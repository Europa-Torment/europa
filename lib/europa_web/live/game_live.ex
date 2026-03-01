defmodule EuropaWeb.GameLive do
  # TODO: write tests
  # coveralls-ignore-start
  use EuropaWeb, :live_view

  import EuropaWeb.GameCompotents

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

  @sound_deplay_ms 100

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
          show_control_hints: false,
          game_started: false
        )
        |> assign_sounds()

      {:ok, socket}
    else
      {:ok, %Game{state: :finished} = game} ->
        {:ok, redirect_to_game_over_page(socket, game.uuid)}
    end
  end

  @impl true
  def handle_event("key_pressed", %{"key" => key}, socket) when key in @move_keys do
    direction = move_key_to_direction(key)
    player_before = socket.assigns.player

    case Server.move(socket.assigns.server, direction) do
      :moved ->
        player = Server.get_player(socket.assigns.server)

        socket =
          socket
          |> assign(
            visible_planet: Server.get_visible_planet(socket.assigns.server),
            player: player,
            chat: Server.get_chat(socket.assigns.server),
            player_stats: get_player_stats(player)
          )
          |> step_sound(player.stand_on)
          |> damaged_sound(player_before.health, player.health)

        {:noreply, socket}

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
    player_before = socket.assigns.player
    shoot_result = Server.shoot(socket.assigns.server)

    player = Server.get_player(socket.assigns.server)
    {weapon, ammo_count} = get_current_weapon_with_ammo_count(player)

    socket =
      socket
      |> assign(
        visible_planet: Server.get_visible_planet(socket.assigns.server),
        player: player,
        weapon: weapon,
        ammo_count: ammo_count,
        chat: Server.get_chat(socket.assigns.server),
        player_stats: get_player_stats(player)
      )
      |> shoot_sound(shoot_result, weapon)
      |> damaged_sound(player_before.health, player.health)

    {:noreply, socket}
  end

  def handle_event("key_pressed", %{"key" => key}, socket) when key in @reload_keys do
    player_before = socket.assigns.player
    result = Server.reload(socket.assigns.server)

    player = Server.get_player(socket.assigns.server)
    {weapon, ammo_count} = get_current_weapon_with_ammo_count(player)

    socket =
      socket
      |> assign(
        visible_planet: Server.get_visible_planet(socket.assigns.server),
        player: player,
        weapon: weapon,
        ammo_count: ammo_count,
        chat: Server.get_chat(socket.assigns.server),
        player_stats: get_player_stats(player)
      )
      |> reload_sound(result)
      |> damaged_sound(player_before.health, player.health)

    {:noreply, socket}
  end

  def handle_event("start_game", _params, socket) do
    {:noreply, assign(socket, game_started: true)}
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

        socket =
          socket
          |> assign(
            item_box: item_box,
            player: player,
            weapon: weapon,
            ammo_count: ammo_count,
            player_stats: get_player_stats(player)
          )
          |> play_sound("equip")

        {:noreply, socket}

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

        socket =
          socket
          |> assign(
            player: updated_player,
            weapon: weapon,
            helmet: helmet,
            suit: suit,
            boots: boots,
            ammo_count: ammo_count,
            inventory: get_player_inventory(socket),
            player_stats: get_player_stats(updated_player)
          )
          |> play_sound("equip")

        {:noreply, socket}

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

        socket =
          socket
          |> assign(
            player: updated_player,
            weapon: weapon,
            helmet: helmet,
            suit: suit,
            boots: boots,
            ammo_count: ammo_count,
            inventory: get_player_inventory(socket),
            player_stats: get_player_stats(updated_player)
          )
          |> play_sound("unequip")

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("unload_weapon", %{"uuid" => item_uuid}, socket) do
    player_before = socket.assigns.player

    case Server.unload_weapon(socket.assigns.server, item_uuid) do
      :ok ->
        updated_player = Server.get_player(socket.assigns.server)
        {weapon, ammo_count} = get_current_weapon_with_ammo_count(updated_player)

        socket =
          socket
          |> assign(
            visible_planet: Server.get_visible_planet(socket.assigns.server),
            player: updated_player,
            weapon: weapon,
            ammo_count: ammo_count,
            inventory: get_player_inventory(socket),
            player_stats: get_player_stats(updated_player),
            chat: Server.get_chat(socket.assigns.server)
          )
          |> play_sound("unload")
          |> damaged_sound(player_before.health, updated_player.health)

        {:noreply, socket}

      _ ->
        {:noreply, assign(socket, chat: Server.get_chat(socket.assigns.server))}
    end
  end

  def handle_event("unload_item_box_weapon", %{"uuid" => item_uuid}, socket) do
    player_before = socket.assigns.player

    case Server.unload_item_box_weapon(socket.assigns.server, item_uuid) do
      {:ok, updated_item_box} ->
        updated_player = Server.get_player(socket.assigns.server)

        socket =
          socket
          |> assign(
            visible_planet: Server.get_visible_planet(socket.assigns.server),
            item_box: updated_item_box,
            player: updated_player,
            player_stats: get_player_stats(updated_player),
            chat: Server.get_chat(socket.assigns.server)
          )
          |> play_sound("unload")
          |> damaged_sound(player_before.health, updated_player.health)

        {:noreply, socket}

      _ ->
        {:noreply, assign(socket, chat: Server.get_chat(socket.assigns.server))}
    end
  end

  def handle_event("consume_supply", %{"uuid" => item_uuid}, socket) do
    player_before = socket.assigns.player

    case Server.consume_supply(socket.assigns.server, item_uuid) do
      {:ok, supply} ->
        updated_player = Server.get_player(socket.assigns.server)

        is_health_not_changed =
          supply.properties.health && player_before.health != updated_player.health - supply.properties.health

        now_health =
          if is_health_not_changed do
            updated_player.health
          else
            updated_player.health - supply.properties.health
          end

        socket =
          socket
          |> assign(
            visible_planet: Server.get_visible_planet(socket.assigns.server),
            player: updated_player,
            inventory: get_player_inventory(socket),
            player_stats: get_player_stats(updated_player),
            chat: Server.get_chat(socket.assigns.server)
          )
          |> play_sound(supply.sound_name)
          |> damaged_sound(player_before.health, now_health)

        {:noreply, socket}

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

  def handle_info({:play_sound, sound_name}, socket) do
    {:noreply, play_sound(socket, sound_name)}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  ### Private ###

  defp assign_sounds(socket) do
    json =
      Jason.encode!(%{
        background_music: %{name: ~p"/sounds/background_music.mp3", volume: 0.1, loop: true},
        snow1: %{name: ~p"/sounds/snow1.mp3", volume: 0.01},
        snow2: %{name: ~p"/sounds/snow2.mp3", volume: 0.01},
        snow3: %{name: ~p"/sounds/snow3.mp3", volume: 0.01},
        shotgun: %{name: ~p"/sounds/shotgun.mp3", volume: 0.2},
        pistol: %{name: ~p"/sounds/pistol.mp3", volume: 0.4},
        rifle: %{name: ~p"/sounds/rifle.mp3", volume: 0.2},
        empty_magazine: %{name: ~p"/sounds/empty_magazine.mp3", volume: 1.0},
        reload: %{name: ~p"/sounds/reload.mp3", volume: 0.2},
        unload: %{name: ~p"/sounds/unload.mp3", volume: 0.2},
        impact: %{name: ~p"/sounds/impact.mp3", volume: 0.3},
        equip: %{name: ~p"/sounds/equip.mp3", volume: 0.08},
        unequip: %{name: ~p"/sounds/unequip.mp3", volume: 0.08},
        eat: %{name: ~p"/sounds/eat.mp3", volume: 0.08},
        injection: %{name: ~p"/sounds/injection.mp3", volume: 0.08},
        click: %{name: ~p"/sounds/click.mp3", volume: 0.6},
        damage1: %{name: ~p"/sounds/damage1.mp3", volume: 0.1},
        damage2: %{name: ~p"/sounds/damage2.mp3", volume: 0.1},
        damage3: %{name: ~p"/sounds/damage3.mp3", volume: 0.1},
        game_over: %{name: ~p"/sounds/game_over.mp3", volume: 0.5}
      })

    assign(socket, :sounds, json)
  end

  defp shoot_sound(socket, shoot_result, weapon) do
    case shoot_result do
      {:ok, :shot} ->
        socket
        |> play_sound(weapon.sound_name)
        |> play_sound_with_delay("impact")

      {:ok, :miss} ->
        play_sound(socket, weapon.sound_name)

      {:error, :empty_magazine} ->
        play_sound(socket, "empty_magazine")

      _ ->
        socket
    end
  end

  defp reload_sound(socket, reload_result) do
    case reload_result do
      :ok -> play_sound(socket, "reload")
      _ -> play_sound(socket, "empty_magazine")
    end
  end

  defp step_sound(socket, _tile) do
    sound = Enum.random(["snow1", "snow2", "snow3"])
    play_sound(socket, sound)
  end

  defp damaged_sound(socket, health_before, health_now) do
    if health_before > health_now do
      sound = Enum.random(["damage1", "damage2", "damage3"])
      play_sound_with_delay(socket, sound)
    else
      socket
    end
  end

  defp play_sound(socket, sound_name) do
    push_event(socket, "play-sound", %{name: sound_name})
  end

  defp play_sound_with_delay(socket, sound_name) do
    self() |> Process.send_after({:play_sound, sound_name}, @sound_deplay_ms)
    socket
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
