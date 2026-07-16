defmodule Europa.Server do
  use GenServer
  use TypedStruct
  use Gettext, backend: Europa.Gettext

  alias Europa.Games
  alias Europa.Server.Planet
  alias Europa.Server.PlanetManager
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Planet.Tiles.Objects.Object
  alias Europa.Server.Player
  alias Europa.Server.PlayerManager
  alias Europa.Server.Chat
  alias Europa.Server.Compass
  alias Europa.Server.Loot
  alias Europa.Server.Loot.Tool
  alias Europa.Server.Enemy
  alias Europa.Server.Npc
  alias Europa.Server.Action
  alias Europa.Server.Event
  alias Europa.Server.Errors
  alias Europa.Server.Characters

  import Europa.Tools.Conf
  import Europa.Tools.Randomizer

  require Logger

  @type land :: list(list())

  @type move_cost :: pos_integer()

  @finish_game_on_exit fetch_config!([__MODULE__, :finish_game_on_server_exit])
  @inactivity_timeout_ms fetch_config!([__MODULE__, :inactivity_timeout_ms])

  @crop_size fetch_config!([Planet, :crop_land_size])

  @max_efficiency fetch_config!([__MODULE__, :max_efficiency])

  @warm_up_quantity fetch_config!([:game_params, :player, :warm_up_quantity])

  @disaster_year fetch_config!([:game_params, :disaster_year])
  @craft_moves_count fetch_config!([:game_params, :craft_moves_count])
  @aim_mode_moves_penalty fetch_config!([:game_params, :player, :aim_mode_moves_penalty])

  typedstruct enforce: true do
    field :game_uuid, Ecto.UUID.t()
    field :planet, Planet.t()
    field :player, Player.t()
    field :chat, Chat.t()
    field :compass, Compass.t()
    field :killed_enemies, non_neg_integer()
    field :start_datetime, DateTime.t()
    field :current_year_after_disaster, pos_integer()
    field :current_datetime, DateTime.t()
  end

  ### PUBLIC INTERFACE ###

  @spec server_name(Ecto.UUID.t()) :: atom()
  def server_name(uuid) do
    :"server_#{uuid}"
  end

  @spec start_link(Ecto.UUID.t()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(uuid) do
    server_name = server_name(uuid)

    case Process.whereis(server_name) do
      nil ->
        GenServer.start_link(__MODULE__, uuid, name: server_name(uuid))

      pid ->
        {:ok, pid}
    end
  end

  @spec child_spec(Ecto.UUID.t()) :: Supervisor.child_spec()
  def child_spec(uuid) do
    %{
      id: server_name(uuid),
      start: {__MODULE__, :start_link, [uuid]},
      restart: :temporary,
      shutdown: 5000,
      type: :worker
    }
  end

  @spec get_pid(Ecto.UUID.t()) :: {:ok, pid()} | {:error, :not_found}
  def get_pid(uuid) do
    server_name = server_name(uuid)

    case Process.whereis(server_name) do
      nil ->
        {:error, :not_found}

      pid ->
        {:ok, pid}
    end
  end

  @spec get_player(pid()) :: Player.t()
  def get_player(server) do
    GenServer.call(server, :get_player)
  end

  @spec events_tick(pid()) :: :ok
  def events_tick(server) do
    if Process.alive?(server) do
      GenServer.call(server, :events_tick)
    else
      :ok
    end
  end

  @spec get_planet(pid()) :: Planet.t()
  def get_planet(server) do
    GenServer.call(server, :get_planet)
  end

  @spec get_chat(pid()) :: Chat.t()
  def get_chat(server) do
    GenServer.call(server, :get_chat)
  end

  @spec get_visible_planet(pid()) :: Planet.land()
  def get_visible_planet(server) do
    GenServer.call(server, :get_visible_planet)
  end

  @spec get_current_coord(pid()) :: Planet.coord()
  def get_current_coord(server) do
    GenServer.call(server, :get_current_coord)
  end

  @spec get_current_time(pid()) :: {year :: pos_integer(), day :: pos_integer(), time :: String.t()}
  def get_current_time(server) do
    GenServer.call(server, :get_current_time)
  end

  @spec move(pid(), Planet.direction()) :: {:moved, :normal | :overloaded} | :stay | {:attack, Loot.Item.item()}
  def move(server, direction) do
    GenServer.call(server, {:move, direction})
  end

  @spec loot(pid()) :: {:open_item_box, Loot.ItemBox.t()} | {:error, :nothing}
  def loot(server) do
    GenServer.call(server, :loot)
  end

  @spec take_loot(pid(), Loot.uuid()) :: {:ok, Loot.ItemBox.t()} | {:error, :nothing}
  def take_loot(server, item_uuid) do
    GenServer.call(server, {:take_loot, item_uuid})
  end

  @spec shoot(pid()) :: {:ok, :shot} | {:ok, :miss} | {:error, :no_weapon} | {:error, :empty_magazine}
  def shoot(server) do
    GenServer.call(server, :shoot)
  end

  @spec reload(pid(), Loot.uuid() | :equiped) ::
          :ok | {:error, :no_weapon} | {:error, :no_ammo} | {:error, :full_magazine}
  def reload(server, item_uuid \\ :equiped) do
    GenServer.call(server, {:reload, item_uuid})
  end

  @spec unload_weapon(pid(), Loot.uuid()) :: :ok | {:error, :not_found} | {:error, :empty_magazine}
  def unload_weapon(server, item_uuid) do
    GenServer.call(server, {:unload_weapon, item_uuid})
  end

  @spec unload_item_box_weapon(pid(), Loot.uuid()) ::
          {:ok, Loot.ItemBox.t()} | {:error, :not_found} | {:error, :empty_magazine} | {:error, :nothing}
  def unload_item_box_weapon(server, item_uuid) do
    GenServer.call(server, {:unload_item_box_weapon, item_uuid})
  end

  @spec get_inventory(pid(), Loot.item_type() | :all) :: Player.inventory()
  def get_inventory(server, type \\ :all) do
    GenServer.call(server, {:get_inventory, type})
  end

  @spec equip_item(pid(), Loot.uuid()) ::
          {:ok, Player.t()} | {:error, :not_found} | {:error, Errors.NotApplicableError.t()}
  def equip_item(server, item_uuid) do
    GenServer.call(server, {:equip_item, item_uuid})
  end

  @spec unequip_item(pid(), Loot.uuid()) ::
          {:ok, Player.t()} | {:error, :not_found} | {:error, Errors.NotApplicableError.t()}
  def unequip_item(server, item_uuid) do
    GenServer.call(server, {:unequip_item, item_uuid})
  end

  @spec get_item(pid(), Loot.uuid()) :: {:ok, Loot.Item.item()} | {:error, :not_found}
  def get_item(server, item_uuid) do
    GenServer.call(server, {:get_item, item_uuid})
  end

  @spec drop_item(pid(), Loot.uuid(), count :: pos_integer() | nil) ::
          {:ok, Player.t(), Loot.Item.item()} | {:error, :not_found}
  def drop_item(server, item_uuid, count \\ nil) do
    GenServer.call(server, {:drop_item, item_uuid, count})
  end

  @spec disassemble_item(pid(), Loot.uuid()) ::
          :ok | {:error, :not_found} | {:error, Errors.NotApplicableError.t()}
  def disassemble_item(server, item_uuid) do
    GenServer.call(server, {:disassemble_item, item_uuid})
  end

  @spec craft_item(pid(), Loot.Blueprint.t()) :: :ok | {:error, Errors.NotApplicableError.t()}
  def craft_item(server, blueprint) do
    GenServer.call(server, {:craft_item, blueprint})
  end

  @spec consume_supply(pid(), Loot.uuid()) ::
          {:ok, Loot.Item.item()} | {:error, :not_found} | {:error, Errors.NotApplicableError.t()}
  def consume_supply(server, item_uuid) do
    GenServer.call(server, {:consume_supply, item_uuid})
  end

  @spec use_tool(pid(), Loot.uuid()) :: {:ok, Loot.Item.item()} | {:error, :cant_use}
  def use_tool(server, item_uuid) do
    GenServer.call(server, {:use_tool, item_uuid})
  end

  @spec interact(pid(), opts :: keyword()) :: {:ok, Planet.interaction()} | {:error, :nothing}
  def interact(server, opts \\ []) do
    GenServer.call(server, {:interact, opts})
  end

  @spec toggle_aim_mode(pid()) :: :ok | {:error, :no_weapon}
  def toggle_aim_mode(server) do
    GenServer.call(server, :toggle_aim_mode)
  end

  @spec get_compass(pid()) :: Compass.t()
  def get_compass(server) do
    GenServer.call(server, :get_compass)
  end

  @spec add_compass_target(pid(), Compass.Target.description()) ::
          {:ok, Compass.t()} | {:error, {:limit_reached, pos_integer()}}
  def add_compass_target(server, description) when is_binary(description) do
    GenServer.call(server, {:add_compass_target, description})
  end

  @spec delete_compass_target(pid(), Compass.Target.uuid()) :: {:ok, Compass.t()} | {:error, :not_found}
  def delete_compass_target(server, uuid) do
    GenServer.call(server, {:delete_compass_target, uuid})
  end

  @spec follow_compass_target(pid(), Compass.Target.uuid()) :: {:ok, Compass.t()} | {:error, :not_found}
  def follow_compass_target(server, uuid) do
    GenServer.call(server, {:follow_compass_target, uuid})
  end

  @spec unfollow_compass_target(pid()) :: {:ok, Compass.t()} | {:error, :not_found}
  def unfollow_compass_target(server) do
    GenServer.call(server, :unfollow_compass_target)
  end

  ### CALLBACKS ###

  # NOTICE: Do not return updated planet or player structs if callback calls :tick
  # Game client should get updated structs by itself, otherwise client will get not actual data

  @impl true
  def init(uuid) do
    Process.flag(:trap_exit, true)

    {:ok, characters_pid} = Characters.start_link()
    {:ok, current_character} = Characters.pick_main(characters_pid)
    current_year_after_disaster = current_character.current_age - current_character.age_at_disaster
    current_year = @disaster_year + current_year_after_disaster
    planet = PlanetManager.new(year: current_year, characters_pid: characters_pid)
    player_initial_stand_on_tile = PlanetManager.player_initial_stand_on_tile(planet)

    weapon = Loot.generate_item(:weapon)
    helmet = Loot.generate_item(:helmet)
    suit = Loot.generate_item(:suit)
    boots = Loot.generate_item(:boots)

    supplies = initial_supplies()
    ammo = initial_ammo()
    melee_weapon = initial_melee_weapon()

    items =
      ([weapon, helmet, suit, boots, melee_weapon] ++ supplies ++ ammo)
      |> Enum.filter(&(not is_nil(&1)))

    player =
      PlayerManager.new(current_character)
      |> PlayerManager.stand_on(player_initial_stand_on_tile)
      |> add_player_items(items)
      |> equip_player_items(items)

    player = PlayerManager.warm_up(player, player.max_warm)

    [bio_message, story_message] = initial_messages(current_year_after_disaster, current_character)

    chat =
      bio_message
      |> Chat.new()
      |> Chat.add_message(story_message)

    compass = Compass.new()

    initial_datetime = initial_datetime()

    state = %__MODULE__{
      game_uuid: uuid,
      planet: planet,
      chat: chat,
      compass: compass,
      player: player,
      killed_enemies: 0,
      start_datetime: initial_datetime,
      current_year_after_disaster: current_year_after_disaster,
      current_datetime: initial_datetime
    }

    {:ok, state, @inactivity_timeout_ms}
  end

  @impl true
  def handle_call(:get_planet, _from, state) do
    {:reply, state.planet, state, @inactivity_timeout_ms}
  end

  def handle_call(:get_visible_planet, _from, state) do
    {:reply, PlanetManager.get_visible_land(state.planet, state.current_datetime), state, @inactivity_timeout_ms}
  end

  def handle_call(:get_player, _from, state) do
    {:reply, state.player, state, @inactivity_timeout_ms}
  end

  def handle_call(:events_tick, _from, state) do
    updated_player = PlayerManager.remove_last_event(state.player)
    updated_planet = PlanetManager.remove_last_events(state.planet)

    {:reply, :ok, struct!(state, player: updated_player, planet: updated_planet), @inactivity_timeout_ms}
  end

  def handle_call(:get_chat, _from, state) do
    {:reply, state.chat, state, @inactivity_timeout_ms}
  end

  def handle_call(:get_current_time, _from, state) do
    {:reply, do_get_current_time(state), state, @inactivity_timeout_ms}
  end

  def handle_call(:get_current_coord, _from, state) do
    {:reply, state.planet.current_coord, state, @inactivity_timeout_ms}
  end

  def handle_call({:move, direction}, {caller_pid, _}, state) do
    cond do
      direction != state.player.view_direction ->
        change_view_direction(direction, state, caller_pid)

      PlayerManager.weight_ratio(state.player) >= 1.5 ->
        message = overloaded_message()

        {:reply, :stay, struct!(state, chat: Chat.add_message(state.chat, message)), @inactivity_timeout_ms}

      true ->
        do_move(direction, state, caller_pid)
    end
  end

  def handle_call(:loot, _from, state) do
    case PlanetManager.loot(state.planet, state.player) do
      {:open_item_box, _item_box} = result ->
        {:reply, result, state, @inactivity_timeout_ms}

      {:error, :nothing} = error ->
        message = nothing_to_loot_message()
        {:reply, error, struct!(state, chat: Chat.add_message(state.chat, message)), @inactivity_timeout_ms}
    end
  end

  def handle_call({:take_loot, item_uuid}, _from, state) do
    case PlanetManager.take_loot(state.planet, state.player, item_uuid) do
      {:ok, updated_planet, updated_player, updated_item_box} ->
        {:reply, {:ok, updated_item_box}, struct!(state, planet: updated_planet, player: updated_player),
         @inactivity_timeout_ms}

      _ ->
        {:reply, {:error, :nothing}, state, @inactivity_timeout_ms}
    end
  end

  def handle_call({:equip_item, item_uuid}, _from, state) do
    case PlayerManager.equip_item(state.player, item_uuid) do
      {:ok, updated_player} ->
        {:reply, {:ok, updated_player}, struct!(state, player: updated_player), @inactivity_timeout_ms}

      error ->
        {:reply, error, state, @inactivity_timeout_ms}
    end
  end

  def handle_call({:unequip_item, item_uuid}, _from, state) do
    case PlayerManager.unequip_item(state.player, item_uuid) do
      {:ok, updated_player} ->
        {:reply, {:ok, updated_player}, struct!(state, player: updated_player), @inactivity_timeout_ms}

      error ->
        {:reply, error, state, @inactivity_timeout_ms}
    end
  end

  def handle_call({:get_item, item_uuid}, _from, state) do
    result = PlayerManager.get_item(state.player, item_uuid)
    {:reply, result, state, @inactivity_timeout_ms}
  end

  def handle_call({:drop_item, item_uuid, count}, _from, state) do
    case PlayerManager.drop_item(state.player, item_uuid, count) do
      {:ok, updated_player, _item} ->
        {:reply, {:ok, updated_player}, struct!(state, player: updated_player), @inactivity_timeout_ms}

      error ->
        {:reply, error, state, @inactivity_timeout_ms}
    end
  end

  def handle_call({:disassemble_item, item_uuid}, caller_pid, state) do
    case PlayerManager.disassemble_item(state.player, item_uuid) do
      {:ok, updated_player, item} ->
        disassembled_message = disassembled_message(item, @craft_moves_count)

        updated_chat =
          state.chat
          |> Chat.add_message(disassembled_message)

        {:reply, :ok, struct!(state, player: updated_player, chat: updated_chat),
         {:continue, {:tick, @craft_moves_count, caller_pid}}}

      error ->
        {:reply, error, state, @inactivity_timeout_ms}
    end
  end

  def handle_call({:craft_item, blueprint}, caller_pid, state) do
    case PlayerManager.craft_item(state.player, %Loot.Blueprint{} = blueprint) do
      {:ok, updated_player} ->
        crafted_message = crafted_message(blueprint.item, @craft_moves_count)

        updated_chat =
          state.chat
          |> Chat.add_message(crafted_message)

        {:reply, :ok, struct!(state, player: updated_player, chat: updated_chat),
         {:continue, {:tick, @craft_moves_count, caller_pid}}}

      error ->
        {:reply, error, state, @inactivity_timeout_ms}
    end
  end

  def handle_call(:toggle_aim_mode, caller_pid, state) do
    case PlayerManager.toggle_aim_mode(state.player) do
      {:ok, player} ->
        moves_count = 1
        aim_mode_switched_message = aim_mode_switched_message(moves_count)

        updated_chat =
          state.chat
          |> Chat.add_message(aim_mode_switched_message)

        {:reply, :ok, struct!(state, player: player, chat: updated_chat), {:continue, {:tick, moves_count, caller_pid}}}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call(:shoot, {caller_pid, _}, state) do
    case PlanetManager.shoot(state.planet, state.player) do
      {:ok, {updated_planet, updated_player, damaged_enemies, moves_count}} ->
        moves_count =
          maybe_decrease_moves_count_with_efficiency(moves_count, updated_player.efficiency)
          |> maybe_increase_moves_count_with_aim_mode(updated_player)

        shoot_message = shoot_message(moves_count)

        updated_chat =
          state.chat
          |> Chat.add_message(shoot_message)
          |> add_damage_messages_to_chat(damaged_enemies)

        killed_enemies_count = killed_enemies_count(damaged_enemies)
        updated_player = maybe_add_killed_enemy_event(updated_player, killed_enemies_count)

        {:reply, {:ok, :shot},
         struct!(state,
           planet: updated_planet,
           player: updated_player,
           chat: updated_chat,
           killed_enemies: state.killed_enemies + killed_enemies_count
         ), {:continue, {:tick, moves_count, caller_pid}}}

      {:error, :miss, updated_player, moves_count} ->
        moves_count =
          maybe_decrease_moves_count_with_efficiency(moves_count, updated_player.efficiency)
          |> maybe_increase_moves_count_with_aim_mode(updated_player)

        shoot_message = shoot_message(moves_count)
        miss_message = miss_message()

        updated_chat =
          state.chat
          |> Chat.add_message(shoot_message)
          |> Chat.add_message(miss_message)

        {:reply, {:ok, :miss}, struct!(state, player: updated_player, chat: updated_chat),
         {:continue, {:tick, moves_count, caller_pid}}}

      {:error, :no_weapon} ->
        no_weapon_message = no_weapon_message()
        updated_chat = Chat.add_message(state.chat, no_weapon_message)
        {:reply, {:error, :no_weapon}, struct!(state, chat: updated_chat), @inactivity_timeout_ms}

      {:error, :empty_magazine} ->
        empty_magazine_message = empty_magazine_message()
        updated_chat = Chat.add_message(state.chat, empty_magazine_message)
        {:reply, {:error, :empty_magazine}, struct!(state, chat: updated_chat), @inactivity_timeout_ms}
    end
  end

  def handle_call({:reload, item_uuid}, {caller_pid, _}, state) do
    result =
      case item_uuid do
        :equiped -> PlayerManager.reload_weapon(state.player)
        _ -> PlayerManager.reload_weapon(state.player, item_uuid)
      end

    case result do
      {:ok, updated_player, weapon} ->
        moves_count = maybe_decrease_moves_count_with_efficiency(weapon.reload_cost, updated_player.efficiency)
        reloaded_message = reloaded_message(weapon, moves_count)

        updated_chat =
          state.chat
          |> Chat.add_message(reloaded_message)

        {:reply, :ok, struct!(state, player: updated_player, chat: updated_chat),
         {:continue, {:tick, moves_count, caller_pid}}}

      {:error, :no_weapon} ->
        no_weapon_message = no_weapon_message()
        updated_chat = Chat.add_message(state.chat, no_weapon_message)
        {:reply, {:error, :no_weapon}, struct!(state, chat: updated_chat), @inactivity_timeout_ms}

      {:error, :no_ammo} ->
        no_ammo_message = no_ammo_message()
        updated_chat = Chat.add_message(state.chat, no_ammo_message)
        {:reply, {:error, :no_ammo}, struct!(state, chat: updated_chat), @inactivity_timeout_ms}

      {:error, :full_magazine} ->
        full_magazine_message = full_magazine_message()
        updated_chat = Chat.add_message(state.chat, full_magazine_message)
        {:reply, {:error, :full_magazine}, struct!(state, chat: updated_chat), @inactivity_timeout_ms}
    end
  end

  def handle_call({:unload_weapon, item_uuid}, {caller_pid, _}, state) do
    case PlayerManager.unload_weapon(state.player, item_uuid) do
      {:ok, updated_player, weapon} ->
        moves_count = maybe_decrease_moves_count_with_efficiency(weapon.reload_cost, updated_player.efficiency)
        unloaded_message = unloaded_message(weapon, moves_count)

        updated_chat =
          state.chat
          |> Chat.add_message(unloaded_message)

        {:reply, :ok, struct!(state, player: updated_player, chat: updated_chat),
         {:continue, {:tick, moves_count, caller_pid}}}

      {:error, :empty_magazine} = error ->
        empty_magazine_message = empty_magazine_message()
        updated_chat = Chat.add_message(state.chat, empty_magazine_message)
        {:reply, error, struct!(state, chat: updated_chat), @inactivity_timeout_ms}

      error ->
        {:reply, error, state, @inactivity_timeout_ms}
    end
  end

  def handle_call({:unload_item_box_weapon, item_uuid}, {caller_pid, _}, state) do
    case PlanetManager.unload_item_box_weapon(state.planet, state.player, item_uuid) do
      {:ok, updated_planet, updated_player, updated_item_box, weapon} ->
        moves_count = maybe_decrease_moves_count_with_efficiency(weapon.reload_cost, updated_player.efficiency)
        unloaded_message = unloaded_message(weapon, moves_count)

        updated_chat =
          state.chat
          |> Chat.add_message(unloaded_message)

        {:reply, {:ok, updated_item_box},
         struct!(state, planet: updated_planet, player: updated_player, chat: updated_chat),
         {:continue, {:tick, moves_count, caller_pid}}}

      {:error, :empty_magazine} = error ->
        empty_magazine_message = empty_magazine_message()
        updated_chat = Chat.add_message(state.chat, empty_magazine_message)
        {:reply, error, struct!(state, chat: updated_chat), @inactivity_timeout_ms}

      error ->
        {:reply, error, state, @inactivity_timeout_ms}
    end
  end

  def handle_call({:consume_supply, item_uuid}, {caller_pid, _}, state) do
    case PlayerManager.consume_supply(state.player, item_uuid) do
      {:ok, updated_player, supply} ->
        moves_count = maybe_decrease_moves_count_with_efficiency(supply.consume_cost, updated_player.efficiency)
        consumed_supply_message = consumed_supply_message(supply, moves_count)

        updated_chat =
          state.chat
          |> Chat.add_message(consumed_supply_message)

        {:reply, {:ok, supply}, struct!(state, player: updated_player, chat: updated_chat),
         {:continue, {:tick, moves_count, caller_pid}}}

      error ->
        {:reply, error, state, @inactivity_timeout_ms}
    end
  end

  def handle_call({:use_tool, item_uuid}, {caller_pid, _}, state) do
    case PlayerManager.get_item(state.player, item_uuid) do
      {:ok, tool} ->
        tool
        |> struct!(count: 1)
        |> do_use_tool(state, caller_pid)

      _error ->
        process_cannot_use_tool(state)
    end
  end

  def handle_call({:get_inventory, type}, _from, state) do
    {:reply, PlayerManager.get_inventory(state.player, type), state, @inactivity_timeout_ms}
  end

  def handle_call({:interact, opts}, _from, state) do
    case PlanetManager.interact(state.planet, state.player.view_direction, opts) do
      {:ok, updated_planet, {:drink, :radioactive_water} = interaction} ->
        updated_player =
          state.player
          |> PlayerManager.increase_thirst(-10)
          |> PlayerManager.increase_radiation(10)

        drink_radioactive_water_message = drink_radioactive_water_message()
        radiation_message = radiation_contamination_message()

        updated_chat =
          state.chat
          |> Chat.add_message(drink_radioactive_water_message)
          |> Chat.add_message(radiation_message)

        {:reply, {:ok, interaction}, struct!(state, planet: updated_planet, player: updated_player, chat: updated_chat),
         @inactivity_timeout_ms}

      {:ok, updated_planet,
       {:transform, %Object{}, %Object.Transform{transform_requirements: {:tools, required_tools}} = transform} =
           interaction}
      when is_list(required_tools) ->
        case PlayerManager.use_tools(state.player, required_tools) do
          {:ok, updated_player} ->
            updated_chat = maybe_add_transform_message(state.chat, transform)

            {:reply, {:ok, interaction},
             struct!(state, planet: updated_planet, player: updated_player, chat: updated_chat), @inactivity_timeout_ms}

          _ ->
            {:reply, {:error, :nothing}, state}
        end

      {:ok, updated_planet, interaction} ->
        {:reply, {:ok, interaction}, struct!(state, planet: updated_planet), @inactivity_timeout_ms}

      _ ->
        nothing_to_interact_message = nothing_to_interact_message()

        updated_chat =
          state.chat
          |> Chat.add_message(nothing_to_interact_message)

        {:reply, {:error, :nothing}, struct!(state, chat: updated_chat), @inactivity_timeout_ms}
    end
  end

  def handle_call(:get_compass, _caller_pid, state) do
    {:reply, state.compass, state, @inactivity_timeout_ms}
  end

  def handle_call({:add_compass_target, description}, _caller_pid, state) do
    target = Compass.Target.new(state.planet.current_coord, description)

    case Compass.add_target(state.compass, target) do
      {:ok, updated_compass} ->
        {:reply, {:ok, updated_compass}, struct!(state, compass: updated_compass), @inactivity_timeout_ms}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:delete_compass_target, uuid}, _caller_pid, state) do
    case Compass.delete_target(state.compass, uuid) do
      {:ok, updated_compass} ->
        {:reply, {:ok, updated_compass}, struct!(state, compass: updated_compass), @inactivity_timeout_ms}

      error ->
        {:reply, error, state, @inactivity_timeout_ms}
    end
  end

  def handle_call({:follow_compass_target, uuid}, _caller_pid, state) do
    case Compass.follow_target(state.compass, uuid) do
      {:ok, updated_compass} ->
        {:reply, {:ok, updated_compass}, struct!(state, compass: updated_compass), @inactivity_timeout_ms}

      error ->
        {:reply, error, state, @inactivity_timeout_ms}
    end
  end

  def handle_call(:unfollow_compass_target, _caller_pid, state) do
    updated_compass = Compass.unfollow_target(state.compass)
    {:reply, {:ok, updated_compass}, struct!(state, compass: updated_compass), @inactivity_timeout_ms}
  end

  @impl true
  def handle_info(:game_over, state) do
    {_year, days, _} = do_get_current_time(state)

    stats = %{
      moves_count: state.planet.moves_count,
      great_red_spots: state.planet.great_red_spots,
      killed_enemies: state.killed_enemies,
      days: days - 1
    }

    Games.update_stats(state.game_uuid, stats)

    Process.exit(self(), :normal)
    {:noreply, state}
  end

  def handle_info({:EXIT, _pid, reason}, state) do
    Logger.warning("Server exited with reason: #{inspect(reason)}")
    finish_game_if_active(state.game_uuid)

    {:stop, reason, state}
  end

  def handle_info(:timeout, state) do
    self() |> send(:game_over)
    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state, @inactivity_timeout_ms}
  end

  @impl true
  def handle_continue({:tick, moves_count, caller_pid}, state) do
    {:ok, updated_planet, planet_actions} = PlanetManager.tick(state.planet, moves_count)
    {:ok, updated_player, player_actions} = PlayerManager.tick(state.player, moves_count)

    actions = planet_actions ++ player_actions

    updated_player = process_actions(updated_player, actions, state.game_uuid, caller_pid)

    updated_chat =
      state.chat
      |> add_action_messages_to_chat(actions)
      |> maybe_add_radiation_contamination_message(state.player, updated_player)

    {:noreply,
     struct!(state,
       planet: updated_planet,
       player: updated_player,
       chat: updated_chat,
       current_datetime: shift_datetime(state.current_datetime, moves_count)
     ), @inactivity_timeout_ms}
  end

  @impl true
  def terminate(_, state) do
    finish_game_if_active(state.game_uuid)
    :ok
  end

  ### PRIVATE ###

  defp do_use_tool(%Tool{using_type: {:put_object, _}} = tool, state, caller_pid) do
    with {:ok, updated_player} <- PlayerManager.use_tools(state.player, [tool]),
         {:ok, updated_planet} <- PlanetManager.use_tool(state.planet, tool, updated_player.view_direction) do
      moves_count = tool.use_cost

      tool_used_message = tool_used_message(tool)

      updated_chat =
        state.chat
        |> Chat.add_message(tool_used_message)

      {:reply, {:ok, tool}, struct!(state, planet: updated_planet, player: updated_player, chat: updated_chat),
       {:continue, {:tick, moves_count, caller_pid}}}
    else
      _error ->
        process_cannot_use_tool(state)
    end
  end

  defp do_use_tool(_, state, _) do
    process_cannot_use_tool(state)
  end

  defp process_cannot_use_tool(state) do
    cant_do_it_message = cant_do_it_message()

    updated_chat =
      state.chat
      |> Chat.add_message(cant_do_it_message)

    {:reply, {:error, :cant_use}, struct!(state, chat: updated_chat)}
  end

  defp do_get_current_time(state) do
    current_year = @disaster_year + (state.player.character.current_age - state.player.character.age_at_disaster)

    current_date = Timex.to_date(state.current_datetime)
    start_date = Timex.to_date(state.start_datetime)

    days_diff = Timex.diff(current_date, start_date, :days)

    day =
      if days_diff == 0 do
        1
      else
        days_diff + 1
      end

    current_time = Timex.format!(state.current_datetime, "{h24}:{m}")
    {current_year, day, current_time}
  end

  defp maybe_crop_land(state) do
    if PlanetManager.land_size(state.planet) >= @crop_size do
      {:ok, updated_planet} = PlanetManager.crop_land(state.planet)
      message = crop_planet_land_message()

      struct!(state,
        planet: updated_planet,
        chat: Chat.add_message(state.chat, message)
      )
    else
      state
    end
  end

  defp killed_enemies_count(damaged_enemies) do
    Enum.count(damaged_enemies, fn
      {%Enemy{} = enemy, _} -> enemy.health == 0
      {_, _} -> false
    end)
  end

  defp change_view_direction(direction, state, caller_pid) do
    moves_count = 1

    updated_player =
      state.player
      |> PlayerManager.change_view_direction(direction)

    moved_message = moved_message(moves_count, updated_player.stand_on)

    updated_chat =
      state.chat
      |> Chat.add_message(moved_message)

    {:reply, {:moved, :normal}, struct!(state, player: updated_player, chat: updated_chat),
     {:continue, {:tick, moves_count, caller_pid}}}
  end

  defp do_move(direction, state, caller_pid) do
    case PlanetManager.move(state.planet, direction, state.player) do
      {:moved, updated_planet, moves_count, step_on_tile, next_to_interactive?} ->
        weight_ratio = PlayerManager.weight_ratio(state.player)
        status = if weight_ratio < 1.0, do: :normal, else: :overloaded

        moves_count =
          moves_count
          |> maybe_decrease_moves_count_with_efficiency(state.player.efficiency)
          |> maybe_increase_moves_count_with_inventory_weight(weight_ratio)

        moved_message = moved_message(moves_count, step_on_tile)

        updated_chat =
          state.chat
          |> Chat.add_message(moved_message)

        updated_player =
          state.player
          |> PlayerManager.stand_on(step_on_tile)
          |> maybe_add_interested_event(next_to_interactive?)
          |> maybe_finish_game(state.game_uuid, caller_pid)

        {:reply, {:moved, status},
         struct!(state,
           planet: updated_planet,
           player: updated_player,
           chat: updated_chat
         )
         |> maybe_crop_land(), {:continue, {:tick, moves_count, caller_pid}}}

      {:attack, updated_planet, damaged_enemies, moves_count} ->
        weight_ratio = PlayerManager.weight_ratio(state.player)

        {status, updated_chat} =
          if Enum.empty?(damaged_enemies) do
            miss_message = miss_message()

            updated_chat =
              state.chat
              |> Chat.add_message(miss_message)

            {:miss, updated_chat}
          else
            moves_count =
              moves_count
              |> maybe_decrease_moves_count_with_efficiency(state.player.efficiency)
              |> maybe_increase_moves_count_with_inventory_weight(weight_ratio)
              |> maybe_increase_moves_count_with_aim_mode(state.player)

            updated_chat =
              state.chat
              |> add_punch_message_to_chat(state.player, moves_count)
              |> add_damage_messages_to_chat(damaged_enemies)

            {:hitted, updated_chat}
          end

        killed_enemies_count = killed_enemies_count(damaged_enemies)

        updated_player = maybe_add_killed_enemy_event(state.player, killed_enemies_count)

        {:reply, {:attack, status},
         struct!(state,
           planet: updated_planet,
           player: updated_player,
           chat: updated_chat,
           killed_enemies: state.killed_enemies + killed_enemies_count
         ), {:continue, {:tick, moves_count, caller_pid}}}

      {:stay, tile} ->
        message = cant_move_message(tile)

        {:reply, :stay,
         struct!(state,
           chat: Chat.add_message(state.chat, message)
         )}
    end
  end

  defp maybe_decrease_moves_count_with_efficiency(moves_count, efficiency) do
    decreased_moves_count = max(moves_count - 1, 1)

    if efficiency >= @max_efficiency do
      decreased_moves_count
    else
      if m_to_n?(efficiency, @max_efficiency) do
        decreased_moves_count
      else
        moves_count
      end
    end
  end

  defp maybe_increase_moves_count_with_aim_mode(moves_count, %Player{aim_mode?: true}) do
    moves_count + @aim_mode_moves_penalty
  end

  defp maybe_increase_moves_count_with_aim_mode(moves_count, _player), do: moves_count

  defp maybe_increase_moves_count_with_inventory_weight(moves_count, weight_ratio) do
    cond do
      weight_ratio <= 1.0 -> moves_count
      weight_ratio <= 1.1 -> moves_count + 1
      weight_ratio <= 1.2 -> moves_count + 2
      weight_ratio <= 1.3 -> moves_count + 3
      true -> moves_count + 4
    end
  end

  defp add_player_items(%Player{} = player, items) when is_list(items) do
    Enum.reduce(items, player, fn item, player ->
      {:ok, updated_player} = PlayerManager.add_item(player, item)
      updated_player
    end)
  end

  defp equip_player_items(%Player{} = player, items) when is_list(items) do
    Enum.reduce(items, player, fn item, player ->
      if Loot.Item.equipable?(item) do
        {:ok, updated_player} = PlayerManager.equip_item(player, item.uuid)
        updated_player
      else
        player
      end
    end)
  end

  defp process_actions(%Player{} = player, actions, game_uuid, caller_pid) when is_list(actions) do
    Enum.reduce(actions, player, fn action, player ->
      case action do
        %Action{action_type: :attack, subject: enemy} ->
          blood_tile = blood_tile(player.stand_on)

          player
          |> PlayerManager.take_damage(enemy.damage)
          |> PlayerManager.stand_on(blood_tile)
          |> maybe_add_radiation(enemy)
          |> maybe_decrease_warm(enemy)

        %Action{action_type: :warm_up, subject: :player} ->
          PlayerManager.warm_up(player, @warm_up_quantity)

        %Action{action_type: :radiation_contamination, subject: :player} ->
          PlayerManager.increase_radiation(player, 3)

        _ ->
          player
      end
    end)
    |> maybe_finish_game(game_uuid, caller_pid)
  end

  defp maybe_add_radiation(%Player{} = player, %Enemy{radioactive?: true}) do
    if m_to_n?(1, 10) do
      PlayerManager.increase_radiation(player, 5)
    else
      player
    end
  end

  defp maybe_add_radiation(player, _), do: player

  defp maybe_decrease_warm(%Player{} = player, %Enemy{cold?: true}) do
    if m_to_n?(1, 10) do
      PlayerManager.warm_up(player, -5)
    else
      player
    end
  end

  defp maybe_decrease_warm(player, _), do: player

  defp maybe_add_interested_event(%Player{} = player, true = _next_to_interactive_event?) do
    interested_event = Event.new(:interested)
    PlayerManager.add_events(player, [interested_event])
  end

  defp maybe_add_interested_event(player, _), do: player

  defp maybe_add_killed_enemy_event(%Player{} = player, 0), do: player

  defp maybe_add_killed_enemy_event(%Player{} = player, _) do
    PlayerManager.add_events(player, [Event.new(:enemy_killed)])
  end

  # this is for "skip" object, see Objects module
  defp blood_tile(%Object{name: "", image_name: "", stand_on: tile} = object) do
    blood_tile = blood_tile(tile)
    Object.stand_on(object, blood_tile)
  end

  defp blood_tile(tile) do
    case Tiles.tile_by_atom_value(tile) do
      %Tiles.Tile{blood_version: bv} when not is_nil(bv) -> bv
      _ -> tile
    end
  end

  defp maybe_finish_game(%Player{health: 0} = player, game_uuid, caller_pid) do
    Games.finish_game(game_uuid, :died)
    caller_pid |> send(:game_over)
    Process.send_after(self(), :game_over, 800)
    player
  end

  defp maybe_finish_game(player, _, _) do
    player
  end

  defp finish_game_if_active(game_uuid) do
    if @finish_game_on_exit do
      with {:ok, %Games.Game{state: :active}} <- Games.get_by_uuid(game_uuid) do
        Games.finish_game(game_uuid, :server_error)
      end
    end
  end

  defp initial_messages(year, %Characters.Character{} = character) do
    gender = Characters.Character.readable_gender(character)

    bio_msg =
      [
        "#{year} ",
        ngettext("year", "years", year),
        " after disaster.",
        "\n",
        gettext("My name is"),
        " #{character.name}.",
        "\n",
        gettext("I'm"),
        " ",
        "#{character.current_age} ",
        gettext("years old"),
        " ",
        gender,
        "."
      ]
      |> Enum.join()

    story_msg = Characters.Character.random_story(character)

    bio = Chat.Message.new(bio_msg, :story)
    story = Chat.Message.new(story_msg, :story)
    [bio, story]
  end

  defp maybe_add_transform_message(chat, %Object.Transform{message: nil}), do: chat

  defp maybe_add_transform_message(chat, %Object.Transform{transform_cost: moves_count} = transform) do
    moves_count =
      if is_integer(moves_count) && moves_count > 0 do
        moves_count
      else
        0
      end

    message = Chat.Message.new(transform.message, :regular, moves_count)
    Chat.add_message(chat, message)
  end

  defp moved_message(moves_count, step_on_tile) do
    tile_name = PlanetManager.readable_tile_name(step_on_tile)
    msg = gettext("You walked at %{tile_name}", tile_name: tile_name)

    Chat.Message.new(msg, :regular, moves_count)
  end

  defp tool_used_message(tool) do
    msg = gettext("You used %{tool_name}", tool_name: tool.name)
    Chat.Message.new(msg, :regular, tool.use_cost)
  end

  def cant_do_it_message do
    msg = gettext("It's not possible to do this now.")
    Chat.Message.new(msg, :danger)
  end

  defp cant_move_message(tile) do
    tile_name = PlanetManager.readable_tile_name(tile)
    msg = gettext("You can't walk through %{tile_name}", tile_name: tile_name)
    Chat.Message.new(msg, :warning)
  end

  defp overloaded_message do
    msg = gettext("You can't walk because you're overloaded")
    Chat.Message.new(msg, :warning)
  end

  defp nothing_to_loot_message do
    msg = gettext("There is nothing to loot")
    Chat.Message.new(msg, :warning)
  end

  defp nothing_to_interact_message do
    msg = gettext("There is nothing to interact with")
    Chat.Message.new(msg, :warning)
  end

  defp miss_message do
    msg = gettext("You didn't hit anyone")
    Chat.Message.new(msg, :warning)
  end

  defp no_weapon_message do
    msg = gettext("You have no weapon in your hands!")
    Chat.Message.new(msg, :warning)
  end

  defp no_ammo_message do
    msg = gettext("You don't have any ammo to reload your weapon!")
    Chat.Message.new(msg, :warning)
  end

  defp empty_magazine_message do
    msg = gettext("Your weapon is unloaded.")
    Chat.Message.new(msg, :warning)
  end

  defp full_magazine_message do
    msg = gettext("Your weapon is fully loaded.")
    Chat.Message.new(msg, :warning)
  end

  defp reloaded_message(%Loot.Weapon{} = weapon, moves_count) do
    msg = gettext("You reloaded %{weapon_name}", weapon_name: weapon.name)
    Chat.Message.new(msg, :regular, moves_count)
  end

  defp unloaded_message(%Loot.Weapon{} = weapon, moves_count) do
    msg = gettext("You unloaded %{weapon_name}", weapon_name: weapon.name)
    Chat.Message.new(msg, :regular, moves_count)
  end

  defp shoot_message(moves_count) do
    msg = gettext("You fired")
    Chat.Message.new(msg, :regular, moves_count)
  end

  defp aim_mode_switched_message(moves_count) do
    msg = gettext("You have changed the aiming mode")
    Chat.Message.new(msg, :regular, moves_count)
  end

  defp disassembled_message(item, moves_count) do
    msg = gettext("You have disassembled %{item_name}", item_name: Loot.Item.composed_name(item))
    Chat.Message.new(msg, :regular, moves_count)
  end

  defp crafted_message(item, moves_count) do
    msg = gettext("You have crafted %{item_name}", item_name: Loot.Item.composed_name(item))
    Chat.Message.new(msg, :regular, moves_count)
  end

  defp consumed_supply_message(%Loot.Supply{} = supply, moves_count) do
    msg = gettext("You consumed %{supply_name}", supply_name: supply.name)
    Chat.Message.new(msg, :regular, moves_count)
  end

  defp radiation_contamination_message do
    msg = gettext("You received a dose of radiation!")
    Chat.Message.new(msg, :danger)
  end

  defp drink_radioactive_water_message do
    msg = gettext("You drank radioactive water!")
    Chat.Message.new(msg, :warning)
  end

  defp crop_planet_land_message do
    msg =
      gettext(
        "Jupiter shows the Great Red Spot, a monstrous storm swept everything around, but you miraculously survived"
      )

    Chat.Message.new(msg, :story)
  end

  defp action_message(%Action{subject: :player, action_type: :frostbite}) do
    msg = gettext("You get frostbite!")
    Chat.Message.new(msg, :danger)
  end

  defp action_message(%Action{
         subject: %Enemy{} = healer_enemy,
         action_type: {:healed, %Enemy{} = healed_enemy, heal_unit}
       }) do
    msg =
      gettext("%{healer_name} healed %{healed_name} for %{units} HP",
        healer_name: healer_enemy.name,
        healed_name: healed_enemy.name,
        units: heal_unit
      )

    Chat.Message.new(msg, :warning)
  end

  defp action_message(%Action{subject: :player, action_type: :dehydration}) do
    msg = gettext("You are dying of dehydration!")
    Chat.Message.new(msg, :danger)
  end

  defp action_message(%Action{subject: :player, action_type: :hunger}) do
    msg = gettext("You are dying of hunger!")
    Chat.Message.new(msg, :danger)
  end

  defp action_message(%Action{subject: :player, action_type: :radiation_contamination}) do
    radiation_contamination_message()
  end

  defp action_message(%Action{subject: :player, action_type: :radiation_damage}) do
    msg = gettext("You are dying of radiation!")
    Chat.Message.new(msg, :danger)
  end

  defp action_message(%Action{subject: %Enemy{} = enemy, action_type: :chasing}) do
    msg = gettext("%{enemy_name} is chasing you", enemy_name: enemy.name)
    Chat.Message.new(msg, :warning)
  end

  defp action_message(%Action{subject: %Enemy{} = enemy, action_type: :attack}) do
    msg = gettext("%{enemy_name} attacks you and deals %{damage} damage", enemy_name: enemy.name, damage: enemy.damage)
    Chat.Message.new(msg, :danger)
  end

  defp action_message(%Action{subject: %Enemy{} = enemy, action_type: :miss_attack}) do
    msg = gettext("%{enemy_name} attacks you but misses.", enemy_name: enemy.name)
    Chat.Message.new(msg, :warning)
  end

  defp action_message(%Action{subject: {%Enemy{} = enemy, %Npc{} = npc}, action_type: :enemy_killed_npc}) do
    msg = gettext("%{enemy_name} killed %{character_name}", enemy_name: enemy.name, character_name: npc.character.name)
    Chat.Message.new(msg, :danger)
  end

  defp action_message(_), do: nil

  defp add_action_messages_to_chat(%Chat{} = chat, actions) do
    Enum.reduce(actions, chat, fn action, chat ->
      case action_message(action) do
        nil -> chat
        message -> Chat.add_message(chat, message)
      end
    end)
  end

  defp add_damage_messages_to_chat(%Chat{} = chat, damaged_enemies) do
    Enum.reduce(damaged_enemies, chat, fn
      {%Enemy{} = enemy, damage}, chat ->
        msg =
          if enemy.health > 0 do
            gettext("You hit %{enemy_name} and dealt %{damage} damage to it!", enemy_name: enemy.name, damage: damage)
          else
            gettext("You killed %{enemy_name}", enemy_name: enemy.name)
          end

        message = Chat.Message.new(msg, :regular)
        Chat.add_message(chat, message)

      {%Npc{} = npc, _}, chat ->
        msg = gettext("You killed %{character_name}", character_name: npc.character.name)
        message = Chat.Message.new(msg, :danger)
        Chat.add_message(chat, message)
    end)
  end

  defp add_punch_message_to_chat(%Chat{} = chat, player, moves_count) do
    melee_weapon_name =
      case PlayerManager.get_equiped_melee_weapon(player) do
        {:ok, melee_weapon} -> melee_weapon.name
        _ -> gettext("fist")
      end

    msg = gettext("You struck with a %{melee_weapon_name}", melee_weapon_name: melee_weapon_name)
    message = Chat.Message.new(msg, :regular, moves_count)

    Chat.add_message(chat, message)
  end

  defp maybe_add_radiation_contamination_message(%Chat{} = chat, %Player{} = player_before, %Player{} = player_after) do
    if player_before.radiation < player_after.radiation do
      message = radiation_contamination_message()
      Chat.add_message(chat, message)
    else
      chat
    end
  end

  defp initial_datetime do
    shift = random_number(50)
    Timex.now() |> Timex.shift(hours: shift)
  end

  defp shift_datetime(current_datetime, shift_in_minutes) do
    Timex.shift(current_datetime, minutes: shift_in_minutes)
  end

  defp initial_supplies do
    random_number = random_number(4)

    Enum.map(1..random_number, fn _ ->
      Loot.generate_item(:supply)
    end)
  end

  defp initial_ammo do
    random_number = random_number(2)

    Enum.map(1..random_number, fn _ ->
      Loot.generate_item(:ammo)
    end)
  end

  defp initial_melee_weapon do
    if m_to_n?(1, 10) do
      Loot.generate_item(:melee_weapon)
    else
      nil
    end
  end
end
