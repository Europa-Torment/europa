defmodule EuropaWeb.GameLive do
  # TODO: write tests
  # coveralls-ignore-start
  use EuropaWeb, :live_view
  use Gettext, backend: Europa.Gettext

  alias Europa.Games
  alias Europa.Games.Game
  alias Europa.Server
  alias Europa.Server.Planet
  alias Europa.Server.Player
  alias Europa.Server.PlayerManager
  alias Europa.Server.Loot
  alias Europa.Server.Event
  alias Europa.Server.Loot.Weapon
  alias Europa.Server.Planet.Tiles.Objects.Object

  import EuropaWeb.GameCompotents
  import Europa.Tools.Conf
  import Europa.Tools.Randomizer

  @move_up_codes fetch_config!([:control_bindings, :move_up]).codes
  @move_down_codes fetch_config!([:control_bindings, :move_down]).codes
  @move_left_codes fetch_config!([:control_bindings, :move_left]).codes
  @move_right_codes fetch_config!([:control_bindings, :move_right]).codes

  @move_codes @move_up_codes ++ @move_down_codes ++ @move_left_codes ++ @move_right_codes

  @interact_codes fetch_config!([:control_bindings, :interact]).codes
  @loot_codes fetch_config!([:control_bindings, :loot]).codes
  @inventory_codes fetch_config!([:control_bindings, :inventory]).codes
  @reload_codes fetch_config!([:control_bindings, :reload]).codes
  @control_hints_codes fetch_config!([:control_bindings, :control_hints]).codes
  @close_codes fetch_config!([:control_bindings, :close]).codes
  @shoot_codes fetch_config!([:control_bindings, :shoot]).codes
  @aim_codes fetch_config!([:control_bindings, :aim]).codes

  @low_health_ratio fetch_config!([:game_params, :player, :low_health_ratio])

  @default_sound_delay_ms 100
  @game_over_sound_delay_ms 200

  @game_over_redirect_delay_ms 8950

  @events_tick_delay_ms 1000
  @events_tick_max_resets 5

  @processed_player_events_limit 20

  @view_distance fetch_config!([Planet, :view_distance])

  @impl true
  def mount(%{"uuid" => uuid}, session, socket) do
    current_user = Map.fetch!(session, "current_user")

    with {:ok, %Game{state: :active, user_id: ^current_user} = game} <- Games.get_by_uuid(uuid),
         {:ok, server} <- Server.get_pid(uuid) do
      socket =
        socket
        |> assign(
          game: game,
          server: server,
          events_tick_timer: schedule_events_tick(),
          events_tick_timer_reset_at: current_time_ms(),
          events_tick_timer_reset_skip_count: 0,
          processed_player_events_uuid: []
        )
        |> base_assign(events_tick_timer_reset: false)
        |> assign_equipment()
        |> close_all()

      socket =
        socket
        |> assign(
          game_field_size: length(socket.assigns.visible_planet),
          game_started: false,
          item_to_drop: nil,
          item_drop_count: nil,
          game_over: false,
          game_page: true,
          disassemble_item_uuid: nil,
          disassemble_items: nil,
          blueprints: nil,
          blueprints_type: nil,
          interaction_confirmation: nil,
          inventory_type: nil
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

  def handle_event("key_pressed", %{"code" => code}, socket) when code in @move_codes do
    direction = move_code_to_direction(code)

    case Server.move(socket.assigns.server, direction) do
      {:moved, move_status} ->
        socket = base_assign(socket)

        socket =
          socket
          |> step_sound(socket.assigns.player.stand_on)
          |> overloaded_sound(move_status)
          |> low_health_sound(socket.assigns.player)

        {:noreply, socket}

      {:attack, status} ->
        socket = base_assign(socket)

        socket =
          socket
          |> punch_sound(status)
          |> low_health_sound(socket.assigns.player)

        {:noreply, socket}

      _ ->
        {:noreply, base_assign(socket)}
    end
  end

  def handle_event("key_pressed", %{"code" => code} = params, socket) when code in @interact_codes do
    interact(socket, params)
  end

  def handle_event("key_pressed", %{"code" => code}, socket) when code in @loot_codes do
    if socket.assigns.item_box do
      close_item_box(socket)
    else
      open_item_box(socket)
    end
  end

  def handle_event("key_pressed", %{"code" => code}, socket) when code in @inventory_codes do
    if socket.assigns.inventory do
      close_inventory(socket)
    else
      socket
      |> assign(inventory_type: :all)
      |> open_inventory()
    end
  end

  def handle_event("key_pressed", %{"code" => code}, socket) when code in @control_hints_codes do
    socket
    |> toggle_control_hints()
  end

  def handle_event("key_pressed", %{"code" => code}, socket) when code in @close_codes do
    {:noreply, close_all(socket)}
  end

  def handle_event("key_pressed", %{"code" => code}, socket) when code in @shoot_codes do
    shoot_result = Server.shoot(socket.assigns.server)

    socket =
      socket
      |> base_assign()
      |> assign_equipment()
      |> shoot_sound(shoot_result)

    {:noreply, socket}
  end

  def handle_event("key_pressed", %{"code" => code}, socket) when code in @reload_codes do
    reload_weapon(socket)
  end

  def handle_event("key_pressed", %{"code" => code}, socket) when code in @aim_codes do
    case Server.toggle_aim_mode(socket.assigns.server) do
      :ok ->
        socket =
          socket
          |> base_assign()
          |> play_sound("click")

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("key_pressed", _params, socket) do
    message = gettext("This key doesn't do anything. Press H to get control hints.")
    socket = put_flash(socket, :error, message)

    {:noreply, socket}
  end

  def handle_event("interact", params, socket) do
    interact(socket, params)
  end

  def handle_event("reload_weapon", %{"uuid" => item_uuid}, socket) do
    reload_weapon(socket, item_uuid)
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

  def handle_event("open_craft_menu", params, socket) do
    type =
      params
      |> Map.get("type", "all")
      |> String.to_atom()

    socket
    |> assign(blueprints_type: type)
    |> open_craft_menu()
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

  def handle_event("close_interaction_confirmation", _, socket) do
    {:noreply, assign(socket, interaction_confirmation: nil)}
  end

  def handle_event("close_item_disassemble_menu", _, socket) do
    {:noreply, assign(socket, disassemble_items: nil)}
  end

  def handle_event("close_craft_menu", _, socket) do
    socket
    |> close_craft_menu()
  end

  def handle_event("take_item", %{"uuid" => item_uuid}, socket) do
    case Server.take_loot(socket.assigns.server, item_uuid) do
      {:ok, item_box} ->
        socket =
          socket
          |> base_assign()
          |> assign_equipment()
          |> assign(item_box: item_box)
          |> play_sound("equip")

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("equip_item", %{"uuid" => item_uuid}, socket) do
    case Server.equip_item(socket.assigns.server, item_uuid) do
      {:ok, _updated_player} ->
        socket =
          socket
          |> base_assign()
          |> assign_equipment()
          |> assign(inventory: get_player_inventory(socket))
          |> play_sound("equip")

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("unequip_item", %{"uuid" => item_uuid}, socket) do
    case Server.unequip_item(socket.assigns.server, item_uuid) do
      {:ok, _updated_player} ->
        socket =
          socket
          |> base_assign()
          |> assign_equipment()
          |> assign(inventory: get_player_inventory(socket))
          |> play_sound("unequip")

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("disassemble_item", %{"uuid" => item_uuid}, socket) do
    with {:ok, item} <- Server.get_item(socket.assigns.server, item_uuid),
         true <- Loot.Item.disassemblable?(item),
         {:ok, items} <- Loot.Item.disassemble(item) do
      {:noreply, assign(socket, disassemble_item_uuid: item_uuid, disassemble_items: items)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("confirm_item_disassemble", %{"uuid" => item_uuid}, socket) do
    case Server.disassemble_item(socket.assigns.server, item_uuid) do
      :ok ->
        socket =
          socket
          |> base_assign()
          |> assign_equipment()
          |> assign(
            inventory: get_player_inventory(socket),
            disassemble_item_uuid: nil,
            disassemble_items: nil
          )
          |> play_sound("assemble")

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("drop_item", %{"uuid" => item_uuid}, socket) do
    case Server.drop_item(socket.assigns.server, item_uuid, socket.assigns.item_drop_count) do
      {:ok, _updated_player} ->
        socket =
          socket
          |> base_assign()
          |> assign_equipment()
          |> assign(
            inventory: get_player_inventory(socket),
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
    case Server.unload_weapon(socket.assigns.server, item_uuid) do
      :ok ->
        socket =
          socket
          |> base_assign()
          |> assign_equipment()
          |> assign(inventory: get_player_inventory(socket))
          |> play_sound("unload")

        {:noreply, socket}

      _ ->
        {:noreply, assign(socket, chat: Server.get_chat(socket.assigns.server))}
    end
  end

  def handle_event("unload_item_box_weapon", %{"uuid" => item_uuid}, socket) do
    case Server.unload_item_box_weapon(socket.assigns.server, item_uuid) do
      {:ok, updated_item_box} ->
        socket =
          socket
          |> base_assign()
          |> assign(item_box: updated_item_box)
          |> play_sound("unload")

        {:noreply, socket}

      _ ->
        {:noreply, assign(socket, chat: Server.get_chat(socket.assigns.server))}
    end
  end

  def handle_event("consume_supply", %{"uuid" => item_uuid}, socket) do
    case Server.consume_supply(socket.assigns.server, item_uuid) do
      {:ok, supply} ->
        socket =
          socket
          |> base_assign()
          |> assign(inventory: get_player_inventory(socket))
          |> play_sound(supply.sound_name)

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("use_tool", %{"uuid" => item_uuid}, socket) do
    case Server.use_tool(socket.assigns.server, item_uuid) do
      {:ok, tool} ->
        socket =
          socket
          |> base_assign()
          |> close_all()
          |> play_sound(tool.sound_name)

        {:noreply, socket}

      _ ->
        {:noreply, close_all(socket)}
    end
  end

  def handle_event("craft_item", %{"uuid" => item_uuid}, socket) do
    case socket.assigns.blueprints do
      nil -> {:noreply, socket}
      blueprints -> craft_item(item_uuid, blueprints, socket)
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

  def handle_info({:timeout, timer_ref, :events_tick}, socket) do
    if connected?(socket) do
      time_diff = current_time_ms() - socket.assigns.events_tick_timer_reset_at
      skip_count = socket.assigns.events_tick_timer_reset_skip_count

      cond do
        timer_ref != socket.assigns.events_tick_timer -> {:noreply, socket}
        skip_count >= @events_tick_max_resets -> do_events_tick(socket)
        time_diff >= @events_tick_delay_ms -> do_events_tick(socket)
        true -> {:noreply, assign(socket, events_tick_timer: schedule_events_tick())}
      end
    else
      Process.cancel_timer(socket.assigns.events_tick_timer)
      {:stop, :shutdown, socket}
    end
  end

  def handle_info(:reset_events_tick_timer, socket) do
    skip_count = socket.assigns.events_tick_timer_reset_skip_count

    Process.cancel_timer(socket.assigns.events_tick_timer)

    {:noreply,
     assign(socket, events_tick_timer: schedule_events_tick(), events_tick_timer_reset_skip_count: skip_count + 1)}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  ### Private ###

  defp do_events_tick(socket) do
    if Process.alive?(socket.assigns.server) do
      :ok = Server.events_tick(socket.assigns.server)

      socket =
        socket
        |> assign(
          events_tick_timer: schedule_events_tick(),
          events_tick_timer_reset_at: current_time_ms(),
          events_tick_timer_reset_skip_count: 0
        )
        |> base_assign(events_tick_timer_reset: false)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp play_sounds_from_player_events(socket) do
    Enum.reduce(socket.assigns.player.events, socket, fn event, socket ->
      if event.uuid in socket.assigns.processed_player_events_uuid do
        socket
      else
        socket
        |> remember_player_event(event.uuid)
        |> play_player_event_sound(event)
      end
    end)
  end

  defp remember_player_event(socket, event_uuid) do
    processed_uuids = socket.assigns.processed_player_events_uuid

    updated_processed_uuids =
      if Enum.count(processed_uuids) == @processed_player_events_limit do
        List.delete_at(processed_uuids, 0) ++ [event_uuid]
      else
        processed_uuids ++ [event_uuid]
      end

    assign(socket, processed_player_events_uuid: updated_processed_uuids)
  end

  defp play_player_event_sound(socket, %Event{type: {:damaged, _}}) do
    damaged_sound(socket)
  end

  defp play_player_event_sound(socket, %Event{type: {:radiation, _}}) do
    radiation_sound(socket)
  end

  defp play_player_event_sound(socket, %Event{type: {:dead, :regular}}) do
    dead_sound(socket)
  end

  defp play_player_event_sound(socket, %Event{type: {:dead, :ice_cracked}}) do
    ice_cracked_sound(socket)
  end

  defp play_player_event_sound(socket, %Event{type: :enemy_killed}) do
    enemy_killed_sound(socket)
  end

  defp play_player_event_sound(socket, _), do: socket

  defp base_assign(socket, opts \\ []) do
    resets_count = socket.assigns.events_tick_timer_reset_skip_count

    if Keyword.get(opts, :events_tick_timer_reset, true) && resets_count <= @events_tick_max_resets do
      self() |> send(:reset_events_tick_timer)
    end

    player = Server.get_player(socket.assigns.server)
    visible_planet = Server.get_visible_planet(socket.assigns.server)

    socket
    |> assign(
      player: player,
      player_stats: get_player_stats(player),
      visible_planet: visible_planet,
      chat: Server.get_chat(socket.assigns.server),
      current_time: get_current_time(socket.assigns.server),
      aim: get_aim(visible_planet, player)
    )
    |> play_sounds_from_player_events()
  end

  defp assign_equipment(socket) do
    player = socket.assigns.player

    {weapon, ammo_count} = get_current_weapon_with_ammo_count(player)
    melee_weapon = get_current_melee_weapon(player)
    helmet = get_current_helmet(player)
    suit = get_current_suit(player)
    boots = get_current_boots(player)

    socket
    |> assign(
      weapon: weapon,
      ammo_count: ammo_count,
      melee_weapon: melee_weapon,
      helmet: helmet,
      suit: suit,
      boots: boots
    )
  end

  defp close_all(socket) do
    socket
    |> assign(
      inventory: nil,
      item_box: nil,
      show_control_hints: false,
      item_drop_menu: false,
      item_to_drop: nil,
      dialog: nil,
      disassemble_items: nil,
      blueprints: nil,
      interaction_confirmation: nil
    )
  end

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
        assemble: %{name: ~p"/sounds/assemble.mp3", volume: 0.2},
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
        game_over: %{name: ~p"/sounds/game_over.mp3", volume: 0.1},
        open_door: %{name: ~p"/sounds/open_door.mp3", volume: 0.03},
        matches: %{name: ~p"/sounds/matches.mp3", volume: 0.3},
        radiation: %{name: ~p"/sounds/radiation.mp3", volume: 0.1},
        ice_cracked: %{name: ~p"/sounds/ice_cracked.mp3", volume: 0.1},
        monster_dead1: %{name: ~p"/sounds/monster_dead1.mp3", volume: 0.2},
        monster_dead2: %{name: ~p"/sounds/monster_dead2.mp3", volume: 0.2},
        monster_dead3: %{name: ~p"/sounds/monster_dead3.mp3", volume: 0.2},
        monster_dead4: %{name: ~p"/sounds/monster_dead4.mp3", volume: 0.2},
        fire_extinguisher: %{name: ~p"/sounds/fire_extinguisher.mp3", volume: 0.2}
      })

    assign(socket, :sounds, json)
  end

  defp shoot_sound(socket, shoot_result) do
    case shoot_result do
      {:ok, :shot} ->
        socket
        |> play_sound(socket.assigns.weapon.sound_name)
        |> play_sound_with_delay("impact")

      {:ok, :miss} ->
        play_sound(socket, socket.assigns.weapon.sound_name)

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

  defp damaged_sound(socket) do
    sound = Enum.random(["damage1", "damage2", "damage3"])
    play_sound_with_delay(socket, sound)
  end

  defp radiation_sound(socket) do
    play_sound_with_delay(socket, "radiation")
  end

  defp ice_cracked_sound(socket) do
    play_sound(socket, "ice_cracked")
  end

  defp enemy_killed_sound(socket) do
    sound = Enum.random(["monster_dead1", "monster_dead2", "monster_dead3", "monster_dead4"])
    play_sound(socket, sound)
  end

  defp dead_sound(socket) do
    play_sound(socket, "dead")
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

  defp reload_weapon(socket, item_uuid \\ :equiped) do
    result = Server.reload(socket.assigns.server, item_uuid)

    socket = base_assign(socket)

    inventory =
      if socket.assigns.inventory do
        get_player_inventory(socket)
      else
        nil
      end

    socket =
      socket
      |> assign(inventory: inventory)
      |> assign_equipment()
      |> reload_sound(result)

    {:noreply, socket}
  end

  defp open_inventory(socket) do
    inventory = get_player_inventory(socket)

    socket =
      socket
      |> close_all()
      |> assign(inventory: inventory)

    {:noreply, socket}
  end

  defp close_inventory(socket) do
    {:noreply, assign(socket, inventory: nil, inventory_type: nil)}
  end

  defp open_craft_menu(socket) do
    blueprints = Loot.blueprints(socket.assigns.blueprints_type)
    inventory = get_player_inventory(socket)

    socket =
      socket
      |> close_all()
      |> assign(blueprints: blueprints, inventory: inventory)

    {:noreply, socket}
  end

  defp close_craft_menu(socket) do
    {:noreply, assign(socket, blueprints: nil, blueprints_type: nil)}
  end

  defp open_item_box(socket) do
    case Server.loot(socket.assigns.server) do
      {:open_item_box, item_box} ->
        socket =
          socket
          |> close_all()
          |> assign(item_box: item_box)

        {:noreply, socket}

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

  defp interact(socket, params) do
    opts =
      case Map.get(params, "type", "regular") do
        "forced" -> [forced: true]
        _ -> []
      end

    case Server.interact(socket.assigns.server, opts) do
      {:ok, {:confirmation, requirements}} ->
        {:noreply, assign(socket, interaction_confirmation: requirements)}

      {:ok, {:talk, npc}} ->
        {:noreply,
         assign(socket,
           dialog: %{npc: npc},
           chat: Server.get_chat(socket.assigns.server),
           show_control_hints: false,
           inventory: nil,
           item_box: nil,
           interaction_confirmation: nil
         )}

      {:ok, {:drink, _}} ->
        socket =
          socket
          |> base_assign()
          |> assign(interaction_confirmation: nil)
          |> play_sound("drink")

        {:noreply, socket}

      {:ok, {:transform, %Object{transform_sound_name: sound_name}}} when not is_nil(sound_name) ->
        socket =
          socket
          |> base_assign()
          |> assign(interaction_confirmation: nil)
          |> play_sound(sound_name)

        {:noreply, socket}

      _ ->
        {:noreply, assign(socket, chat: Server.get_chat(socket.assigns.server), interaction_confirmation: nil)}
    end
  end

  defp craft_item(item_uuid, blueprints, socket) do
    case Enum.find(blueprints, fn bp -> bp.item.uuid == item_uuid end) do
      nil -> {:noreply, socket}
      blueprint -> do_craft_item(blueprint, socket)
    end
  end

  defp do_craft_item(blueprint, socket) do
    case Server.craft_item(socket.assigns.server, blueprint) do
      :ok ->
        socket =
          socket
          |> base_assign()
          |> assign(
            blueprints: Loot.blueprints(),
            inventory: get_player_inventory(socket)
          )
          |> play_sound("assemble")

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
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

  defp get_aim(visible_planet, %Player{aim_mode?: true} = player) do
    {weapon, _ammo_count} = get_current_weapon_with_ammo_count(player)

    planet_view_distance = div(@view_distance, 2)
    distance = min(weapon.shooting_distance, planet_view_distance)

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
    |> maybe_add_shotgun_aims(weapon, player.view_direction)
  end

  defp get_aim(_, _), do: []

  defp maybe_add_shotgun_aims(
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

  defp maybe_add_shotgun_aims(aims, _, _), do: aims

  defp move_code_to_direction(code) when code in @move_up_codes, do: :up
  defp move_code_to_direction(code) when code in @move_down_codes, do: :down
  defp move_code_to_direction(code) when code in @move_left_codes, do: :left
  defp move_code_to_direction(code) when code in @move_right_codes, do: :right

  defp schedule_events_tick do
    :erlang.start_timer(@events_tick_delay_ms, self(), :events_tick)
  end

  defp current_time_ms do
    System.system_time(:millisecond)
  end

  # coveralls-ignore-stop
end
