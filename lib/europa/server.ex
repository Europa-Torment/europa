defmodule Europa.Server do
  use GenServer
  use TypedStruct
  use Gettext, backend: Europa.Gettext

  alias Europa.Games
  alias Europa.Server.Planet
  alias Europa.Server.PlanetManager
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Player
  alias Europa.Server.PlayerManager
  alias Europa.Server.Chat
  alias Europa.Server.Loot
  alias Europa.Server.Enemy
  alias Europa.Server.Action
  alias Europa.Server.Errors
  alias Europa.Tools.TextGenerator

  import Europa.Tools.Conf
  import Europa.Tools.Randomizer

  require Logger

  @type land :: list(list())

  @type move_cost :: pos_integer()

  @finish_game_on_exit fetch_config!([__MODULE__, :finish_game_on_server_exit])
  @inactivity_timeout_ms fetch_config!([__MODULE__, :inactivity_timeout_ms])

  @crop_period_ms fetch_config!([__MODULE__, :crop_land_period_ms])
  @crop_size fetch_config!([Planet, :crop_land_size])

  @max_efficiency fetch_config!([__MODULE__, :max_efficiency])

  @warm_up_quantity fetch_config!([:game_params, :player, :warm_up_quantity])

  typedstruct enforce: true do
    field :game_uuid, Ecto.UUID.t()
    field :planet, Planet.t()
    field :player, Player.t()
    field :chat, Chat.t()
    field :moves_count, non_neg_integer()
    field :great_red_spots, non_neg_integer()
    field :killed_enemies, non_neg_integer()
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

  @spec reload(pid()) :: :ok | {:error, :no_weapon} | {:error, :no_ammo} | {:error, :full_magazine}
  def reload(server) do
    GenServer.call(server, :reload)
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

  @spec consume_supply(pid(), Loot.uuid()) ::
          {:ok, Loot.Item.item()} | {:error, :not_found} | {:error, Errors.NotApplicableError.t()}
  def consume_supply(server, item_uuid) do
    GenServer.call(server, {:consume_supply, item_uuid})
  end

  ### CALLBACKS ###

  # NOTICE: Do not return updated planet or player structs if callback calls :tick
  # Game client should get updated structs by itself, otherwise client will get not actual data

  @impl true
  def init(uuid) do
    Process.flag(:trap_exit, true)

    planet = PlanetManager.new()
    player_initial_stand_on_tile = PlanetManager.player_initial_stand_on_tile(planet)

    weapon = Loot.generate_item(:weapon)
    helmet = Loot.generate_item(:helmet)
    suit = Loot.generate_item(:suit)
    boots = Loot.generate_item(:boots)

    items = [weapon, helmet, suit, boots]

    player =
      PlayerManager.new()
      |> PlayerManager.stand_on(player_initial_stand_on_tile)
      |> add_player_items(items)
      |> equip_player_items(items)

    init_message =
      :initial_story
      |> TextGenerator.generate_text(year: planet.year)
      |> Chat.Message.new(:story)

    chat = Chat.new(init_message)

    state = %__MODULE__{
      game_uuid: uuid,
      planet: planet,
      chat: chat,
      player: player,
      moves_count: 0,
      great_red_spots: 0,
      killed_enemies: 0
    }

    schedule_planet_land_crop()

    {:ok, state, @inactivity_timeout_ms}
  end

  @impl true
  def handle_call(:get_planet, _from, state) do
    {:reply, state.planet, state, @inactivity_timeout_ms}
  end

  def handle_call(:get_visible_planet, _from, state) do
    {:reply, PlanetManager.get_visible_land(state.planet), state, @inactivity_timeout_ms}
  end

  def handle_call(:get_player, _from, state) do
    {:reply, state.player, state, @inactivity_timeout_ms}
  end

  def handle_call(:get_chat, _from, state) do
    {:reply, state.chat, state, @inactivity_timeout_ms}
  end

  def handle_call({:move, direction}, {caller_pid, _}, state) do
    if PlayerManager.weight_ratio(state.player) >= 1.5 do
      message = overloaded_message()

      updated_player =
        state.player
        |> PlayerManager.change_view_direction(direction)

      {:reply, :stay, struct!(state, player: updated_player, chat: Chat.add_message(state.chat, message)),
       @inactivity_timeout_ms}
    else
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

  def handle_call(:shoot, {caller_pid, _}, state) do
    case PlanetManager.shoot(state.planet, state.player) do
      {:ok, {updated_planet, updated_player, damaged_enemies, moves_count}} ->
        moves_count = maybe_decrease_moves_count_with_efficiency(moves_count, updated_player.efficiency)
        shoot_message = shoot_message(moves_count)

        updated_chat =
          state.chat
          |> Chat.add_message(shoot_message)
          |> add_damage_messages_to_chat(damaged_enemies)

        killed_enemies_count = killed_enemies_count(damaged_enemies)

        {:reply, {:ok, :shot},
         struct!(state,
           planet: updated_planet,
           player: updated_player,
           chat: updated_chat,
           killed_enemies: state.killed_enemies + killed_enemies_count
         ), {:continue, {:tick, moves_count, caller_pid}}}

      {:error, :miss, updated_player, moves_count} ->
        moves_count = maybe_decrease_moves_count_with_efficiency(moves_count, updated_player.efficiency)
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

  def handle_call(:reload, {caller_pid, _}, state) do
    case PlayerManager.reload_weapon(state.player) do
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

  def handle_call({:get_inventory, type}, _from, state) do
    {:reply, PlayerManager.get_inventory(state.player, type), state, @inactivity_timeout_ms}
  end

  @impl true
  def handle_info(:crop_planet_land, state) do
    schedule_planet_land_crop()

    if PlanetManager.land_size(state.planet) >= @crop_size do
      {:ok, updated_planet} = PlanetManager.crop_land(state.planet)
      message = crop_planet_land_message()

      {:noreply,
       struct!(state,
         planet: updated_planet,
         chat: Chat.add_message(state.chat, message),
         great_red_spots: state.great_red_spots + 1
       ), @inactivity_timeout_ms}
    else
      {:noreply, state, @inactivity_timeout_ms}
    end
  end

  def handle_info(:game_over, state) do
    stats = %{
      moves_count: state.moves_count,
      great_red_spots: state.great_red_spots,
      killed_enemies: state.killed_enemies
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

    {:noreply,
     struct!(state,
       planet: updated_planet,
       player: updated_player,
       chat: updated_chat,
       moves_count: state.moves_count + moves_count
     ), @inactivity_timeout_ms}
  end

  @impl true
  def terminate(_, state) do
    finish_game_if_active(state.game_uuid)
    :ok
  end

  ### PRIVATE ###

  defp killed_enemies_count(damaged_enemies) do
    Enum.count(damaged_enemies, fn {enemy, _} -> enemy.health == 0 end)
  end

  defp do_move(direction, state, caller_pid) do
    case PlanetManager.move(state.planet, direction, state.player) do
      {:moved, updated_planet, moves_count, step_on_tile} ->
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
          |> PlayerManager.change_view_direction(direction)
          |> PlayerManager.stand_on(step_on_tile)

        {:reply, {:moved, status},
         struct(state,
           planet: updated_planet,
           player: updated_player,
           chat: updated_chat
         ), {:continue, {:tick, moves_count, caller_pid}}}

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
            updated_chat =
              state.chat
              |> add_damage_messages_to_chat(damaged_enemies)

            {:hitted, updated_chat}
          end

        moves_count =
          moves_count
          |> maybe_decrease_moves_count_with_efficiency(state.player.efficiency)
          |> maybe_increase_moves_count_with_inventory_weight(weight_ratio)

        killed_enemies_count = killed_enemies_count(damaged_enemies)

        updated_player =
          state.player
          |> PlayerManager.change_view_direction(direction)

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
           player: PlayerManager.change_view_direction(state.player, direction),
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
      {:ok, updated_player} = Player.add_item(player, item)
      updated_player
    end)
  end

  defp equip_player_items(%Player{} = player, items) when is_list(items) do
    Enum.reduce(items, player, fn item, player ->
      {:ok, updated_player} = Player.equip_item(player, item.uuid)
      updated_player
    end)
  end

  defp process_actions(%Player{} = player, actions, game_uuid, caller_pid) when is_list(actions) do
    Enum.reduce(actions, player, fn action, player ->
      case action do
        %Action{action_type: :attack, subject: enemy} ->
          blood_tile = blood_tile(player.stand_on)

          player
          |> PlayerManager.take_damage(enemy.damage)
          |> Player.stand_on(blood_tile)

        %Action{action_type: :warm_up, subject: :player} ->
          PlayerManager.warm_up(player, @warm_up_quantity)

        _ ->
          player
      end
    end)
    |> maybe_finish_game(game_uuid, caller_pid)
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
    Process.send_after(self(), :game_over, 500)
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

  defp moved_message(moves_count, step_on_tile) do
    tile_name = PlanetManager.readable_tile_name(step_on_tile)

    msg =
      Gettext.gettext(
        Europa.Gettext,
        "You walked at #{tile_name}, it took #{moves_count} step(s)"
      )

    Chat.Message.new(msg, :regular)
  end

  defp cant_move_message(tile) do
    tile_name = PlanetManager.readable_tile_name(tile)
    msg = Gettext.gettext(Europa.Gettext, "You can't walk through #{tile_name}")
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
    msg =
      Gettext.gettext(
        Europa.Gettext,
        "You reloaded #{weapon.name}, it took #{moves_count} step(s)"
      )

    Chat.Message.new(msg, :regular)
  end

  defp unloaded_message(%Loot.Weapon{} = weapon, moves_count) do
    msg =
      Gettext.gettext(
        Europa.Gettext,
        "You unloaded #{weapon.name}, it took #{moves_count} step(s)"
      )

    Chat.Message.new(msg, :regular)
  end

  defp shoot_message(moves_count) do
    msg =
      Gettext.gettext(
        Europa.Gettext,
        "You fired, it took #{moves_count} step(s)"
      )

    Chat.Message.new(msg, :regular)
  end

  defp consumed_supply_message(%Loot.Supply{} = supply, moves_count) do
    msg =
      Gettext.gettext(
        Europa.Gettext,
        "You consumed #{supply.name}, it took #{moves_count} step(s)"
      )

    Chat.Message.new(msg, :regular)
  end

  defp crop_planet_land_message do
    msg = TextGenerator.generate_text(:great_red_spot, [])
    Chat.Message.new(msg, :story)
  end

  defp action_message(%Action{subject: :player, action_type: :frostbite}) do
    msg = gettext("You get frostbite!")
    Chat.Message.new(msg, :danger)
  end

  defp action_message(%Action{subject: :player, action_type: :dehydration}) do
    msg = gettext("You are dying of dehydration!")
    Chat.Message.new(msg, :danger)
  end

  defp action_message(%Action{subject: :player, action_type: :hunger}) do
    msg = gettext("You are dying of hunger!")
    Chat.Message.new(msg, :danger)
  end

  defp action_message(%Action{subject: %Enemy{} = enemy, action_type: :chasing}) do
    msg = Gettext.gettext(Europa.Gettext, "#{enemy.name} is chasing you")
    Chat.Message.new(msg, :warning)
  end

  defp action_message(%Action{subject: %Enemy{} = enemy, action_type: :attack}) do
    msg = Gettext.gettext(Europa.Gettext, "#{enemy.name} is attacking you!")
    Chat.Message.new(msg, :danger)
  end

  defp action_message(%Action{subject: %Enemy{} = enemy, action_type: :miss_attack}) do
    msg = Gettext.gettext(Europa.Gettext, "#{enemy.name} attacks you but misses.")
    Chat.Message.new(msg, :warning)
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
    Enum.reduce(damaged_enemies, chat, fn {enemy, damage}, chat ->
      msg =
        if enemy.health > 0 do
          Gettext.gettext(Europa.Gettext, "You hit #{enemy.name} and dealt #{damage} damage to it!")
        else
          Gettext.gettext(Europa.Gettext, "You killed #{enemy.name}!")
        end

      message = Chat.Message.new(msg, :regular)
      Chat.add_message(chat, message)
    end)
  end

  defp schedule_planet_land_crop do
    self() |> Process.send_after(:crop_planet_land, @crop_period_ms)
  end
end
