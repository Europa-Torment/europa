defmodule EuropaWeb.GameLive do
  # TODO: write tests
  # coveralls-ignore-start
  use EuropaWeb, :live_view

  import EuropaWeb.GameCompotents

  alias Europa.Server.PlayerManager
  alias Europa.Games
  alias Europa.Games.Game
  alias Europa.Server
  alias Europa.Server.Player
  alias Europa.Server.PlayerManager

  import Europa.Tools.Conf

  @move_up_keys fetch_config!([:control_bindings, :move_up])
  @move_down_keys fetch_config!([:control_bindings, :move_down])
  @move_left_keys fetch_config!([:control_bindings, :move_left])
  @move_right_keys fetch_config!([:control_bindings, :move_right])

  @move_keys @move_up_keys ++ @move_down_keys ++ @move_left_keys ++ @move_right_keys

  @loot_keys fetch_config!([:control_bindings, :loot])
  @inventory_keys fetch_config!([:control_bindings, :inventory])
  @reload_keys fetch_config!([:control_bindings, :reload])
  @control_hints_keys fetch_config!([:control_bindings, :control_hints])
  @close_keys fetch_config!([:control_bindings, :close])
  @shoot_keys fetch_config!([:control_bindings, :shoot])

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
          inventory: nil,
          inventory_type: nil,
          show_control_hints: false
        )

      {:ok, socket}
    else
      {:ok, %Game{state: :finished} = game} ->
        {:ok, redirect_to_game_over_page(socket, game.uuid)}
    end
  end

  @impl true
  def handle_event("key_pressed", %{"key" => key}, socket) when key in @move_keys do
    direction = move_key_to_direction(key)

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
    if socket.assigns.item_box do
      close_item_box(socket)
    else
      open_item_box(socket)
    end
  end

  def handle_event("key_pressed", %{"key" => key}, socket) when key in @inventory_keys do
    if socket.assigns.inventory do
      close_inventory(socket)
    else
      socket
      |> assign(inventory_type: :all)
      |> open_inventory()
    end
  end

  def handle_event("key_pressed", %{"key" => key}, socket) when key in @control_hints_keys do
    socket
    |> toggle_control_hints()
  end

  def handle_event("key_pressed", %{"key" => key}, socket) when key in @close_keys do
    {:noreply, assign(socket, inventory: nil, item_box: nil, show_control_hints: false)}
  end

  def handle_event("key_pressed", %{"key" => key}, socket) when key in @shoot_keys do
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

  def handle_event("open_inventory", params, socket) do
    type =
      params
      |> Map.get("type", "all")
      |> String.to_atom()

    socket
    |> assign(inventory_type: type)
    |> open_inventory()
  end

  def handle_event("show_control_hints", _, socket) do
    socket
    |> toggle_control_hints()
  end

  def handle_event("close_control_hints", _, socket) do
    {:noreply, assign(socket, show_control_hints: false)}
  end

  def handle_event("take_item", %{"uuid" => item_uuid}, socket) do
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

  def handle_event("equip_item", %{"uuid" => item_uuid}, socket) do
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
           inventory: get_player_inventory(socket),
           player_stats: get_player_stats(updated_player)
         )}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("unequip_item", %{"uuid" => item_uuid}, socket) do
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
           inventory: get_player_inventory(socket),
           player_stats: get_player_stats(updated_player)
         )}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("unload_weapon", %{"uuid" => item_uuid}, socket) do
    case Server.unload_weapon(socket.assigns.server, item_uuid) do
      {:ok, updated_player} ->
        {weapon, ammo_count} = get_current_weapon_with_ammo_count(updated_player)

        {:noreply,
         assign(socket,
           visible_planet: Server.get_visible_planet(socket.assigns.server),
           player: updated_player,
           weapon: weapon,
           ammo_count: ammo_count,
           inventory: get_player_inventory(socket),
           player_stats: get_player_stats(updated_player),
           chat: Server.get_chat(socket.assigns.server)
         )}

      _ ->
        {:noreply, assign(socket, chat: Server.get_chat(socket.assigns.server))}
    end
  end

  def handle_event("unload_item_box_weapon", %{"uuid" => item_uuid}, socket) do
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

  def handle_event("consume_supply", %{"uuid" => item_uuid}, socket) do
    case Server.consume_supply(socket.assigns.server, item_uuid) do
      {:ok, updated_player} ->
        {:noreply,
         assign(socket,
           player: updated_player,
           inventory: get_player_inventory(socket),
           player_stats: get_player_stats(updated_player),
           chat: Server.get_chat(socket.assigns.server)
         )}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("close_item_box", _, socket) do
    close_item_box(socket)
  end

  def handle_event("close_inventory", _, socket) do
    close_inventory(socket)
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
    inventory = get_player_inventory(socket)
    {:noreply, assign(socket, inventory: inventory)}
  end

  defp close_inventory(socket) do
    {:noreply, assign(socket, inventory: nil, inventory_type: nil)}
  end

  defp open_item_box(socket) do
    case Server.loot(socket.assigns.server) do
      {:open_item_box, item_box} ->
        {:noreply, assign(socket, item_box: item_box)}

      _ ->
        {:noreply, assign(socket, chat: Server.get_chat(socket.assigns.server))}
    end
  end

  defp close_item_box(socket) do
    {:noreply, assign(socket, item_box: nil)}
  end

  defp toggle_control_hints(socket) do
    {:noreply, assign(socket, show_control_hints: !socket.assigns.show_control_hints)}
  end

  defp get_player_inventory(socket) do
    Server.get_inventory(socket.assigns.server, socket.assigns[:inventory_type] || :all)
  end

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

  defp move_key_to_direction(key) when key in @move_up_keys, do: :up
  defp move_key_to_direction(key) when key in @move_down_keys, do: :down
  defp move_key_to_direction(key) when key in @move_left_keys, do: :left
  defp move_key_to_direction(key) when key in @move_right_keys, do: :right

  # coveralls-ignore-stop
end
