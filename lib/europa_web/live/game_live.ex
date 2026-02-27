defmodule EuropaWeb.GameLive do
  # TODO: write tests
  # coveralls-ignore-start
  use EuropaWeb, :live_view

  alias Europa.Server.PlayerManager
  alias Europa.Games
  alias Europa.Games.Game
  alias Europa.Server
  alias Europa.Server.Player
  alias Europa.Server.PlayerManager

  @loot_keys ["l", "L"]
  @inventory_keys ["i", "I"]
  @reload_keys ["r", "R"]

  @close_keys ["Escape"]

  @impl true
  def mount(%{"uuid" => uuid}, _session, socket) do
    with {:ok, %Game{state: :active} = game} <- Games.get_by_uuid(uuid),
         {:ok, server} <- Server.get_pid(uuid) do
      visible_land = Server.get_visible_planet(server)
      player = Server.get_player(server)

      {weapon, ammo_count} = get_current_weapon_with_ammo_count(player)

      helmet = get_current_helmet(player)
      suit = get_current_suit(player)
      boots = get_current_boots(player)

      socket =
        socket
        |> assign(
          game: game,
          server: server,
          visible_planet: visible_land,
          chat: Server.get_chat(server),
          player: player,
          weapon: weapon,
          helmet: helmet,
          suit: suit,
          boots: boots,
          ammo_count: ammo_count,
          player_stats: get_player_stats(player),
          game_field_size: length(visible_land),
          item_box: nil,
          inventory: nil
        )

      {:ok, socket}
    else
      {:ok, %Game{state: :finished} = game} ->
        {:ok, redirect_to_game_over_page(socket, game.uuid)}
    end
  end

  @impl true
  def handle_event("key_pressed", %{"key" => "Arrow" <> arrow_direction}, socket) do
    direction = parse_direction(arrow_direction)

    case Server.move(socket.assigns.server, direction) do
      :moved ->
        player = Server.get_player(socket.assigns.server)

        {:noreply,
         assign(socket,
           visible_planet: Server.get_visible_planet(socket.assigns.server),
           player: player,
           chat: Server.get_chat(socket.assigns.server),
           player_stats: get_player_stats(player)
         )}

      _ ->
        {:noreply,
         assign(socket,
           visible_planet: Server.get_visible_planet(socket.assigns.server),
           player: Server.get_player(socket.assigns.server),
           chat: Server.get_chat(socket.assigns.server)
         )}
    end
  end

  def handle_event("key_pressed", %{"key" => key}, socket) when key in @loot_keys do
    case Server.loot(socket.assigns.server) do
      {:open_item_box, item_box} ->
        {:noreply, assign(socket, item_box: item_box)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("key_pressed", %{"key" => key}, socket) when key in @inventory_keys do
    open_inventory(socket)
  end

  def handle_event("key_pressed", %{"key" => key}, socket) when key in @close_keys do
    {:noreply, assign(socket, inventory: nil, item_box: nil)}
  end

  def handle_event("key_pressed", %{"key" => " "}, socket) do
    :ok = Server.shoot(socket.assigns.server)
    player = Server.get_player(socket.assigns.server)
    {weapon, ammo_count} = get_current_weapon_with_ammo_count(player)

    {:noreply,
     assign(socket,
       visible_planet: Server.get_visible_planet(socket.assigns.server),
       player: player,
       weapon: weapon,
       ammo_count: ammo_count,
       chat: Server.get_chat(socket.assigns.server),
       player_stats: get_player_stats(player)
     )}
  end

  def handle_event("key_pressed", %{"key" => key}, socket) when key in @reload_keys do
    :ok = Server.reload(socket.assigns.server)
    player = Server.get_player(socket.assigns.server)
    {weapon, ammo_count} = get_current_weapon_with_ammo_count(player)

    {:noreply,
     assign(socket,
       visible_planet: Server.get_visible_planet(socket.assigns.server),
       player: player,
       weapon: weapon,
       ammo_count: ammo_count,
       chat: Server.get_chat(socket.assigns.server),
       player_stats: get_player_stats(player)
     )}
  end

  def handle_event("open_inventory", _, socket) do
    open_inventory(socket)
  end

  def handle_event("take_item_" <> item_uuid, _, socket) do
    case Server.take_loot(socket.assigns.server, item_uuid) do
      {:ok, item_box} ->
        player = Server.get_player(socket.assigns.server)
        {weapon, ammo_count} = get_current_weapon_with_ammo_count(player)

        {:noreply,
         assign(socket,
           item_box: item_box,
           player: player,
           weapon: weapon,
           ammo_count: ammo_count,
           player_stats: get_player_stats(player)
         )}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("equip_item_" <> item_uuid, _, socket) do
    case Server.equip_item(socket.assigns.server, item_uuid) do
      {:ok, updated_player} ->
        {weapon, ammo_count} = get_current_weapon_with_ammo_count(updated_player)
        helmet = get_current_helmet(updated_player)
        suit = get_current_suit(updated_player)
        boots = get_current_boots(updated_player)

        {:noreply,
         assign(socket,
           player: updated_player,
           weapon: weapon,
           helmet: helmet,
           suit: suit,
           boots: boots,
           ammo_count: ammo_count,
           inventory: updated_player.inventory,
           player_stats: get_player_stats(updated_player)
         )}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("unequip_item_" <> item_uuid, _, socket) do
    case Server.unequip_item(socket.assigns.server, item_uuid) do
      {:ok, updated_player} ->
        {weapon, ammo_count} = get_current_weapon_with_ammo_count(updated_player)
        helmet = get_current_helmet(updated_player)
        suit = get_current_suit(updated_player)
        boots = get_current_boots(updated_player)

        {:noreply,
         assign(socket,
           player: updated_player,
           weapon: weapon,
           helmet: helmet,
           suit: suit,
           boots: boots,
           ammo_count: ammo_count,
           inventory: updated_player.inventory,
           player_stats: get_player_stats(updated_player)
         )}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("unload_weapon_" <> item_uuid, _, socket) do
    case Server.unload_weapon(socket.assigns.server, item_uuid) do
      {:ok, updated_player} ->
        {weapon, ammo_count} = get_current_weapon_with_ammo_count(updated_player)

        {:noreply,
         assign(socket,
           visible_planet: Server.get_visible_planet(socket.assigns.server),
           player: updated_player,
           weapon: weapon,
           ammo_count: ammo_count,
           inventory: updated_player.inventory,
           player_stats: get_player_stats(updated_player),
           chat: Server.get_chat(socket.assigns.server)
         )}

      _ ->
        {:noreply, assign(socket, chat: Server.get_chat(socket.assigns.server))}
    end
  end

  def handle_event("unload_item_box_weapon_" <> item_uuid, _, socket) do
    case Server.unload_item_box_weapon(socket.assigns.server, item_uuid) do
      {:ok, updated_item_box, updated_player} ->
        {:noreply,
         assign(socket,
           visible_planet: Server.get_visible_planet(socket.assigns.server),
           item_box: updated_item_box,
           player: updated_player,
           player_stats: get_player_stats(updated_player),
           chat: Server.get_chat(socket.assigns.server)
         )}

      _ ->
        {:noreply, assign(socket, chat: Server.get_chat(socket.assigns.server))}
    end
  end

  def handle_event("consume_supply_" <> item_uuid, _, socket) do
    case Server.consume_supply(socket.assigns.server, item_uuid) do
      {:ok, updated_player} ->
        {:noreply,
         assign(socket,
           player: updated_player,
           inventory: updated_player.inventory,
           player_stats: get_player_stats(updated_player),
           chat: Server.get_chat(socket.assigns.server)
         )}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("close_item_box", _, socket) do
    {:noreply, assign(socket, item_box: nil)}
  end

  def handle_event("close_inventory", _, socket) do
    {:noreply, assign(socket, inventory: nil)}
  end

  def handle_event(_, _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(:game_over, socket) do
    {:noreply, redirect_to_game_over_page(socket, socket.assigns.game.uuid)}
  end

  defp redirect_to_game_over_page(socket, game_uuid) do
    redirect(socket, to: ~p"/games/#{game_uuid}/game-over")
  end

  defp open_inventory(socket) do
    inventory = Server.get_inventory(socket.assigns.server)
    {:noreply, assign(socket, inventory: inventory)}
  end

  defp parse_direction("Up"), do: :up
  defp parse_direction("Down"), do: :down
  defp parse_direction("Left"), do: :left
  defp parse_direction("Right"), do: :right

  defp get_player_stats(player) do
    %Player{
      health: health,
      max_health: max_health,
      accuracy: accuracy,
      efficiency: efficiency,
      inventory: inventory,
      inventory_size: inventory_size
    } = player

    items_count = Enum.count(inventory)

    %{
      health: "#{health}/#{max_health}",
      inventory: "#{items_count}/#{inventory_size}",
      accuracy: accuracy,
      efficiency: efficiency
    }
  end

  defp get_current_weapon_with_ammo_count(player) do
    weapon = get_current_weapon(player)
    ammo_count = get_weapon_ammo_count(player, weapon)

    {weapon, ammo_count}
  end

  defp get_current_weapon(player) do
    case PlayerManager.get_equiped_weapon(player) do
      {:ok, weapon} -> weapon
      _ -> nil
    end
  end

  defp get_weapon_ammo_count(_, nil), do: 0

  defp get_weapon_ammo_count(player, weapon) do
    case PlayerManager.find_weapon_ammo(player, weapon) do
      {:ok, ammo} -> ammo.count
      _ -> 0
    end
  end

  defp get_current_helmet(player) do
    case PlayerManager.get_equiped_helmet(player) do
      {:ok, helmet} -> helmet
      _ -> nil
    end
  end

  defp get_current_suit(player) do
    case PlayerManager.get_equiped_suit(player) do
      {:ok, suit} -> suit
      _ -> nil
    end
  end

  defp get_current_boots(player) do
    case PlayerManager.get_equiped_boots(player) do
      {:ok, boots} -> boots
      _ -> nil
    end
  end

  # coveralls-ignore-stop
end
