defmodule Europa.Server.Player do
  @behaviour Europa.Server.PlayerManager

  use TypedStruct
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Characters.Character
  alias Europa.Server.Planet
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Planet.Tiles.Tile
  alias Europa.Server.Planet.Tiles.Objects.Object
  alias Europa.Server.Action
  alias Europa.Server.Loot
  alias Europa.Server.Loot.Weapon
  alias Europa.Server.Loot.Weapon.Ammo
  alias Europa.Server.Loot.Supply
  alias Europa.Server.Loot.Tool
  alias Europa.Server.Errors
  alias Europa.Server.Event
  alias Europa.Tools.NumberHelpers

  import Europa.Tools.Randomizer
  import Europa.Tools.Conf

  @type inventory :: list(Loot.Item.item())

  @max_thirst fetch_config!([:game_params, :player, :max_thirst])
  @max_hunger fetch_config!([:game_params, :player, :max_hunger])
  @max_radiation fetch_config!([:game_params, :player, :max_radiation])
  @aim_accuracy fetch_config!([:game_params, :player, :aim_accuracy])

  @warm_up_quantity fetch_config!([:game_params, :player, :warm_up_quantity])

  @warm_tiles Tiles.warm_tiles()
  @lethal_tiles Tiles.lethal_tiles()
  @changeable_tiles Tiles.changeable_tiles()

  @thin_ice Tiles.tile(:thin_ice)
  @thin_ices [@thin_ice.atom_value, @thin_ice.blood_version]

  typedstruct do
    field :character, Character.t(), enforce: true
    field :view_direction, Planet.direction(), enforce: true
    field :inventory, inventory(), enforce: true
    field :max_weight, number(), enforce: true
    field :max_health, pos_integer(), enforce: true
    field :health, non_neg_integer(), enforce: true
    field :accuracy, pos_integer(), enforce: true
    field :efficiency, pos_integer(), enforce: true
    field :max_warm, pos_integer(), enforce: true
    field :warm, pos_integer(), enforce: true
    field :hunger, non_neg_integer(), enforce: true
    field :thirst, non_neg_integer(), enforce: true
    field :radiation, non_neg_integer(), enforce: true
    field :stand_on, Planet.tile(), enforce: true
    field :weapon_uuid, Loot.uuid()
    field :melee_weapon_uuid, Loot.uuid()
    field :helmet_uuid, Loot.uuid()
    field :suit_uuid, Loot.uuid()
    field :boots_uuid, Loot.uuid()
    field :aim_mode?, boolean(), default: false
    field :events, list(Event.t()), default: []
  end

  @impl true
  def new(character) do
    max_health = max_health()
    max_warm = max_warm()

    %__MODULE__{
      character: character,
      view_direction: Planet.allowed_directions() |> Enum.random(),
      inventory: [],
      max_weight: max_weight(),
      max_health: max_health,
      health: health(max_health),
      accuracy: accuracy(),
      efficiency: efficiency(),
      max_warm: max_warm,
      warm: max_warm,
      hunger: hunger(),
      thirst: thirst(),
      radiation: 0,
      stand_on: Tiles.tile(:snow).atom_value
    }
  end

  @impl true
  def readable_stats(%__MODULE__{} = player) do
    equiped_weapon =
      case get_equiped_weapon(player) do
        {:ok, weapon} -> weapon.name
        _ -> gettext("No")
      end

    equiped_melee_weapon =
      case get_equiped_melee_weapon(player) do
        {:ok, melee_weapon} -> melee_weapon.name
        _ -> gettext("No")
      end

    equiped_helmet =
      case get_equiped_helmet(player) do
        {:ok, helmet} -> helmet.name
        _ -> gettext("No")
      end

    equiped_suit =
      case get_equiped_suit(player) do
        {:ok, suit} -> suit.name
        _ -> gettext("No")
      end

    equiped_boots =
      case get_equiped_boots(player) do
        {:ok, boots} -> boots.name
        _ -> gettext("No")
      end

    [
      {gettext("Name"), player.character.name},
      {gettext("Age"), player.character.current_age},
      {gettext("Gender"), Character.readable_gender(player.character)},
      {gettext("Health"), "#{player.health}/#{player.max_health}"},
      {gettext("Weapon"), equiped_weapon},
      {gettext("Melee weapon"), equiped_melee_weapon},
      {gettext("Helmet"), equiped_helmet},
      {gettext("Suit"), equiped_suit},
      {gettext("Boots"), equiped_boots}
    ]
  end

  @impl true
  def change_view_direction(%__MODULE__{} = player, new_direction) do
    if new_direction in Planet.allowed_directions() do
      struct!(player, view_direction: new_direction)
    else
      player
    end
  end

  @impl true
  def stand_on(%__MODULE__{} = player, tile) do
    player
    |> struct!(stand_on: tile)
    |> maybe_change_tile()
    |> maybe_dead_if_tile_is_lethal()
  end

  @impl true
  def stand_on_lethal_tile?(%__MODULE__{} = player) do
    do_stand_on_lethal_tile?(player.stand_on)
  end

  @impl true
  def add_events(player, []), do: player

  def add_events(%__MODULE__{} = player, events) when is_list(events) do
    events =
      Enum.uniq_by(player.events ++ events, fn event ->
        case event.type do
          type when is_atom(type) -> type
          _ -> event.uuid
        end
      end)
      |> Event.stack_events()

    struct!(player, events: events)
  end

  @impl true
  def remove_last_event(%__MODULE__{events: []} = player), do: player

  def remove_last_event(%__MODULE__{events: [_ | rest_events]} = player) do
    struct!(player, events: rest_events)
  end

  @impl true
  def warm_up(%__MODULE__{} = player, warm_units) when is_integer(warm_units) and warm_units > 0 do
    increase_attrs(player, %{warm: warm_units})
  end

  @impl true
  def increase_thirst(%__MODULE__{} = player, thirst_units) when is_integer(thirst_units) do
    increase_attrs(player, %{thirst: thirst_units})
  end

  @impl true
  def toggle_aim_mode(%__MODULE__{weapon_uuid: nil, aim_mode?: false}) do
    {:error, :no_weapon}
  end

  def toggle_aim_mode(%__MODULE__{} = player) do
    accuracy =
      if player.aim_mode? do
        player.accuracy - @aim_accuracy
      else
        player.accuracy + @aim_accuracy
      end

    {:ok, struct!(player, aim_mode?: !player.aim_mode?, accuracy: accuracy)}
  end

  @impl true
  def add_item(%__MODULE__{} = player, item) do
    if Loot.Item.stackable?(item) && already_have_such_item?(player.inventory, item) do
      stack_items(player, item)
    else
      do_add_item(player, item)
    end
  end

  @impl true
  def get_item(%__MODULE__{inventory: inventory}, item_uuid) do
    case Enum.find(inventory, fn item -> item.uuid == item_uuid end) do
      nil -> {:error, :not_found}
      item -> {:ok, item}
    end
  end

  @impl true
  def drop_item(%__MODULE__{} = player, item_uuid, count \\ nil) do
    with {:ok, item} <- get_item(player, item_uuid) do
      {player, item} = maybe_unequip_item(player, item)

      {updated_player, dropped_item} =
        if Loot.Item.stackable?(item) && is_integer(count) && item.count > count do
          drop_stackable_item(player, item, count)
        else
          drop_regular_item(player, item)
        end

      {:ok, updated_player, dropped_item}
    end
  end

  @impl true
  def disassemble_item(%__MODULE__{} = player, item_uuid) do
    with {:ok, item} <- get_item(player, item_uuid) do
      {player, item} = maybe_unequip_item(player, item)
      do_disassemble_item(player, item)
    end
  end

  @impl true
  def equip_item(%__MODULE__{} = player, item_uuid) do
    with {:ok, item} <- get_item(player, item_uuid),
         {:ok, updated_item} <- Loot.Item.equip(item) do
      do_equip_or_unequip_item(player, updated_item)
    end
  end

  @impl true
  def unequip_item(%__MODULE__{} = player, item_uuid) do
    with {:ok, item} <- get_item(player, item_uuid),
         {:ok, updated_item} <- Loot.Item.unequip(item) do
      do_equip_or_unequip_item(player, updated_item)
    end
  end

  @impl true
  def update_item(%__MODULE__{inventory: inventory} = player, updated_item) do
    updated_inventory =
      Enum.map(inventory, fn item ->
        if item.uuid == updated_item.uuid do
          updated_item
        else
          item
        end
      end)

    struct!(player, inventory: updated_inventory)
  end

  @impl true
  def delete_item(%__MODULE__{inventory: inventory} = player, item_to_delete) do
    updated_inventory = Enum.reject(inventory, fn item -> item.uuid == item_to_delete.uuid end)
    struct!(player, inventory: updated_inventory)
  end

  @impl true
  def tools_amount(%__MODULE__{} = player, %Loot.Tool{} = tool) do
    inventory_tool = find_tool(player, tool)

    if inventory_tool do
      inventory_tool.count
    else
      0
    end
  end

  @impl true
  def enough_tools?(%__MODULE__{} = player, tools) when is_list(tools) do
    Enum.all?(tools, fn tool -> tools_amount(player, tool) >= tool.count end)
  end

  @impl true
  def craft_item(%__MODULE__{} = player, %Loot.Blueprint{} = blueprint) do
    with {:ok, player} <- use_tools(player, blueprint.tools) do
      add_item(player, blueprint.item)
    end
  end

  @impl true
  def use_tools(%__MODULE__{} = player, tools) when is_list(tools) do
    if enough_tools?(player, tools) do
      {:ok, do_use_tools(player, tools)}
    else
      {:error, %Errors.NotApplicableError{}}
    end
  end

  @impl true
  def get_equiped_weapon(%__MODULE__{weapon_uuid: nil}) do
    {:error, :no_weapon}
  end

  def get_equiped_weapon(%__MODULE__{weapon_uuid: weapon_uuid} = player) do
    with {:error, :not_found} <- get_item(player, weapon_uuid) do
      {:error, :no_weapon}
    end
  end

  @impl true
  def get_equiped_melee_weapon(%__MODULE__{melee_weapon_uuid: nil}) do
    {:error, :no_melee_weapon}
  end

  def get_equiped_melee_weapon(%__MODULE__{melee_weapon_uuid: melee_weapon_uuid} = player) do
    with {:error, :not_found} <- get_item(player, melee_weapon_uuid) do
      {:error, :no_melee_weapon}
    end
  end

  @impl true
  def get_equiped_helmet(%__MODULE__{helmet_uuid: nil}) do
    {:error, :no_helmet}
  end

  def get_equiped_helmet(%__MODULE__{helmet_uuid: helmet_uuid} = player) do
    with {:error, :not_found} <- get_item(player, helmet_uuid) do
      {:error, :no_helmet}
    end
  end

  @impl true
  def get_equiped_suit(%__MODULE__{suit_uuid: nil}) do
    {:error, :no_suit}
  end

  def get_equiped_suit(%__MODULE__{suit_uuid: suit_uuid} = player) do
    with {:error, :not_found} <- get_item(player, suit_uuid) do
      {:error, :no_suit}
    end
  end

  @impl true
  def get_equiped_boots(%__MODULE__{boots_uuid: nil}) do
    {:error, :no_boots}
  end

  def get_equiped_boots(%__MODULE__{boots_uuid: boots_uuid} = player) do
    with {:error, :not_found} <- get_item(player, boots_uuid) do
      {:error, :no_boots}
    end
  end

  @impl true
  def find_weapon_ammo(%__MODULE__{} = player, %Loot.Weapon{} = weapon) do
    ammo =
      Enum.find(player.inventory, fn
        %Weapon.Ammo{caliber: caliber} when caliber == weapon.caliber -> true
        _ -> false
      end)

    case ammo do
      %Weapon.Ammo{} = ammo ->
        {:ok, ammo}

      _ ->
        {:error, :no_ammo}
    end
  end

  @impl true
  def take_damage(%__MODULE__{} = player, damage) when is_integer(damage) and damage > 0 do
    updated_health = max(0, player.health - damage)

    player
    |> struct!(health: updated_health)
    |> add_events([Event.new({:damaged, damage})])
    |> check_if_dead()
  end

  @impl true
  def increase_radiation(%__MODULE__{} = player, radiation) when is_integer(radiation) do
    updated_radiation = min(player.radiation + radiation, @max_radiation) |> max(0)

    player
    |> struct!(radiation: updated_radiation)
    |> maybe_add_radiation_event(radiation)
  end

  @impl true
  def reload_weapon(%__MODULE__{} = player) do
    with {:ok, weapon} <- get_equiped_weapon(player),
         :ok <- Weapon.check_reload_needed(weapon),
         {:ok, ammo} <- find_weapon_ammo(player, weapon) do
      do_reload_weapon(player, weapon, ammo)
    end
  end

  @impl true
  def reload_weapon(%__MODULE__{} = player, weapon_uuid) do
    with {:ok, weapon} <- get_item(player, weapon_uuid),
         :ok <- Weapon.check_reload_needed(weapon),
         {:ok, ammo} <- find_weapon_ammo(player, weapon) do
      do_reload_weapon(player, weapon, ammo)
    end
  end

  @impl true
  def unload_weapon(%__MODULE__{} = player, weapon_uuid) do
    with {:ok, %Weapon{} = weapon} <- get_item(player, weapon_uuid),
         {:ok, {updated_weapon, ammo}} <- Weapon.unload(weapon),
         {:ok, updated_player} <- player |> update_item(updated_weapon) |> add_item(ammo) do
      {:ok, updated_player, updated_weapon}
    end
  end

  @impl true
  def consume_supply(%__MODULE__{} = player, supply_uuid) do
    with {:ok, supply} <- get_item(player, supply_uuid) do
      do_consume_supply(player, supply)
    end
  end

  @impl true
  def get_inventory(%__MODULE__{inventory: inventory}, :all), do: inventory

  def get_inventory(%__MODULE__{inventory: inventory}, items_type) do
    Enum.filter(inventory, fn item -> Loot.Item.item_type(item) == items_type end)
  end

  @impl true
  def inventory_weight(%__MODULE__{inventory: inventory}) do
    Enum.reduce(inventory, 0, fn i, weight ->
      weight + Loot.Item.weight(i)
    end)
    |> NumberHelpers.round(2)
  end

  @impl true
  def weight_ratio(%__MODULE__{} = player) do
    inventory_weight(player) / player.max_weight
  end

  @impl true
  def tick(%__MODULE__{} = player, moves_count) when moves_count > 0 do
    do_tick(player, moves_count)
  end

  def tick(player, _), do: {:ok, player, []}

  ### PRIVATE ###

  defp do_stand_on_lethal_tile?(%{stand_on: stand_on} = tile) when is_struct(tile) do
    do_stand_on_lethal_tile?(stand_on)
  end

  defp do_stand_on_lethal_tile?(tile) when tile in @lethal_tiles do
    true
  end

  defp do_stand_on_lethal_tile?(_), do: false

  defp maybe_change_tile(%__MODULE__{stand_on: tile} = player) do
    new_tile = do_maybe_change_tile(player, tile)
    struct!(player, stand_on: new_tile)
  end

  defp do_maybe_change_tile(player, %{stand_on: stand_on} = tile) when is_struct(tile) do
    struct!(tile, stand_on: do_maybe_change_tile(player, stand_on))
  end

  defp do_maybe_change_tile(player, tile_atom_value) when tile_atom_value in @changeable_tiles do
    regular_tile = Tiles.tile_by_atom_value(tile_atom_value)
    blood_tile = Tiles.tile_by_blood_version(tile_atom_value)

    {tile, changes_to} =
      if blood_tile do
        {blood_tile, Tiles.tile(blood_tile.changes_to).blood_version}
      else
        {regular_tile, Tiles.tile(regular_tile.changes_to).atom_value}
      end

    change_possibility = tile_change_possibility(tile, player)

    if tile.changes_to && change_possibility && m_to_n?(1, change_possibility) do
      changes_to
    else
      tile_atom_value
    end
  end

  defp do_maybe_change_tile(_player, tile), do: tile

  defp tile_change_possibility(%Tile{atom_value: tile_value} = tile, player) when tile_value in @thin_ices do
    inventory_loaded_percent = inventory_loaded_percent(player)

    if inventory_loaded_percent >= 100 do
      tile.change_possibility
    else
      100 - inventory_loaded_percent
    end
  end

  defp tile_change_possibility(tile, _player), do: tile.change_possibility

  defp inventory_loaded_percent(player) do
    percent = inventory_weight(player) / player.max_weight * 100
    round(percent)
  end

  defp maybe_dead_if_tile_is_lethal(%__MODULE__{stand_on: stand_on} = player) do
    maybe_dead_if_tile_is_lethal(player, stand_on)
  end

  defp maybe_dead_if_tile_is_lethal(%__MODULE__{} = player, %{stand_on: stand_on} = tile) when is_struct(tile) do
    maybe_dead_if_tile_is_lethal(player, stand_on)
  end

  defp maybe_dead_if_tile_is_lethal(%__MODULE__{} = player, tile) when tile in @lethal_tiles do
    tile = Tiles.tile_by_atom_value(tile) || Tiles.tile_by_blood_version(tile)

    # add custom dead event
    player
    |> take_damage(player.max_health)
    |> replace_events_with_new_event(Event.new({:dead, tile.lethal_event}))
  end

  defp maybe_dead_if_tile_is_lethal(player, _tile), do: player

  defp check_if_dead(%__MODULE__{health: 0, aim_mode?: true} = player) do
    {:ok, player} = toggle_aim_mode(player)
    check_if_dead(player)
  end

  defp check_if_dead(%__MODULE__{health: 0, events: events} = player) do
    has_dead_event? =
      Enum.find(events, fn
        {:dead, _} -> true
        _ -> false
      end)

    if has_dead_event? do
      player
    else
      replace_events_with_new_event(player, Event.new({:dead, :regular}))
    end
  end

  defp check_if_dead(%__MODULE__{} = player), do: player

  defp replace_events_with_new_event(%__MODULE__{} = player, %Event{} = event) do
    struct!(player, events: [event])
  end

  defp do_use_tools(%__MODULE__{} = player, tools) when is_list(tools) do
    Enum.reduce(tools, player, fn tool, player ->
      updated_tool =
        player
        |> find_tool(tool)
        |> Loot.Tool.decrease_count(tool.count)

      if updated_tool.count > 0 do
        update_item(player, updated_tool)
      else
        delete_item(player, updated_tool)
      end
    end)
  end

  defp add_items(%__MODULE__{} = player, items) when is_list(items) do
    Enum.reduce(items, player, fn item, player ->
      {:ok, updated_player} = add_item(player, item)
      updated_player
    end)
  end

  defp do_disassemble_item(%__MODULE__{} = player, item) do
    with {:ok, new_items} <- Loot.Item.disassemble(item) do
      updated_player =
        player
        |> delete_item(item)
        |> add_items(new_items)

      {:ok, updated_player, item}
    end
  end

  defp maybe_unequip_item(%__MODULE__{} = player, item) do
    if Loot.Item.equipable?(item) && item.equiped do
      {:ok, updated_player} = unequip_item(player, item.uuid)
      {updated_player, struct!(item, equiped: false)}
    else
      {player, item}
    end
  end

  defp drop_regular_item(player, item) do
    updated_player =
      player
      |> delete_item(item)
      |> do_drop_item(item)

    {updated_player, item}
  end

  defp drop_stackable_item(player, item, count) do
    dropped_item = struct!(item, uuid: Ecto.UUID.generate(), count: count)
    updated_item = struct!(item, count: item.count - count)

    updated_player =
      player
      |> update_item(updated_item)
      |> do_drop_item(dropped_item)

    {updated_player, dropped_item}
  end

  defp do_drop_item(%__MODULE__{stand_on: %Object{movable?: true} = object} = player, item) do
    item_box =
      Loot.new_item_box(:bag, [item])
      |> Loot.ItemBox.stand_on(object)

    stand_on(player, item_box)
  end

  defp do_drop_item(%__MODULE__{stand_on: %Loot.ItemBox{} = item_box} = player, item) do
    updated_item_box = Loot.ItemBox.add_item(item_box, item)
    stand_on(player, updated_item_box)
  end

  defp do_drop_item(%__MODULE__{stand_on: stand_on} = player, item) do
    stand_on_tile = Tiles.tile_by_blood_version(stand_on) || Tiles.tile_by_atom_value(stand_on)
    stand_on = stand_on_tile.atom_value

    item_box =
      Loot.new_item_box(:bag, [item])
      |> Loot.ItemBox.stand_on(stand_on)

    stand_on(player, item_box)
  end

  defp do_tick(player, moves_count) do
    do_tick(player, moves_count, [])
  end

  defp do_tick(player, 0, actions) do
    {:ok, player, actions}
  end

  defp do_tick(player, moves_count, actions) do
    ticks = [
      fn player -> get_cold(player) end,
      fn player -> get_thirsty(player) end,
      fn player -> get_hungry(player) end,
      fn player -> maybe_warm_up(player) end,
      fn player -> maybe_increase_or_decrease_radiation(player) end,
      fn player -> take_radiation_damage(player) end
    ]

    {updated_player, actions} =
      Enum.reduce(ticks, {player, actions}, fn tick_fn, {player, actions} ->
        {updated_player, new_actions} = tick_fn.(player)
        {updated_player, actions ++ new_actions}
      end)

    do_tick(updated_player, moves_count - 1, actions)
  end

  defp get_cold(%__MODULE__{stand_on: stand_on} = player) when stand_on in @warm_tiles do
    {player, []}
  end

  defp get_cold(%__MODULE__{warm: 0} = player) do
    if m_to_n?(1, 10) do
      {take_damage(player, 1), [Action.new(:player, :frostbite)]}
    else
      {player, []}
    end
  end

  defp get_cold(%__MODULE__{max_warm: max_warm, warm: warm} = player) do
    is_get_colder =
      cond do
        warm == max_warm ->
          !m_to_n?(90, 100)

        !m_to_n?(warm, max_warm) ->
          !m_to_n?(3, 5)

        true ->
          false
      end

    if is_get_colder do
      {struct!(player, warm: max(player.warm - 1, 0)), [Action.new(:player, :get_cold)]}
    else
      {player, []}
    end
  end

  defp get_thirsty(%__MODULE__{thirst: thirst} = player) when thirst >= @max_thirst do
    if m_to_n?(3, 10) do
      {take_damage(player, 2), [Action.new(:player, :dehydration)]}
    else
      {player, []}
    end
  end

  defp get_thirsty(%__MODULE__{thirst: thirst} = player) do
    if m_to_n?(900, 1000) do
      {player, []}
    else
      {struct!(player, thirst: thirst + 1), []}
    end
  end

  defp get_hungry(%__MODULE__{hunger: hunger} = player) when hunger >= @max_hunger do
    if m_to_n?(3, 10) do
      {take_damage(player, 1), [Action.new(:player, :hunger)]}
    else
      {player, []}
    end
  end

  defp get_hungry(%__MODULE__{hunger: hunger} = player) do
    if m_to_n?(900, 1000) do
      {player, []}
    else
      {struct!(player, hunger: hunger + 1), []}
    end
  end

  defp maybe_warm_up(%__MODULE__{stand_on: stand_on} = player) when stand_on in @warm_tiles do
    {warm_up(player, @warm_up_quantity), []}
  end

  defp maybe_warm_up(player) do
    {player, []}
  end

  defp maybe_increase_or_decrease_radiation(player) do
    radiation_factors = [
      {player.helmet_uuid, _penalty = 1},
      {player.suit_uuid, _penalty = 3},
      {player.boots_uuid, _penalty = 1}
    ]

    radiation =
      Enum.reduce(radiation_factors, 0, fn
        {nil, penalty}, acc -> acc + penalty
        _, acc -> acc
      end)

    cond do
      radiation > 0 ->
        {increase_radiation(player, radiation), [Action.new(:player, :radiation_contamination)]}

      radiation == 0 && player.radiation > 0 && m_to_n?(1, 5) ->
        {increase_radiation(player, -1), []}

      true ->
        {player, []}
    end
  end

  defp take_radiation_damage(player) do
    if player.radiation > 0 && m_to_n?(player.radiation, @max_radiation) do
      {take_damage(player, 4), [Action.new(:player, :radiation_damage)]}
    else
      {player, []}
    end
  end

  defp do_consume_supply(%__MODULE__{} = player, %Supply{} = supply) do
    stats_changes = Loot.Item.player_stats_changes(supply)

    updated_supply = Supply.decrease_count(supply)

    updated_player =
      if updated_supply.count > 0 do
        player
        |> increase_attrs(stats_changes)
        |> update_item(updated_supply)
      else
        player
        |> increase_attrs(stats_changes)
        |> delete_item(supply)
      end

    {:ok, updated_player, updated_supply}
  end

  defp do_consume_supply(_player, _supply), do: {:error, %Errors.NotApplicableError{}}

  defp find_tool(%__MODULE__{} = player, %Loot.Tool{} = tool) do
    Enum.find(player.inventory, fn
      %Loot.Tool{} = item -> tool.type == item.type && tool.name == item.name && tool.properties == item.properties
      _ -> false
    end)
  end

  defp do_add_item(player, item) do
    {:ok, struct!(player, inventory: [item | player.inventory])}
  end

  defp do_reload_weapon(player, weapon, ammo) do
    with {:ok, rounds_needed} <- Weapon.rounds_to_full_magazine(weapon) do
      ammo_count = ammo.count

      if ammo_count > rounds_needed do
        updated_weapon = Weapon.add_rounds(weapon, rounds_needed)
        updated_ammo = Ammo.decrease_count(ammo, rounds_needed)

        updated_player =
          player
          |> update_item(updated_weapon)
          |> update_item(updated_ammo)

        {:ok, updated_player, updated_weapon}
      else
        rounds_count = min(ammo_count, rounds_needed)
        updated_weapon = Weapon.add_rounds(weapon, rounds_count)

        updated_player =
          player
          |> update_item(updated_weapon)
          |> delete_item(ammo)

        {:ok, updated_player, updated_weapon}
      end
    end
  end

  defp already_have_such_item?(inventory, item) do
    inventory
    |> Enum.filter(fn i ->
      item_type = Loot.Item.item_type(i)
      Loot.Item.stackable?(i) && item_type == Loot.Item.item_type(item)
    end)
    |> Enum.any?(fn inventory_item ->
      case Loot.Item.item_type(inventory_item) do
        :ammo -> inventory_item.caliber == item.caliber
        :supply -> inventory_item.name == item.name && inventory_item.properties == item.properties
        :tool -> inventory_item.name == item.name && inventory_item.properties == item.properties
      end
    end)
  end

  defp stack_items(%__MODULE__{} = player, item) do
    updated_inventory =
      Enum.map(player.inventory, fn
        %Weapon.Ammo{caliber: caliber} = inventory_ammo when caliber == item.caliber ->
          struct!(inventory_ammo, count: inventory_ammo.count + item.count)

        %Supply{name: name} = inventory_supply when name == item.name ->
          struct!(inventory_supply, count: inventory_supply.count + item.count)

        %Tool{name: name} = inventory_tool when name == item.name ->
          struct!(inventory_tool, count: inventory_tool.count + item.count)

        item ->
          item
      end)

    {:ok, struct!(player, inventory: updated_inventory)}
  end

  defp do_equip_or_unequip_item(player, updated_item) do
    current_item_attrs = get_current_item_attrs(player, updated_item)

    stats_changes =
      if updated_item.equiped do
        Loot.Item.player_stats_changes(updated_item)
      else
        %{}
      end

    updated_inventory =
      Enum.map(player.inventory, fn item ->
        cond do
          item.uuid == updated_item.uuid ->
            updated_item

          Loot.Item.item_type(item) == Loot.Item.item_type(updated_item) && item.equiped ->
            {:ok, item} = Loot.Item.unequip(item)
            item

          true ->
            item
        end
      end)

    changed_params =
      case updated_item do
        %Loot.Weapon{equiped: true} -> [weapon_uuid: updated_item.uuid]
        %Loot.MeleeWeapon{equiped: true} -> [melee_weapon_uuid: updated_item.uuid]
        %Loot.Helmet{equiped: true} -> [helmet_uuid: updated_item.uuid]
        %Loot.Suit{equiped: true} -> [suit_uuid: updated_item.uuid]
        %Loot.Boots{equiped: true} -> [boots_uuid: updated_item.uuid]
        %Loot.Weapon{equiped: false} -> [weapon_uuid: nil]
        %Loot.MeleeWeapon{equiped: false} -> [melee_weapon_uuid: nil]
        %Loot.Helmet{equiped: false} -> [helmet_uuid: nil]
        %Loot.Suit{equiped: false} -> [suit_uuid: nil]
        %Loot.Boots{equiped: false} -> [boots_uuid: nil]
      end

    updated_player =
      player
      |> struct!([inventory: updated_inventory] ++ changed_params)
      |> update_player_attrs(current_item_attrs, stats_changes)
      |> maybe_turn_off_aim_mode()

    {:ok, updated_player}
  end

  defp maybe_turn_off_aim_mode(%__MODULE__{weapon_uuid: nil, aim_mode?: true} = player) do
    {:ok, player} = toggle_aim_mode(player)
    player
  end

  defp maybe_turn_off_aim_mode(player), do: player

  defp update_player_attrs(player, old_item_attrs, new_item_attrs) do
    player
    |> decrease_attrs(old_item_attrs)
    |> increase_attrs(new_item_attrs)
  end

  defp decrease_attrs(player, attrs) do
    Enum.reduce(attrs, player, fn {attr_name, attr_value}, player ->
      case attr_name do
        :max_weight ->
          struct!(player, max_weight: player.max_weight - attr_value)

        :accuracy ->
          struct!(player, accuracy: player.accuracy - attr_value)

        :efficiency ->
          struct!(player, efficiency: player.efficiency - attr_value)

        :max_health ->
          max_health = player.max_health - attr_value
          struct!(player, max_health: max_health, health: min(player.health, max_health))

        :max_warm ->
          max_warm = player.max_warm - attr_value
          struct!(player, max_warm: max_warm, warm: min(player.warm, max_warm))

        _ ->
          player
      end
    end)
  end

  defp increase_attrs(player, attrs) do
    Enum.reduce(attrs, player, fn {attr_name, attr_value}, player ->
      case attr_name do
        :max_weight ->
          struct!(player, max_weight: player.max_weight + attr_value)

        :accuracy ->
          struct!(player, accuracy: player.accuracy + attr_value)

        :efficiency ->
          struct!(player, efficiency: player.efficiency + attr_value)

        :max_health ->
          struct!(player, max_health: player.max_health + attr_value)

        :health ->
          player
          |> struct!(health: min(player.max_health, player.health + attr_value) |> max(0))
          |> add_health_changed_event(attr_value)
          |> check_if_dead()

        :max_warm ->
          struct!(player, max_warm: player.max_warm + attr_value)

        :warm ->
          struct!(player, warm: min(player.max_warm, player.warm + attr_value) |> max(0))

        :hunger ->
          struct!(player, hunger: max(0, player.hunger + attr_value) |> min(@max_hunger))

        :thirst ->
          struct!(player, thirst: max(0, player.thirst + attr_value) |> min(@max_thirst))

        :radiation ->
          increase_radiation(player, attr_value)

        _ ->
          player
      end
    end)
  end

  defp get_current_item_attrs(player, new_item) do
    uuid =
      case new_item do
        %Loot.Weapon{} -> player.weapon_uuid
        %Loot.MeleeWeapon{} -> player.melee_weapon_uuid
        %Loot.Helmet{} -> player.helmet_uuid
        %Loot.Suit{} -> player.suit_uuid
        %Loot.Boots{} -> player.boots_uuid
      end

    case get_item(player, uuid) do
      {:ok, current_item} -> Loot.Item.player_stats_changes(current_item)
      _ -> %{}
    end
  end

  defp add_health_changed_event(player, health_value) do
    event =
      if health_value < 0 do
        Event.new({:damaged, abs(health_value)})
      else
        Event.new({:healed, health_value})
      end

    add_events(player, [event])
  end

  defp maybe_add_radiation_event(player, radiation_value) when radiation_value > 0 do
    event = Event.new({:radiation, radiation_value})
    add_events(player, [event])
  end

  defp maybe_add_radiation_event(player, _), do: player

  defp max_weight do
    from = fetch_config!([:game_params, :player, :max_weight, :from])
    to = fetch_config!([:game_params, :player, :max_weight, :to])

    m_to_n(from, to) + 0.0
  end

  defp max_health do
    from = fetch_config!([:game_params, :player, :max_health, :from])
    to = fetch_config!([:game_params, :player, :max_health, :to])

    m_to_n(from, to)
  end

  defp health(max_health) do
    half_of_health = div(max_health, 2)
    m_to_n(half_of_health, max_health)
  end

  defp accuracy do
    from = fetch_config!([:game_params, :player, :accuracy, :from])
    to = fetch_config!([:game_params, :player, :accuracy, :to])

    m_to_n(from, to)
  end

  defp efficiency do
    from = fetch_config!([:game_params, :player, :efficiency, :from])
    to = fetch_config!([:game_params, :player, :efficiency, :to])

    m_to_n(from, to)
  end

  defp max_warm do
    from = fetch_config!([:game_params, :player, :max_warm, :from])
    to = fetch_config!([:game_params, :player, :max_warm, :to])

    m_to_n(from, to)
  end

  defp hunger do
    from = fetch_config!([:game_params, :player, :hunger, :from])
    to = fetch_config!([:game_params, :player, :hunger, :to])

    m_to_n(from, to)
  end

  defp thirst do
    from = fetch_config!([:game_params, :player, :thirst, :from])
    to = fetch_config!([:game_params, :player, :thirst, :to])

    m_to_n(from, to)
  end
end
