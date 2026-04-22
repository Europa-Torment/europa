defmodule EuropaWeb.GameLive do
  # TODO: write tests
  # coveralls-ignore-start
  use EuropaWeb, :live_view
  use Gettext, backend: Europa.Gettext

  import EuropaWeb.GameCompotents

  alias Europa.Games
  alias Europa.Games.Game
  alias Europa.Server
  alias Europa.Server.Planet
  alias Europa.Server.Player
  alias Europa.Server.PlayerManager
  alias Europa.Server.Loot
  alias Europa.Server.Loot.Weapon

  import Europa.Tools.Conf
  import Europa.Tools.Randomizer

  @move_up_keys fetch_config!([:control_bindings, :move_up])
  @move_down_keys fetch_config!([:control_bindings, :move_down])
  @move_left_keys fetch_config!([:control_bindings, :move_left])
  @move_right_keys fetch_config!([:control_bindings, :move_right])

  @move_keys @move_up_keys ++ @move_down_keys ++ @move_left_keys ++ @move_right_keys

  @interact_keys fetch_config!([:control_bindings, :interact])
  @loot_keys fetch_config!([:control_bindings, :loot])
  @inventory_keys fetch_config!([:control_bindings, :inventory])
  @reload_keys fetch_config!([:control_bindings, :reload])
  @control_hints_keys fetch_config!([:control_bindings, :control_hints])
  @close_keys fetch_config!([:control_bindings, :close])
  @shoot_keys fetch_config!([:control_bindings, :shoot])
  @scope_keys fetch_config!([:control_bindings, :scope])

  @low_health_ratio fetch_config!([:game_params, :player, :low_health_ratio])

  @default_sound_delay_ms 100
  @game_over_sound_delay_ms 200

  @game_over_redirect_delay_ms 8950

  @view_distance fetch_config!([Planet, :view_distance])

  @impl true
  def mount(%{"uuid" => uuid}, session, socket) do
    current_user = Map.fetch!(session, "current_user")

    with {:ok, %Game{state: :active, user_id: ^current_user} = game} <- Games.get_by_uuid(uuid),
         {:ok, server} <- Server.get_pid(uuid) do
      visible_planet = Server.get_visible_planet(server)
      player = Server.get_player(server)

      {weapon, ammo_count} = get_current_weapon_with_ammo_count(player)

      melee_weapon = get_current_melee_weapon(player)
      helmet = get_current_helmet(player)
      suit = get_current_suit(player)
      boots = get_current_boots(player)

      socket =
        socket
        |> assign(
          game: game,
          server: server,
          visible_planet: visible_planet,
          chat: Server.get_chat(server),
          current_time: get_current_time(server),
          player: player,
          weapon: weapon,
          melee_weapon: melee_weapon,
          helmet: helmet,
          suit: suit,
          boots: boots,
          ammo_count: ammo_count,
          player_stats: get_player_stats(player),
          game_field_size: length(visible_planet),
          item_box: nil,
          inventory: nil,
          inventory_type: nil,
          show_control_hints: false,
          game_started: false,
          item_to_drop: nil,
          item_drop_count: 1,
          game_over: false,
          game_page: true,
          dialog: nil,
          show_scope: false,
          scope: get_scope(visible_planet, player, weapon)
        )

      {:ok, socket}
    else
      {:ok, %Game{state: :finished} = game} ->
        {:ok, redirect_to_game_over_page(socket, game.uuid)}

      _ ->
        {:ok, redirect(socket, to: "/")}
    end
  end

  @impl true
  def handle_event(_, _, %{assigns: %{game_over: true}} = socket) do
    {:noreply, socket}
  end

  def handle_event("start_game", _params, socket) do
    socket =
      socket
      |> assign_sounds()
      |> assign(game_started: true)
      |> play_sound("background_music")

    {:noreply, socket}
  end

  def handle_event(_, _, %{assigns: %{game_started: false}} = socket) do
    {:noreply, socket}
  end

  def handle_event("key_pressed", %{"key" => key}, socket) when key in @move_keys do
    direction = move_key_to_direction(key)
    player_before = socket.assigns.player

    case Server.move(socket.assigns.server, direction) do
      {:moved, move_status} ->
        player = Server.get_player(socket.assigns.server)
        visible_planet = Server.get_visible_planet(socket.assigns.server)
        weapon = get_current_weapon(player)

        socket =
          socket
          |> assign(
            visible_planet: visible_planet,
            player: player,
            chat: Server.get_chat(socket.assigns.server),
            player_stats: get_player_stats(player),
            current_time: get_current_time(socket.assigns.server),
            scope: get_scope(visible_planet, player, weapon)
          )
          |> step_sound(player.stand_on)
          |> damaged_sound(player_before.health, player.health)
          |> overloaded_sound(move_status)
          |> low_health_sound(player)

        {:noreply, socket}

      {:attack, status} ->
        player = Server.get_player(socket.assigns.server)
        visible_planet = Server.get_visible_planet(socket.assigns.server)
        weapon = get_current_weapon(player)

        socket =
          socket
          |> assign(
            visible_planet: Server.get_visible_planet(socket.assigns.server),
            player: player,
            chat: Server.get_chat(socket.assigns.server),
            player_stats: get_player_stats(player),
            current_time: get_current_time(socket.assigns.server),
            scope: get_scope(visible_planet, player, weapon)
          )
          |> punch_sound(status)
          |> damaged_sound(player_before.health, player.health)
          |> low_health_sound(player)

        {:noreply, socket}

      _ ->
        player = Server.get_player(socket.assigns.server)
        visible_planet = Server.get_visible_planet(socket.assigns.server)
        weapon = get_current_weapon(player)

        {:noreply,
         assign(socket,
           visible_planet: visible_planet,
           player: player,
           chat: Server.get_chat(socket.assigns.server),
           current_time: get_current_time(socket.assigns.server),
           scope: get_scope(visible_planet, player, weapon)
         )}
    end
  end

  def handle_event("key_pressed", %{"key" => key}, socket) when key in @interact_keys do
    case Server.interact(socket.assigns.server) do
      {:ok, {:talk, npc}} ->
        {:noreply,
         assign(socket,
           dialog: %{npc: npc},
           chat: Server.get_chat(socket.assigns.server),
           show_control_hints: false,
           inventory: nil,
           item_box: nil
         )}

      {:ok, {:drink, _}} ->
        player = Server.get_player(socket.assigns.server)

        socket =
          socket
          |> assign(
            chat: Server.get_chat(socket.assigns.server),
            show_control_hints: false,
            inventory: nil,
            item_box: nil,
            player: player,
            player_stats: get_player_stats(player)
          )
          |> play_sound("drink")

        {:noreply, socket}

      _ ->
        {:noreply, assign(socket, chat: Server.get_chat(socket.assigns.server))}
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
    {:noreply,
     assign(socket,
       inventory: nil,
       item_box: nil,
       show_control_hints: false,
       item_drop_menu: false,
       item_to_drop: nil,
       dialog: nil
     )}
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
        player_stats: get_player_stats(player),
        current_time: get_current_time(socket.assigns.server)
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
        player_stats: get_player_stats(player),
        current_time: get_current_time(socket.assigns.server)
      )
      |> reload_sound(result)
      |> damaged_sound(player_before.health, player.health)

    {:noreply, socket}
  end

  def handle_event("key_pressed", %{"key" => key}, socket) when key in @scope_keys do
    {:noreply, assign(socket, :show_scope, !socket.assigns.show_scope)}
  end

  def handle_event("key_pressed", _params, socket) do
    message = gettext("This button doesn't do anything. Perhaps you forgot to switch the keyboard layout to English?")
    socket = put_flash(socket, :error, message)

    {:noreply, socket}
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

  def handle_event("close_dialog", _, socket) do
    {:noreply, assign(socket, dialog: nil)}
  end

  def handle_event("take_item", %{"uuid" => item_uuid}, socket) do
    case Server.take_loot(socket.assigns.server, item_uuid) do
      {:ok, item_box} ->
        player = Server.get_player(socket.assigns.server)
        {weapon, ammo_count} = get_current_weapon_with_ammo_count(player)

        socket =
          socket
          |> assign(
            visible_planet: Server.get_visible_planet(socket.assigns.server),
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
        melee_weapon = get_current_melee_weapon(updated_player)
        helmet = get_current_helmet(updated_player)
        suit = get_current_suit(updated_player)
        boots = get_current_boots(updated_player)
        visible_planet = Server.get_visible_planet(socket.assigns.server)

        socket =
          socket
          |> assign(
            player: updated_player,
            weapon: weapon,
            melee_weapon: melee_weapon,
            helmet: helmet,
            suit: suit,
            boots: boots,
            ammo_count: ammo_count,
            inventory: get_player_inventory(socket),
            player_stats: get_player_stats(updated_player),
            scope: get_scope(visible_planet, updated_player, weapon)
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
        melee_weapon = get_current_melee_weapon(updated_player)
        helmet = get_current_helmet(updated_player)
        suit = get_current_suit(updated_player)
        boots = get_current_boots(updated_player)
        visible_planet = Server.get_visible_planet(socket.assigns.server)

        socket =
          socket
          |> assign(
            player: updated_player,
            weapon: weapon,
            melee_weapon: melee_weapon,
            helmet: helmet,
            suit: suit,
            boots: boots,
            ammo_count: ammo_count,
            inventory: get_player_inventory(socket),
            player_stats: get_player_stats(updated_player),
            show_scope: socket.assigns.show_scope && not is_nil(weapon),
            scope: get_scope(visible_planet, updated_player, weapon)
          )
          |> play_sound("unequip")

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("drop_item", %{"uuid" => item_uuid}, socket) do
    case Server.drop_item(socket.assigns.server, item_uuid, socket.assigns.item_drop_count) do
      {:ok, updated_player} ->
        {weapon, ammo_count} = get_current_weapon_with_ammo_count(updated_player)
        melee_weapon = get_current_melee_weapon(updated_player)
        helmet = get_current_helmet(updated_player)
        suit = get_current_suit(updated_player)
        boots = get_current_boots(updated_player)
        visible_planet = Server.get_visible_planet(socket.assigns.server)

        socket =
          socket
          |> assign(
            player: updated_player,
            weapon: weapon,
            melee_weapon: melee_weapon,
            helmet: helmet,
            suit: suit,
            boots: boots,
            ammo_count: ammo_count,
            inventory: get_player_inventory(socket),
            player_stats: get_player_stats(updated_player),
            show_scope: socket.assigns.show_scope && not is_nil(weapon),
            scope: get_scope(visible_planet, updated_player, weapon),
            item_to_drop: nil,
            item_drop_count: nil
          )
          |> play_sound("equip")

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("open_item_drop_menu", %{"uuid" => item_uuid}, socket) do
    with {:ok, item} <- Server.get_item(socket.assigns.server, item_uuid),
         true <- Loot.Item.stackable?(item) do
      {:noreply, assign(socket, item_to_drop: item, item_drop_count: 1)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("close_item_drop_menu", _, socket) do
    {:noreply, assign(socket, item_to_drop: nil, item_drop_count: nil)}
  end

  def handle_event("change_item_drop_count", %{"item_drop_count" => count}, socket) do
    count =
      case Integer.parse(count) do
        {count, _} when is_integer(count) and count > 0 -> count
        _ -> socket.assigns.item_drop_count
      end

    {:noreply, assign(socket, item_drop_count: count)}
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
            chat: Server.get_chat(socket.assigns.server),
            current_time: get_current_time(socket.assigns.server)
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
            chat: Server.get_chat(socket.assigns.server),
            current_time: get_current_time(socket.assigns.server)
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
          cond do
            is_health_not_changed -> updated_player.health
            supply.properties.health -> updated_player.health - supply.properties.health
            true -> updated_player.health
          end

        socket =
          socket
          |> assign(
            visible_planet: Server.get_visible_planet(socket.assigns.server),
            player: updated_player,
            inventory: get_player_inventory(socket),
            player_stats: get_player_stats(updated_player),
            chat: Server.get_chat(socket.assigns.server),
            current_time: get_current_time(socket.assigns.server)
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
    socket =
      socket
      |> assign(game_over: true)
      |> stop_sound("background_music")
      |> play_sound("dead")
      |> play_sound_with_delay("game_over", @game_over_sound_delay_ms)

    self() |> Process.send_after(:game_over_redirect, @game_over_redirect_delay_ms)
    {:noreply, socket}
  end

  def handle_info(:game_over_redirect, socket) do
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
        laser: %{name: ~p"/sounds/laser.mp3", volume: 0.2},
        punch: %{name: ~p"/sounds/punch.mp3", volume: 0.2},
        empty_magazine: %{name: ~p"/sounds/empty_magazine.mp3", volume: 1.0},
        reload: %{name: ~p"/sounds/reload.mp3", volume: 0.2},
        unload: %{name: ~p"/sounds/unload.mp3", volume: 0.2},
        impact: %{name: ~p"/sounds/impact.mp3", volume: 0.3},
        equip: %{name: ~p"/sounds/equip.mp3", volume: 0.08},
        unequip: %{name: ~p"/sounds/unequip.mp3", volume: 0.08},
        eat: %{name: ~p"/sounds/eat.mp3", volume: 0.08},
        drink: %{name: ~p"/sounds/drink.mp3", volume: 0.5},
        injection: %{name: ~p"/sounds/injection.mp3", volume: 0.08},
        click: %{name: ~p"/sounds/click.mp3", volume: 0.6},
        damage1: %{name: ~p"/sounds/damage1.mp3", volume: 0.05},
        damage2: %{name: ~p"/sounds/damage2.mp3", volume: 0.05},
        damage3: %{name: ~p"/sounds/damage3.mp3", volume: 0.05},
        overloaded1: %{name: ~p"/sounds/overloaded1.mp3", volume: 0.08},
        overloaded2: %{name: ~p"/sounds/overloaded2.mp3", volume: 0.08},
        overloaded3: %{name: ~p"/sounds/overloaded3.mp3", volume: 0.08},
        injured: %{name: ~p"/sounds/injured.mp3", volume: 0.05},
        dead: %{name: ~p"/sounds/dead.mp3", volume: 0.2},
        game_over: %{name: ~p"/sounds/game_over.mp3", volume: 0.1}
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

  defp overloaded_sound(socket, :overloaded) do
    if m_to_n?(1, 10) do
      sound = Enum.random(["overloaded1", "overloaded2", "overloaded3"])
      play_sound_with_delay(socket, sound)
    else
      socket
    end
  end

  defp overloaded_sound(socket, _) do
    socket
  end

  defp low_health_sound(socket, player) do
    if player.health / player.max_health <= @low_health_ratio && m_to_n?(1, 25) do
      play_sound(socket, "injured")
    else
      socket
    end
  end

  defp punch_sound(socket, result) do
    punch_sound =
      if socket.assigns.melee_weapon do
        socket.assigns.melee_weapon.sound_name
      else
        "punch"
      end

    case result do
      :miss ->
        play_sound(socket, punch_sound)

      :hitted ->
        socket
        |> play_sound(punch_sound)
        |> play_sound_with_delay("impact")
    end
  end

  defp play_sound(socket, sound_name) do
    push_event(socket, "play-sound", %{name: sound_name})
  end

  defp stop_sound(socket, sound_name) do
    push_event(socket, "stop-sound", %{name: sound_name})
  end

  defp play_sound_with_delay(socket, sound_name, delay \\ @default_sound_delay_ms) do
    self() |> Process.send_after({:play_sound, sound_name}, delay)
    socket
  end

  defp redirect_to_game_over_page(socket, game_uuid) do
    redirect(socket, to: ~p"/games/#{game_uuid}/game-over")
  end

  defp open_inventory(socket) do
    inventory = get_player_inventory(socket)
    {:noreply, assign(socket, inventory: inventory, item_box: nil, show_control_hints: false, dialog: nil)}
  end

  defp close_inventory(socket) do
    {:noreply, assign(socket, inventory: nil, inventory_type: nil)}
  end

  defp open_item_box(socket) do
    case Server.loot(socket.assigns.server) do
      {:open_item_box, item_box} ->
        {:noreply, assign(socket, item_box: item_box, inventory: nil, show_control_hints: false, dialog: nil)}

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

  defp get_player_stats(%Player{} = player) do
    inventory_weight = PlayerManager.inventory_weight(player)

    %{
      health: player.health,
      max_health: player.max_health,
      warm: player.warm,
      max_warm: player.max_warm,
      hunger: player.hunger,
      thirst: player.thirst,
      radiation: player.radiation,
      max_weight: player.max_weight,
      inventory_weight: inventory_weight,
      accuracy: player.accuracy,
      efficiency: player.efficiency
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

  defp get_current_melee_weapon(player) do
    case PlayerManager.get_equiped_melee_weapon(player) do
      {:ok, melee_weapon} -> melee_weapon
      _ -> nil
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

  defp get_current_time(server) do
    {year, day, time} = Server.get_current_time(server)
    %{year: year, day: day, time: time}
  end

  defp get_scope(_, _, nil), do: []

  defp get_scope(visible_planet, player, %Weapon{shooting_distance: shooting_distance} = weapon) do
    planet_view_distance = div(@view_distance, 2)
    distance = min(shooting_distance, planet_view_distance)

    {player_y, player_x} =
      visible_planet
      |> Enum.with_index()
      |> Enum.find_value(fn {row, row_id} ->
        case Enum.find_index(row, &(&1 == :player)) do
          nil -> nil
          col_id -> {row_id, col_id}
        end
      end)

    case player.view_direction do
      :up -> [{{player_y, player_x}, {player_y - distance, player_x}}]
      :down -> [{{player_y, player_x}, {player_y + distance, player_x}}]
      :left -> [{{player_y, player_x}, {player_y, player_x - distance}}]
      :right -> [{{player_y, player_x}, {player_y, player_x + distance}}]
    end
    |> maybe_add_shotgun_scopes(weapon, player.view_direction)
  end

  defp maybe_add_shotgun_scopes(
         [{{from_y, from_x}, {to_y, to_x}}],
         %Weapon{shooting_type: :shot} = weapon,
         view_direction
       ) do
    distance = weapon.shooting_distance

    case view_direction do
      :up -> Enum.map(-distance..distance, fn m -> {{from_y, from_x}, {to_y, to_x + m}} end)
      :down -> Enum.map(-distance..distance, fn m -> {{from_y, from_x}, {to_y, to_x - m}} end)
      :left -> Enum.map(-distance..distance, fn m -> {{from_y, from_x}, {to_y - m, to_x}} end)
      :right -> Enum.map(-distance..distance, fn m -> {{from_y, from_x}, {to_y + m, to_x}} end)
    end
  end

  defp maybe_add_shotgun_scopes(scopes, _, _), do: scopes

  defp move_key_to_direction(key) when key in @move_up_keys, do: :up
  defp move_key_to_direction(key) when key in @move_down_keys, do: :down
  defp move_key_to_direction(key) when key in @move_left_keys, do: :left
  defp move_key_to_direction(key) when key in @move_right_keys, do: :right

  # coveralls-ignore-stop
end
