defmodule Europa.Server.Planet do
  # TODO: get rid of changing the player structure inside this module, move it to server module
  @behaviour Europa.Server.PlanetManager

  use TypedStruct
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Planet.Tiles.Tile
  alias Europa.Server.Planet.Tiles.Objects
  alias Europa.Server.Planet.Tiles.Objects.Object
  alias Europa.Server.Planet.Templates
  alias Europa.Server.Planet.Region
  alias Europa.Server.Planet.Storm
  alias Europa.Server.Planet.Squad

  alias Europa.Server.Player
  alias Europa.Server.PlayerManager
  alias Europa.Server.Loot
  alias Europa.Server.Loot.Tool
  alias Europa.Server.Loot.Weapon
  alias Europa.Server.Enemy
  alias Europa.Server.Action
  alias Europa.Server.Event
  alias Europa.Server.Characters
  alias Europa.Server.Characters.Character
  alias Europa.Server.Npc

  alias Europa.Server.Errors.NotApplicableError

  alias Europa.Tools.Types
  alias Europa.Tools.PerlinNoise

  import Europa.Tools.Randomizer
  import Europa.Tools.Conf

  @view_distance fetch_config!([__MODULE__, :view_distance])

  @initial_game_field_width @view_distance * 2
  @initial_game_field_height @view_distance * 2

  @view_distance fetch_config!([__MODULE__, :view_distance])
  @min_view_distance fetch_config!([__MODULE__, :min_view_distance])

  @base_enemy_generate_possibility fetch_config!([__MODULE__, :base_enemy_generate_possibility])
  @enemy_view_distance fetch_config!([__MODULE__, :enemy_view_distance])

  @enemy_move_possibility_from fetch_config!([__MODULE__, :enemy_move_possibility, :from])
  @enemy_move_possibility_to fetch_config!([__MODULE__, :enemy_move_possibility, :to])

  @npc_move_possibility_from fetch_config!([__MODULE__, :npc_move_possibility, :from])
  @npc_move_possibility_to fetch_config!([__MODULE__, :npc_move_possibility, :to])

  @max_accuracy fetch_config!([:weapons, :max_accuracy])

  @base_loot_generate_possibility fetch_config!([__MODULE__, :base_loot_generate_possibility])

  @npc_generate_possibility fetch_config!([__MODULE__, :npc_generate_possibility])

  @predefined_cluster_distance fetch_config!([__MODULE__, :predefined_cluster_distance])
  @predefined_cluster_update_distance fetch_config!([__MODULE__, :predefined_cluster_update_distance])
  @default_predefined_possibility fetch_config!([__MODULE__, :default_predefined_possibility])
  @predefined_cluster_possibility fetch_config!([__MODULE__, :predefined_cluster_possibility])

  @storm_possibility fetch_config!([__MODULE__, :storm_possibility])

  @disaster_year fetch_config!([:game_params, :disaster_year])

  @player :player

  @type player() :: :player

  @type coord :: {x :: integer(), y :: integer()}

  @directions [:up, :down, :right, :left]
  @type direction :: unquote(Types.one_of(@directions))

  @type readable_tile_name :: String.t()

  @type storm_tile() :: {:storm, direction()}

  @type tile :: unquote(Types.one_of(Tiles.tiles_values())) | player() | Loot.ItemBox.t() | Object.t() | storm_tile()

  @type land :: list(list({coord(), tile()}))
  @type planet_map :: list(list(tile()))

  @type interaction ::
          {:confirmation, Object.transform_confirmation_info()}
          | {:confirmation, :danger_action}
          | {:confirmation, {:pick_transform, list(Object.Transform.t())}}
          | {:talk, Npc.t()}
          | {:drink, :radioactive_water}
          | {:transform, Object.t()}
          | {:transform, Object.t(), Object.Transform.t()}

  @type coord_info :: {tile(), direction(), distance :: non_neg_integer()}

  @ice Tiles.tile(:ice).atom_value
  @ice_spikes Tiles.tile(:ice_spikes).atom_value
  @thin_ice Tiles.tile(:thin_ice).atom_value

  @water Tiles.tile(:water).atom_value
  @radioactive_water Tiles.tile(:radioactive_water).atom_value
  @warm_water Tiles.tile(:warm_water).atom_value

  @snow Tiles.tile(:snow).atom_value

  @concrete Tiles.tile(:concrete).atom_value
  @concrete_snow Tiles.tile(:concrete_snow).atom_value

  @asphalt Tiles.tile(:asphalt).atom_value
  @ruins Tiles.tile(:ruins).atom_value

  @darkness Tiles.tile(:darkness).atom_value

  @movable_tiles Tiles.movable_tiles()
  @swimable_tiles Tiles.swimable_tiles()
  @enemy_movable_tiles @movable_tiles ++ @swimable_tiles

  @warm_tiles Tiles.warm_tiles()
  @high_tiles Tiles.high_tiles()
  @radioactive_tiles Tiles.radioactive_tiles()
  @high_loot_possibility_tiles Tiles.high_loot_possibility_tiles()

  @lethal_tiles Tiles.lethal_tiles()
  @potential_lethal_tiles Tiles.potential_lethal_tiles()
  @not_spawnable_tiles @lethal_tiles ++ @potential_lethal_tiles

  @water_tiles [@water, @radioactive_water, @warm_water, @ice_spikes]

  @move_costs Tiles.move_costs()

  @tiles_readable_names Tiles.readable_names()

  @open_left_door Tiles.tile(:open_left_door)
  @open_right_door Tiles.tile(:open_right_door)
  @open_up_door Tiles.tile(:open_up_door)
  @open_down_door Tiles.tile(:open_down_door)

  @transforms %{
    @open_left_door.atom_value => {Objects.object(:door_left), :open},
    @open_right_door.atom_value => {Objects.object(:door_right), :open},
    @open_up_door.atom_value => {Objects.object(:door_up), :open},
    @open_down_door.atom_value => {Objects.object(:door_down), :open},
    @open_left_door.blood_version => {Objects.object(:door_left), :open},
    @open_right_door.blood_version => {Objects.object(:door_right), :open},
    @open_up_door.blood_version => {Objects.object(:door_up), :open},
    @open_down_door.blood_version => {Objects.object(:door_down), :open}
  }

  # Follow the ordering by noise_threshold to not get unexpected tiles stacking
  # If there is water in region then next one should be without water
  @regions [
    %Region{water_tile: @water, ice_tile: @ice, snow_tile: @snow, noise_threshold: -0.21},
    %Region{water_tile: @thin_ice, ice_tile: @ice, snow_tile: @snow, noise_threshold: -0.165},
    %Region{water_tile: @warm_water, ice_tile: @ice, snow_tile: @snow, noise_threshold: -0.138},
    %Region{
      city?: true,
      water_tile: @ruins,
      ice_tile: @concrete,
      snow_tile: @concrete_snow,
      road_tile: @asphalt,
      enemy_generate_possibility: div(@base_enemy_generate_possibility, 20),
      predefined_possibility: 1,
      predefined_subcategories: ["city", "shops"],
      noise_threshold: 0.012
    },
    %Region{water_tile: @ice, ice_tile: @ice, snow_tile: @ice_spikes, noise_threshold: 0.11},
    %Region{water_tile: @radioactive_water, ice_tile: @ice, snow_tile: @thin_ice, noise_threshold: 0.369},
    %Region{water_tile: @ice, ice_tile: @ice, snow_tile: @snow, noise_threshold: 0.60},
    %Region{
      city?: true,
      water_tile: @ruins,
      ice_tile: @concrete,
      snow_tile: @concrete_snow,
      road_tile: @asphalt,
      enemy_generate_possibility: div(@base_enemy_generate_possibility, 30),
      predefined_possibility: 1,
      predefined_subcategories: ["science_city", "city"],
      noise_threshold: 0.70
    },
    %Region{water_tile: @ice, ice_tile: @ice, snow_tile: @snow, noise_threshold: 1.0}
  ]

  @city_block_size 11
  @city_road_width 3
  @city_cell_size @city_block_size + @city_road_width

  typedstruct module: Land, enforce: true do
    field :tiles, map(), default: %{}
    field :noise_coef, number()
    field :region_noise_coef, number()
    field :region_x_offset, number()
    field :region_y_offset, number()
  end

  typedstruct do
    field :land, Land.t(), enforce: true
    field :current_coord, coord(), enforce: true
    field :predefined_cluster_coord, coord(), enforce: true
    field :year, pos_integer(), enforce: true
    field :moves_count, non_neg_integer(), enforce: true
    field :great_red_spots, non_neg_integer(), enforce: true
    field :characters_pid, pid(), enforce: true
    field :player_fraction, Characters.Character.fraction(), enforce: true
    field :storm, Storm.t()
    field :squad, Squad.t(), enforce: true
  end

  ### PUBLIC INTERFACE ###

  @impl true
  def new(options) do
    year = Keyword.fetch!(options, :year)
    characters_pid = Keyword.fetch!(options, :characters_pid)
    player_fraction = Keyword.fetch!(options, :player_fraction)

    {x, y} = initial_coord = initial_coord()

    planet =
      %__MODULE__{
        land: generate_land(),
        current_coord: initial_coord,
        predefined_cluster_coord: initial_coord(),
        year: year,
        moves_count: 0,
        great_red_spots: 0,
        characters_pid: characters_pid,
        player_fraction: player_fraction,
        squad: Squad.new()
      }

    # Re-generate planet if player spawned on non movable tile or in non spawnable region
    initial_tile = player_initial_stand_on_tile(planet)

    if not region_by_perlin_noise(x, y, planet.land).not_spawnable? && initial_tile in @movable_tiles &&
         initial_tile not in @not_spawnable_tiles do
      planet
    else
      new(options)
    end
  end

  @impl true
  def player_initial_stand_on_tile(%__MODULE__{} = planet) do
    {x, y} = initial_coord()
    tile_by_perlin_noise(x, y, planet.land)
  end

  @impl true
  def view_distance, do: @view_distance

  @impl true
  def player, do: @player

  @impl true
  def allowed_directions, do: @directions

  @impl true
  def readable_tile_name(%Loot.ItemBox{} = item_box), do: Loot.ItemBox.readable_name(item_box)
  def readable_tile_name(%Enemy{name: name}), do: Gettext.gettext(Europa.Gettext, name)
  def readable_tile_name(%Object{name: "", stand_on: stand_on}), do: readable_tile_name(stand_on)
  def readable_tile_name(%Object{name: name}), do: name
  def readable_tile_name(%Npc{}), do: gettext("person")
  def readable_tile_name(tile), do: Map.get(@tiles_readable_names, tile)

  @impl true
  def get_visible_land(
        %__MODULE__{land: land, current_coord: current_coord} = planet,
        %Player{} = player,
        %DateTime{} = current_datetime
      ) do
    current_hour = current_datetime.hour
    {{x_from, x_to}, {y_from, y_to}} = visible_land_intervals(planet.current_coord)
    flashlight_coords = flashlight_coords(land, current_coord, player)

    for y <- y_from..y_to do
      for x <- x_from..x_to do
        tile =
          get_tile(land, {x, y})
          |> tile_or_storm(current_coord, {x, y}, planet.storm)
          |> tile_or_darkness(current_coord, {x, y}, current_hour, land, flashlight_coords)

        {{x, y}, tile}
      end
    end
  end

  @impl true
  def get_map(%__MODULE__{land: land} = planet, opts \\ []) do
    x_offset = Keyword.get(opts, :x_offset, 0)
    y_offset = Keyword.get(opts, :y_offset, 0)

    {{x_from, x_to}, {y_from, y_to}} = map_land_intervals(planet, 60, x_offset, y_offset)

    map_tile = fn x, y ->
      tile = get_tile(land, {x, y})

      if tile do
        tile_for_map(tile)
      else
        @darkness
      end
    end

    for y <- y_from..y_to do
      for x <- x_from..x_to do
        map_tile.(x, y)
      end
    end
  end

  @impl true
  def coord_info(%__MODULE__{} = planet, {_x, _y} = coord) do
    tile = get_tile(planet.land, coord)
    direction = coords_position(planet.current_coord, coord)
    distance = coords_distance(planet.current_coord, coord)

    {tile, direction, distance}
  end

  @impl true
  def get_storm(%__MODULE__{storm: nil}), do: {:error, :not_storm}
  def get_storm(%__MODULE__{storm: storm}), do: {:ok, storm}

  @impl true
  def land_size(%__MODULE__{land: land}) do
    Enum.count(land.tiles)
  end

  @impl true
  def crop_land(%__MODULE__{land: land} = planet) do
    {{x_from, x_to}, {y_from, y_to}} = visible_land_intervals(planet.current_coord)

    new_tiles =
      for x <- x_from..x_to do
        for y <- y_from..y_to do
          get_tile(land, {x, y})
        end
      end
      |> Enum.with_index(fn row, x ->
        Enum.with_index(row, fn tile, y ->
          {{x, y}, tile_to_landscape(tile)}
        end)
      end)
      |> List.flatten()
      |> Enum.into(%{})

    updated_land = struct!(land, tiles: new_tiles)
    current_coord = {div(@view_distance, 2), div(@view_distance, 2)}

    updated_planet =
      struct!(planet, land: updated_land, current_coord: current_coord, great_red_spots: planet.great_red_spots + 1)

    {:ok, updated_planet}
  end

  @impl true
  def move(%__MODULE__{} = planet, direction, %Player{} = player) do
    target_coord = target_coord(planet, direction)
    do_move(planet, target_coord, direction, player)
  end

  @impl true
  def loot(%__MODULE__{}, %Player{stand_on: %Loot.ItemBox{} = item_box}) do
    {:open_item_box, item_box}
  end

  def loot(%__MODULE__{} = planet, %Player{view_direction: view_direction}) when view_direction in @directions do
    target_coord = target_coord(planet, view_direction)
    target_tile = get_tile(planet.land, target_coord)

    case target_tile do
      %Loot.ItemBox{} = ib ->
        {:open_item_box, ib}

      _ ->
        {:error, :nothing}
    end
  end

  @impl true
  def take_loot(%__MODULE__{} = planet, %Player{} = player, item_uuid) do
    with {:open_item_box, item_box} <- loot(planet, player),
         {:ok, item, updated_item_box} <- Loot.ItemBox.take_item(item_box, item_uuid),
         {:ok, updated_player} <- PlayerManager.add_item(player, item) do
      do_take_loot(planet, updated_item_box, updated_player)
    end
  end

  @impl true
  def use_tool(%__MODULE__{land: land} = planet, %Tool{using_type: {:put_object, object_name}}, direction)
      when direction in @directions do
    target_coord = target_coord(planet, direction)
    target_tile = get_tile(land, target_coord)

    if movable_tile?(land, target_coord) && target_tile in Tiles.tiles_values() do
      object = Objects.object(object_name) |> Object.stand_on(target_tile)
      updated_land = change_tile(land, target_coord, object)
      {:ok, struct!(planet, land: updated_land)}
    else
      {:error, %NotApplicableError{}}
    end
  end

  def use_tool(_, _, _), do: {:error, %NotApplicableError{}}

  @impl true
  def shoot(%__MODULE__{} = planet, %Player{} = player) do
    with {:ok, weapon} <- PlayerManager.get_equipped_weapon(player) do
      do_shoot(planet, player, weapon)
    end
  end

  @impl true
  def unload_item_box_weapon(%__MODULE__{} = planet, %Player{} = player, item_uuid) do
    with {:open_item_box, item_box} <- loot(planet, player),
         {:ok, updated_item_box, updated_weapon} <- Loot.ItemBox.unload_weapon(item_box, item_uuid) do
      do_unload_item_box_weapon(planet, player, updated_item_box, updated_weapon)
    end
  end

  @impl true
  def interact(%__MODULE__{land: land} = planet, direction, opts \\ []) when direction in @directions do
    target_coord = target_coord(planet, direction)
    target_tile = get_tile(land, target_coord)

    do_interact(target_tile, planet, direction, opts)
  end

  @impl true
  def recruit_squad_member(%__MODULE__{} = planet, direction) when direction in @directions do
    target_coord = target_coord(planet, direction)

    case get_tile(planet.land, target_coord) do
      %Npc{} = npc -> do_recruit_squad_member(planet, npc, target_coord)
      _ -> {:error, %NotApplicableError{}}
    end
  end

  @impl true
  def fire_squad_member(%__MODULE__{} = planet, npc_uuid) do
    case Squad.remove_member(planet.squad, npc_uuid, :fired) do
      {:ok, updated_squad} -> {:ok, struct!(planet, squad: updated_squad)}
      _ -> {:error, %NotApplicableError{}}
    end
  end

  @impl true
  def set_squad_loot_types(%__MODULE__{} = planet, loot_types) when is_list(loot_types) do
    {:ok, updated_squad} = Squad.set_loot_types(planet.squad, loot_types)
    {:ok, struct!(planet, squad: updated_squad)}
  end

  @impl true
  def set_squad_attack_mode(%__MODULE__{} = planet, attack_mode) when is_atom(attack_mode) do
    {:ok, updated_squad} = Squad.set_attack_mode(planet.squad, attack_mode)
    {:ok, struct!(planet, squad: updated_squad)}
  end

  @impl true
  def add_squad_loot(%__MODULE__{} = planet, item) do
    {:ok, updated_squad} = Squad.take_items(planet.squad, [item])
    {:ok, struct!(planet, squad: updated_squad)}
  end

  @impl true
  def tick(%__MODULE__{} = planet, moves_count) when moves_count > 0 do
    planet
    |> maybe_set_new_predefined_cluster_coord()
    |> maybe_start_storm()
    |> increment_moves_count(moves_count)
    |> do_tick(moves_count, [])
  end

  def tick(%__MODULE__{} = planet, _) do
    {:ok, planet, []}
  end

  @impl true
  def remove_last_events(%__MODULE__{} = planet) do
    coords = get_coords_of_structs_with_events_list(planet)

    not_visible_squad_members_coords = Squad.member_coords(planet.squad) -- coords

    # skip events from not visible squad members
    changed_squad_tiles =
      Enum.reduce(not_visible_squad_members_coords, %{}, fn coord, tiles ->
        case get_tile(planet.land, coord) do
          %Npc{events: [_h | _t]} = npc ->
            updated_npc = struct!(npc, events: [])
            Map.put(tiles, coord, updated_npc)

          _ ->
            tiles
        end
      end)

    {changed_tiles, events} =
      Enum.reduce(coords, {%{}, []}, fn coord, {tiles, events} ->
        %{uuid: uuid, events: [event | rest_events]} = tile = get_tile(planet.land, coord)
        updated_tile = struct!(tile, events: rest_events)
        {Map.put(tiles, coord, updated_tile), [{uuid, event} | events]}
      end)

    new_tiles = Map.merge(changed_squad_tiles, changed_tiles)

    if Enum.empty?(new_tiles) do
      {:ok, planet, []}
    else
      updated_land = struct!(planet.land, tiles: Map.merge(planet.land.tiles, new_tiles))
      {:ok, struct!(planet, land: updated_land), events}
    end
  end

  @impl true
  def remove_last_squad_event(%__MODULE__{} = planet) do
    case Squad.remove_last_event(planet.squad) do
      {:ok, updated_squad, event} -> {:ok, struct!(planet, squad: updated_squad), event}
      _ -> {:ok, planet, nil}
    end
  end

  @spec prepare_predefined_tile(tile() | {:npc, tile() | nil}, coord(), t(), tile() | nil) :: tile()
  def prepare_predefined_tile(_, _, _, forced_stand_on \\ nil)

  def prepare_predefined_tile(%Enemy{stand_on: nil} = enemy, coord, planet, forced_stand_on) do
    stand_on = forced_stand_on || predefined_stand_on_tile(planet.land, coord)
    Enemy.stand_on(enemy, stand_on)
  end

  def prepare_predefined_tile(%Loot.ItemBox{stand_on: nil} = item_box, coord, planet, forced_stand_on) do
    stand_on = forced_stand_on || predefined_stand_on_tile(planet.land, coord)
    Loot.ItemBox.stand_on(item_box, stand_on)
  end

  def prepare_predefined_tile(%Object{stand_on: nil} = object, coord, planet, forced_stand_on) do
    stand_on = forced_stand_on || predefined_stand_on_tile(planet.land, coord)
    Object.stand_on(object, stand_on)
  end

  def prepare_predefined_tile({:npc, stand_on}, coord, planet, forced_stand_on) do
    stand_on = stand_on || forced_stand_on || predefined_stand_on_tile(planet.land, coord)

    case Characters.pick(planet.characters_pid, planet.year - @disaster_year) do
      {:ok, character} ->
        Npc.new(character, stand_on)

      _ ->
        stand_on
    end
  end

  def prepare_predefined_tile(tile, _, _, _), do: tile

  ### PRIVATE ###

  defp do_recruit_squad_member(%__MODULE__{} = planet, %Npc{} = npc, {_x, _y} = coord) do
    case Squad.recruit_member(planet.squad, npc, coord) do
      {:ok, squad} -> {:ok, struct!(planet, squad: squad)}
      error -> error
    end
  end

  defp tile_to_landscape(%{stand_on: tile}), do: tile_to_landscape(tile)
  defp tile_to_landscape(tile), do: tile

  defp next_to_interactive_tile?(%__MODULE__{} = planet) do
    Enum.any?(@directions, fn direction ->
      # Just checking for the possibility of interaction without planet updation.
      case interact(planet, direction, check: true) do
        {:error, :nothing} -> false
        _ -> true
      end
    end)
  end

  defp do_interact(%Npc{target: nil, character: %Character{}} = npc, planet, _view_direction, _opts) do
    {:ok, planet, {:talk, npc}}
  end

  defp do_interact(@water, planet, _view_direction, opts) do
    if forced_interaction?(opts) do
      {:ok, planet, {:drink, :radioactive_water}}
    else
      {:ok, planet, {:confirmation, :danger_action}}
    end
  end

  defp do_interact(%Object{transforms: transforms} = object, planet, view_direction, opts) when is_list(transforms) do
    transform_name = Keyword.get(opts, :transform_name)
    transforms_count = Enum.count(transforms)

    cond do
      transforms_count == 0 ->
        {:error, :nothing}

      transforms_count == 1 ->
        transform_name = List.first(transforms).name
        opts = Keyword.put(opts, :transform_name, transform_name)
        do_interact_with_object(object, planet, view_direction, opts)

      transform_name ->
        do_interact_with_object(object, planet, view_direction, opts)

      true ->
        {:ok, planet, {:confirmation, {:pick_transform, transforms}}}
    end
  end

  defp do_interact(tile, planet, view_direction, opts) do
    transform_opts = Map.get(@transforms, tile)

    if transform_opts do
      {object, transform_name} = transform_opts
      transform = Object.fetch_transform!(object, transform_name)

      if just_check_interact?(opts) do
        {:ok, planet, {:transform, object, transform}}
      else
        target_coord = target_coord(planet, view_direction)
        stand_on_tile = predefined_stand_on_tile(planet.land, target_coord)
        object = Object.stand_on(object, stand_on_tile)

        updated_land =
          planet.land
          |> change_tile(target_coord, object)

        {:ok, struct!(planet, land: updated_land), {:transform, object, transform}}
      end
    else
      {:error, :nothing}
    end
  end

  defp do_interact_with_object(%Object{} = object, planet, view_direction, opts) do
    transform_name = Keyword.fetch!(opts, :transform_name)
    transform = Object.fetch_transform!(object, transform_name)

    if (transform.transform_requirements && forced_interaction?(opts)) || is_nil(transform.transform_requirements) do
      target_coord = target_coord(planet, view_direction)

      transformed_tile =
        Object.transform(object, transform_name)
        |> prepare_predefined_tile(target_coord, planet)

      updated_land =
        planet.land
        |> change_tile(target_coord, transformed_tile)

      {:ok, struct!(planet, land: updated_land), {:transform, object, transform}}
    else
      {:ok, planet, {:confirmation, Object.transform_confirmation(object, transform_name)}}
    end
  end

  defp forced_interaction?(opts) do
    Keyword.get(opts, :forced, false)
  end

  defp just_check_interact?(opts) do
    Keyword.get(opts, :check, false)
  end

  defp do_tick(%__MODULE__{} = planet, 0, actions) do
    {:ok, planet, actions}
  end

  defp do_tick(%__MODULE__{} = planet, moves_count, actions) do
    ticks = [
      fn planet -> maybe_tick_storm(planet) end,
      fn planet -> maybe_perform_npc_actions(planet) end,
      fn planet -> maybe_perform_enemies_actions(planet) end,
      fn planet -> maybe_add_temperature_action(planet) end,
      fn planet -> maybe_add_radiation(planet) end,
      fn planet -> tick_squad(planet) end,
      fn planet -> heal_squad_npcs(planet) end
    ]

    {updated_planet, actions} =
      Enum.reduce(ticks, {planet, actions}, fn tick_fn, {planet, actions} ->
        {updated_planet, new_actions} = tick_fn.(planet)
        {updated_planet, actions ++ new_actions}
      end)

    do_tick(updated_planet, moves_count - 1, actions)
  end

  defp do_shoot(_, _, %Loot.Weapon{rounds_loaded: 0}) do
    {:error, :empty_magazine}
  end

  defp do_shoot(%__MODULE__{} = planet, %Player{} = player, %Loot.Weapon{} = weapon) do
    case find_targets(planet, planet.current_coord, player.view_direction, weapon) do
      [] ->
        updated_weapon = Loot.Weapon.decrease_rounds_loaded(weapon)
        updated_player = PlayerManager.update_item(player, updated_weapon)
        {:error, :miss, updated_player, weapon.shot_cost}

      enemies_coords ->
        shoot_enemies(planet, player, weapon, enemies_coords)
    end
  end

  defp do_unload_item_box_weapon(
         %__MODULE__{} = planet,
         %Player{stand_on: %Loot.ItemBox{}} = player,
         updated_item_box,
         updated_weapon
       ) do
    updated_player = PlayerManager.stand_on(player, updated_item_box)
    {:ok, planet, updated_player, updated_item_box, updated_weapon}
  end

  defp do_unload_item_box_weapon(%__MODULE__{} = planet, %Player{} = player, updated_item_box, updated_weapon) do
    target_coord =
      target_coord(planet, player.view_direction)

    updated_land =
      planet.land
      |> change_tile(target_coord, updated_item_box)

    {:ok, struct!(planet, land: updated_land), player, updated_item_box, updated_weapon}
  end

  defp find_targets(planet, coord, view_direction, weapon, subject \\ :player)

  defp find_targets(planet, coord, view_direction, %Loot.Weapon{shooting_type: st} = weapon, subject)
       when st in [:bullet, :burst] do
    shooting_distance = weapon.shooting_distance
    find_direct_targets(planet, coord, view_direction, shooting_distance, subject)
  end

  defp find_targets(planet, coord, view_direction, %Loot.Weapon{shooting_type: :shot} = weapon, subject) do
    shooting_distance = weapon.shooting_distance
    find_shotgun_targets(planet, coord, view_direction, shooting_distance, subject)
  end

  defp find_direct_targets(
         %__MODULE__{land: land} = planet,
         {x, y},
         view_direction,
         shooting_distance,
         subject
       ) do
    coord_fun =
      case view_direction do
        :right -> fn n -> {x + n, y} end
        :left -> fn n -> {x - n, y} end
        :up -> fn n -> {x, y - n} end
        :down -> fn n -> {x, y + n} end
      end

    target_coord =
      1..shooting_distance
      |> Enum.map(fn n -> coord_fun.(n) end)
      |> stop_on_barrier(land)
      |> Enum.find(fn coord ->
        case get_tile(land, coord) do
          %Enemy{stand_on: tile} when tile not in @swimable_tiles -> true
          %Npc{} = npc -> can_attack_npc?(planet.squad, npc, subject)
          :player -> true
          _ -> false
        end
      end)

    case target_coord do
      nil -> []
      coord -> [coord]
    end
  end

  defp find_shotgun_targets(
         %__MODULE__{land: land} = planet,
         coord,
         view_direction,
         shooting_distance,
         subject
       ) do
    coord
    |> shotgun_targets(shooting_distance, land, view_direction)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.filter(fn coord ->
      case get_tile(land, coord) do
        %Enemy{stand_on: tile} when tile not in @swimable_tiles -> true
        %Npc{} = npc -> can_attack_npc?(planet.squad, npc, subject)
        :player -> true
        _ -> false
      end
    end)
  end

  defp shotgun_targets({x, y}, shooting_distance, land, direction) do
    coord_fun =
      case direction do
        :up -> fn m, n -> {x + m, y - n} end
        :down -> fn m, n -> {x + m, y + n} end
        :left -> fn m, n -> {x - n, y + m} end
        :right -> fn m, n -> {x + n, y + m} end
      end

    Enum.map(-shooting_distance..shooting_distance, fn m_end ->
      Enum.map(1..shooting_distance, fn n ->
        m = round(m_end * n / shooting_distance)
        coord_fun.(m, n)
      end)
      |> stop_on_barrier(land)
    end)
  end

  defp stop_on_barrier(coords, land) do
    closest_barrier_index =
      Enum.find_index(coords, fn coord ->
        case get_tile(land, coord) do
          nil -> false
          :player -> true
          %Enemy{stand_on: tile} when tile not in @swimable_tiles -> true
          %Npc{} -> true
          %Object{high?: true} -> true
          tile -> tile in @high_tiles
        end
      end)

    if closest_barrier_index do
      Enum.take(coords, closest_barrier_index + 1)
    else
      coords
    end
  end

  defp can_attack_npc?(%Squad{} = squad, %Npc{} = npc, :player) do
    not Squad.member?(squad, npc)
  end

  defp can_attack_npc?(%Squad{} = squad, %Npc{} = npc, %Npc{} = subject) do
    subject.target == npc.uuid || (Squad.member?(squad, subject) && Squad.can_attack?(squad, npc))
  end

  defp shoot_enemies(%__MODULE__{} = planet, %Player{} = player, %Loot.Weapon{} = weapon, enemies_coords)
       when is_list(enemies_coords) do
    damage = PlayerManager.weapon_damage(player)

    {updated_planet, shooted_enemies} =
      Enum.reduce(enemies_coords, {planet, []}, fn coord, {planet, shooted_enemies} = acc ->
        distance_to_target = coords_distance(planet.current_coord, coord)

        accuracy =
          if distance_to_target == 1 do
            player.accuracy + 2
          else
            max(player.accuracy - distance_to_target, 1)
          end

        if accuracy >= @max_accuracy || m_to_n?(accuracy, @max_accuracy) do
          {enemy, updated_land} = shoot_enemy(planet.land, coord, damage)
          {struct!(planet, land: updated_land), [{enemy, damage} | shooted_enemies]}
        else
          acc
        end
      end)

    updated_weapon = Loot.Weapon.decrease_rounds_loaded(weapon)
    updated_player = PlayerManager.update_item(player, updated_weapon)

    shot_cost = weapon.shot_cost

    if Enum.empty?(shooted_enemies) do
      {:error, :miss, updated_player, shot_cost}
    else
      {:ok, {updated_planet, updated_player, shooted_enemies, shot_cost}}
    end
  end

  defp shoot_enemy(land, coord, damage) do
    enemy = get_tile(land, coord)
    damage_enemy(land, coord, enemy, damage)
  end

  defp damage_enemy(land, coord, %Enemy{} = enemy, damage) do
    updated_enemy =
      enemy
      |> Enemy.take_damage(damage)
      |> Enemy.stand_on(blood_tile(enemy.stand_on))

    if updated_enemy.health > 0 do
      {updated_enemy, change_tile(land, coord, updated_enemy)}
    else
      {updated_enemy, generate_monster_body(land, coord, updated_enemy)}
    end
  end

  defp damage_enemy(land, coord, %Npc{} = npc, damage) do
    updated_npc =
      npc
      |> Npc.take_damage(damage)
      |> Npc.stand_on(blood_tile(npc.stand_on))
      |> trigger_npc(:player)

    if updated_npc.health > 0 do
      {updated_npc, change_tile(land, coord, updated_npc)}
    else
      {updated_npc, generate_human_body(land, coord, updated_npc)}
    end
  end

  defp maybe_delete_empty_item_box(%Loot.ItemBox{type: :bag, items: [], stand_on: stand_on}), do: stand_on
  defp maybe_delete_empty_item_box(item_box), do: item_box

  defp generate_monster_body(land, coord, %Enemy{morphs_to: {:around, enemy_id}}) do
    neighbor_coords = neighbor_coords(coord, 1) |> Enum.filter(&movable_tile?(land, &1))

    new_tiles =
      [coord | neighbor_coords]
      |> Enum.map(fn coord ->
        tile = tile_by_perlin_noise(coord, land)
        enemy = Enemy.generate_enemy(enemy_id) |> Enemy.stand_on(tile)
        {coord, enemy}
      end)
      |> Enum.into(%{})

    struct!(land, tiles: Map.merge(land.tiles, new_tiles))
  end

  defp generate_monster_body(land, coord, %Enemy{morphs_to: {:single, enemy_id}, stand_on: stand_on}) do
    new_enemy = Enemy.generate_enemy(enemy_id) |> Enemy.stand_on(stand_on)
    change_tile(land, coord, new_enemy)
  end

  defp generate_monster_body(land, coord, %Enemy{stand_on: %Loot.ItemBox{items: items, stand_on: stand_on}} = enemy) do
    monster_body =
      enemy
      |> Enemy.stand_on(stand_on)
      |> Loot.generate_item_box_from_enemy()

    monster_body = struct!(monster_body, items: items ++ monster_body.items)
    change_tile(land, coord, monster_body)
  end

  defp generate_monster_body(land, _coord, %Enemy{stand_on: tile}) when tile in @swimable_tiles do
    land
  end

  defp generate_monster_body(land, coord, %Enemy{} = enemy) do
    monster_body = Loot.generate_item_box_from_enemy(enemy)
    change_tile(land, coord, monster_body)
  end

  defp generate_human_body(land, coord, %Npc{stand_on: %Loot.ItemBox{items: items, stand_on: stand_on}} = npc) do
    human_body =
      npc
      |> Npc.stand_on(stand_on)
      |> Loot.generate_item_box_from_npc()

    human_body = struct!(human_body, items: items ++ human_body.items)
    change_tile(land, coord, human_body)
  end

  defp generate_human_body(land, coord, %Npc{} = npc) do
    human_body = Loot.generate_item_box_from_npc(npc)
    change_tile(land, coord, human_body)
  end

  # this is for "skip" object, see Objects module
  defp blood_tile(%Object{name: "", image_name: "", stand_on: tile} = object) do
    blood_tile = blood_tile(tile)
    Object.stand_on(object, blood_tile)
  end

  defp blood_tile(tile) do
    case Tiles.tile_by_atom_value(tile) do
      %Tile{blood_version: blood_tile} when not is_nil(blood_tile) -> blood_tile
      _ -> tile
    end
  end

  defp tile_for_map(%{map_color: color} = tile) when not is_nil(color) do
    tile
  end

  defp tile_for_map(%Npc{} = npc), do: npc
  defp tile_for_map(%Enemy{} = enemy), do: enemy

  defp tile_for_map(tile) do
    tile_to_landscape(tile)
  end

  defp maybe_set_new_predefined_cluster_coord(%__MODULE__{} = planet) do
    if coords_distance(planet.current_coord, planet.predefined_cluster_coord) >= @predefined_cluster_update_distance do
      struct!(planet, predefined_cluster_coord: planet.current_coord)
    else
      planet
    end
  end

  defp maybe_start_storm(%__MODULE__{storm: nil} = planet) do
    if m_to_n?(1, @storm_possibility) do
      storm = Storm.new()
      struct!(planet, storm: storm)
    else
      planet
    end
  end

  defp maybe_start_storm(%__MODULE__{} = planet) do
    planet
  end

  defp increment_moves_count(%__MODULE__{} = planet, moves_count) when is_integer(moves_count) do
    struct!(planet, moves_count: planet.moves_count + moves_count)
  end

  defp maybe_add_temperature_action(%__MODULE__{} = planet) do
    case get_neighbor_objects_temperature(planet) do
      nil -> {planet, []}
      temperature -> {planet, [Action.new(:player, {:temperature, temperature})]}
    end
  end

  defp maybe_add_radiation(%__MODULE__{} = planet) do
    if next_to_radioactive_tile?(planet) && m_to_n?(1, 4) do
      {planet, [Action.new(:player, :radiation_contamination)]}
    else
      {planet, []}
    end
  end

  defp tick_squad(%__MODULE__{} = planet) do
    {:ok, updated_squad, actions} = Squad.tick(planet.squad)
    {struct!(planet, squad: updated_squad), actions}
  end

  defp heal_squad_npcs(%__MODULE__{} = planet) do
    updated_planet =
      planet.squad
      |> Squad.member_coords()
      |> Enum.reduce(planet, fn coord, planet ->
        case get_tile(planet.land, coord) do
          %Npc{health: health, max_health: max_health} = npc when health < max_health ->
            maybe_heal_squad_npc(planet, npc, coord)

          _ ->
            planet
        end
      end)

    {updated_planet, []}
  end

  defp maybe_heal_squad_npc(%__MODULE__{} = planet, %Npc{} = npc, {_x, _y} = npc_coord) do
    if m_to_n?(1, 3) do
      case Squad.use_supply(planet.squad) do
        {:ok, updated_squad, health} ->
          updated_npc = Npc.heal(npc, health)
          updated_land = change_tile(planet.land, npc_coord, updated_npc)
          {:ok, updated_squad} = Squad.update_member(updated_squad, updated_npc, npc_coord)
          struct!(planet, land: updated_land, squad: updated_squad)

        _ ->
          planet
      end
    else
      planet
    end
  end

  defp get_neighbor_objects_temperature(%__MODULE__{land: land, current_coord: current_coord}) do
    temperatures =
      land
      |> get_neighbors(current_coord, 1)
      |> Enum.filter(fn tile ->
        case tile do
          %Object{temperature: temperature} when is_integer(temperature) ->
            true

          tile when tile in @warm_tiles and tile not in @movable_tiles ->
            tile

          _ ->
            false
        end
      end)
      |> Enum.map(fn
        %Object{temperature: temperature} ->
          temperature

        tile ->
          tile = Tiles.tile_by_atom_value(tile) || Tiles.tile_by_blood_version(tile)
          tile.temperature
      end)

    case Enum.count(temperatures) do
      0 -> nil
      1 -> List.first(temperatures)
      count -> temperatures |> Enum.sum() |> div(count)
    end
  end

  defp next_to_radioactive_tile?(%__MODULE__{land: land, current_coord: current_coord}) do
    land
    |> get_neighbors(current_coord, 1)
    |> Enum.any?(fn
      %Object{radioactive?: true} -> true
      tile -> tile in @radioactive_tiles and tile not in @movable_tiles
    end)
  end

  defp maybe_perform_enemies_actions(%__MODULE__{} = planet) do
    enemies_actions = [
      fn enemies_coords, planet -> trigger_enemies(enemies_coords, planet) end,
      fn enemies_coords, planet -> move_enemies(enemies_coords, planet) end,
      fn enemies_coords, planet -> heal_enemies(enemies_coords, planet) end
    ]

    Enum.reduce(enemies_actions, {planet, []}, fn action_fn, {planet, actions} ->
      enemies_coords = get_coords_of_visible_enemies(planet)

      {updated_planet, new_actions} = action_fn.(enemies_coords, planet)
      {updated_planet, actions ++ new_actions}
    end)
  end

  defp trigger_npcs([], planet), do: {planet, []}

  defp trigger_npcs(npc_coords, %__MODULE__{} = planet) do
    enemy_coords = get_coords_of_visible_enemies(planet)

    Enum.reduce(npc_coords, {planet, []}, fn npc_coord, {pl, act} ->
      npc = get_tile(pl.land, npc_coord)
      {updated_pl, actions} = trigger_npc(pl, npc_coord, npc, enemy_coords, npc_coords -- [npc_coord])
      {updated_pl, act ++ actions}
    end)
  end

  defp trigger_npc(%__MODULE__{} = planet, npc_coord, %Npc{target: nil} = npc, enemy_coords, other_npc_coords) do
    squad_member? = Squad.member?(planet.squad, npc)
    enemy_npc_coords = enemy_npc_coords(planet, npc, other_npc_coords, squad_member?)

    {new_target_coord, new_target} =
      closest_target(planet, npc_coord, enemy_coords ++ enemy_npc_coords, npc, without_player: true)

    player_enemy? =
      (planet.player_fraction in npc.character.enemy_fractions && npc.character.not_playable?) || npc.player_enemy?

    new_target =
      cond do
        new_target && player_enemy? &&
            first_coord_closed?(planet.current_coord, new_target_coord, npc_coord) ->
          :player

        is_nil(new_target) && player_enemy? ->
          :player

        squad_member? && planet.squad.resources.ammo == 0 ->
          get_closest_loot_coord_for_squad(planet, npc, npc_coord)

        new_target && squad_member? && !npc?(new_target) && Squad.can_attack?(planet.squad, new_target) ->
          new_target

        new_target ->
          new_target

        squad_member? ->
          get_closest_loot_coord_for_squad(planet, npc, npc_coord)

        true ->
          nil
      end

    updated_npc = trigger_npc(npc, new_target)
    updated_land = change_tile(planet.land, npc_coord, updated_npc)

    updated_squad =
      cond do
        squad_member? && coord?(new_target) ->
          {:ok, updated_squad} = Squad.update_member(planet.squad, npc, npc_coord)
          Squad.assign_coord(updated_squad, new_target)

        squad_member? ->
          {:ok, updated_squad} = Squad.update_member(planet.squad, npc, npc_coord)
          updated_squad

        true ->
          planet.squad
      end

    {struct!(planet, land: updated_land, squad: updated_squad), []}
  end

  defp trigger_npc(%__MODULE__{} = planet, _, _, _, _), do: {planet, []}

  defp enemy_npc_coords(%__MODULE__{} = planet, %Npc{} = npc, other_npc_coords, squad_member?) do
    other_npc_coords
    |> Enum.filter(fn coord ->
      case get_tile(planet.land, coord) do
        %Npc{} = other_npc ->
          enemies? = Characters.enemies?(npc.character, other_npc.character)

          (squad_member? && Squad.can_attack?(planet.squad, other_npc)) || enemies? ||
            (squad_member? && other_npc.target == :player)

        _ ->
          false
      end
    end)
  end

  defp get_closest_loot_coord_for_squad(%__MODULE__{squad: %Squad{loot_types: []}}, _, _) do
    nil
  end

  defp get_closest_loot_coord_for_squad(%__MODULE__{} = planet, %Npc{} = npc, {_x, _y} = npc_coord) do
    coords =
      planet
      |> get_coords_of_visible_loot()
      |> Enum.filter(
        &(&1 not in planet.squad.assigned_coords && calculate_move_coord(planet, &1, npc_coord, npc) != :stay)
      )
      |> Enum.sort_by(&coords_distance(npc_coord, &1))

    if Enum.empty?(coords) do
      nil
    else
      List.first(coords)
    end
  end

  defp move_npcs([], planet), do: {planet, []}

  defp move_npcs(npc_coords, %__MODULE__{} = planet) do
    Enum.reduce(npc_coords, {planet, []}, fn npc_coord, {pl, act} ->
      case get_tile(pl.land, npc_coord) do
        %Npc{} = npc ->
          {updated_pl, actions} = move_npc(pl, npc_coord, npc)
          {updated_pl, act ++ actions}

        _ ->
          {pl, act}
      end
    end)
  end

  defp move_npc(%__MODULE__{} = planet, npc_coord, %Npc{target: nil} = npc) do
    if Squad.member?(planet.squad, npc) do
      do_move_npc(planet, npc_coord, npc, planet.current_coord)
    else
      updated_npc = Npc.maybe_add_speech_event(npc)
      updated_land = change_tile(planet.land, npc_coord, updated_npc)

      {struct!(planet, land: updated_land), []}
    end
  end

  defp move_npc(%__MODULE__{} = planet, npc_coord, %Npc{weapon: %Weapon{shooting_distance: shooting_distance}} = npc) do
    case get_target_coord(planet, npc) do
      nil ->
        {skip_npc_trigger(planet, npc_coord, npc), []}

      target_coord ->
        target = get_tile(planet.land, target_coord)
        new_view_direction = coords_position(npc_coord, target_coord)
        npc = Npc.change_view_direction(npc, new_view_direction)

        cond do
          !m_to_n?(@npc_move_possibility_from, @npc_move_possibility_to) ->
            {planet, []}

          Squad.member?(planet.squad, npc) && !visible_coord?(planet.current_coord, target_coord) ->
            {skip_npc_trigger(planet, npc_coord, npc), []}

          loot?(target) && coords_on_same_line?(npc_coord, target_coord) &&
              coords_distance(npc_coord, target_coord) in 0..1 ->
            take_squad_resources(planet, npc, npc_coord, target, target_coord)

          target && coords_on_same_line?(npc_coord, target_coord) &&
            coords_distance(npc_coord, target_coord) in 1..shooting_distance &&
              target_coord in find_targets(planet, npc_coord, npc.view_direction, npc.weapon, npc) ->
            npc_attack(planet, npc_coord, npc, target_coord)

          target ->
            do_move_npc(planet, npc_coord, npc, target_coord)

          true ->
            {skip_npc_trigger(planet, npc_coord, npc), []}
        end
    end
  end

  defp take_squad_resources(
         %__MODULE__{} = planet,
         %Npc{} = npc,
         {_nx, _ny} = npc_coord,
         %Loot.ItemBox{} = item_box,
         {_tx, _ty} = target_coord
       ) do
    {:ok, items, updated_item_box} = Loot.ItemBox.take_items_by_types(item_box, planet.squad.loot_types)
    updated_land = change_tile(planet.land, target_coord, updated_item_box)

    {:ok, updated_squad} =
      planet.squad
      |> Squad.take_items(items)

    updated_planet =
      planet
      |> struct!(land: updated_land, squad: updated_squad)
      |> skip_npc_trigger(npc_coord, npc)

    {updated_planet, []}
  end

  defp skip_npc_trigger(%__MODULE__{} = planet, npc_coord, npc) do
    updated_squad =
      if coord?(npc.target) do
        Squad.remove_assigned_coord(planet.squad, npc.target)
      else
        planet.squad
      end

    updated_npc = trigger_npc(npc, nil)
    updated_land = change_tile(planet.land, npc_coord, updated_npc)

    struct!(planet, land: updated_land, squad: updated_squad)
  end

  defp trigger_npc(%Npc{} = npc, %{uuid: uuid}), do: Npc.trigger(npc, uuid)
  defp trigger_npc(%Npc{} = npc, target), do: Npc.trigger(npc, target)

  defp npc_attack(%__MODULE__{} = planet, npc_coord, %Npc{} = npc, target_coord) do
    cond do
      Squad.member?(planet.squad, npc) && planet.squad.resources.ammo > 0 ->
        updated_squad = Squad.register_shoot(planet.squad)

        planet
        |> struct!(squad: updated_squad)
        |> npc_attack_or_miss(npc_coord, npc, target_coord)

      Squad.member?(planet.squad, npc) ->
        {skip_npc_trigger(planet, npc_coord, npc), []}

      true ->
        npc_attack_or_miss(planet, npc_coord, npc, target_coord)
    end
  end

  defp npc_attack_or_miss(%__MODULE__{} = planet, npc_coord, %Npc{} = npc, target_coord) do
    if m_to_n?(npc.accuracy, @max_accuracy) do
      do_npc_attack(planet, npc_coord, npc, target_coord)
    else
      updated_npc =
        npc
        |> add_npc_shoot_event()
        |> Npc.add_events([Event.new(:missed_shoot)])

      updated_land = change_tile(planet.land, npc_coord, updated_npc)

      actions =
        if npc.target == :player do
          [Action.new(npc, :miss_attack)]
        else
          []
        end

      {struct!(planet, land: updated_land), actions}
    end
  end

  defp do_npc_attack(%__MODULE__{} = planet, npc_coord, %Npc{} = npc, target_coord) do
    case get_tile(planet.land, target_coord) do
      nil ->
        {planet, []}

      :player ->
        updated_npc = add_npc_shoot_event(npc)
        updated_land = change_tile(planet.land, npc_coord, updated_npc)
        {struct!(planet, land: updated_land), [Action.new(updated_npc, :attack)]}

      target ->
        do_npc_attack_by_target_uuid(planet, npc, npc_coord, target_coord, target)
    end
  end

  defp do_npc_attack_by_target_uuid(%__MODULE__{} = planet, %Npc{} = npc, npc_coord, target_coord, target) do
    updated_land = damage_object(planet.land, target_coord, target, npc.weapon.damage, npc.uuid)
    updated_squad = maybe_update_squad_after_attack(updated_land, target, target_coord, planet.squad)

    updated_npc = add_npc_shoot_event(npc)
    updated_land = change_tile(updated_land, npc_coord, updated_npc)

    {struct!(planet, land: updated_land, squad: updated_squad), attack_actions(npc, target)}
  end

  defp get_target_coord(%__MODULE__{current_coord: current_coord}, %{target: :player}), do: current_coord

  defp get_target_coord(%__MODULE__{} = planet, %{target: uuid}) when is_binary(uuid) do
    planet.current_coord
    |> visible_land_coords()
    |> Enum.find(fn coord ->
      case get_tile(planet.land, coord) do
        %{uuid: ^uuid} -> true
        _ -> false
      end
    end)
  end

  defp get_target_coord(%__MODULE__{}, %{target: {_x, _y} = coord}), do: coord

  defp get_target_coord(_, _), do: nil

  defp attack_actions(%Npc{} = npc, %{health: health} = target) when is_struct(target) do
    if health - npc.weapon.damage <= 0 do
      [Action.new({npc, struct!(target, health: 0)}, :attack)]
    else
      [Action.new({npc, target}, :attack)]
    end
  end

  defp attack_actions(%Enemy{} = enemy, %{health: health} = target) when is_struct(target) do
    if health - enemy.damage <= 0 do
      [Action.new({enemy, struct!(target, health: 0)}, :attack)]
    else
      [Action.new({enemy, target}, :attack)]
    end
  end

  defp attack_actions(_, _) do
    []
  end

  defp do_move_npc(%__MODULE__{} = planet, npc_coord, %Npc{} = npc, target_coord) do
    case calculate_move_coord(planet, npc_coord, target_coord, npc) do
      coord when coord == target_coord ->
        {planet, []}

      :stay ->
        {skip_npc_trigger(planet, npc_coord, npc), []}

      new_npc_coord ->
        target_tile = get_tile(planet.land, new_npc_coord)
        new_view_direction = coords_position(npc_coord, new_npc_coord)

        updated_npc =
          npc
          |> Npc.stand_on(target_tile)
          |> Npc.change_view_direction(new_view_direction)

        updated_squad =
          if Squad.member?(planet.squad, npc) do
            {:ok, updated_squad} = Squad.update_member(planet.squad, npc, new_npc_coord)
            updated_squad
          else
            planet.squad
          end

        {updated_land, _updated_npc} =
          planet.land
          |> change_tile(npc_coord, npc.stand_on)
          |> change_tile(new_npc_coord, updated_npc)
          |> maybe_autotransform_target_object(new_npc_coord, updated_npc)

        updated_planet = struct!(planet, land: updated_land, squad: updated_squad)
        {updated_planet, []}
    end
  end

  defp maybe_autotransform_target_object(land, subject_coord, subject) do
    if smart_subject?(subject) do
      object =
        land
        |> get_neighbors(subject_coord, 1, with_coords?: true, without_diagonal?: true)
        |> Enum.find(fn
          {_coord, %Object{} = object} -> Object.autotransformable_for_npc?(object)
          _ -> false
        end)

      case object do
        {coord, object} ->
          transform = Enum.find(object.transforms, & &1.autotransformable_for_npc?)
          updated_object = Object.transform(object, transform.name)
          updated_subject = add_transform_sound_event(subject, transform)

          updated_land =
            land
            |> change_tile(coord, updated_object)
            |> change_tile(subject_coord, updated_subject)

          {updated_land, updated_subject}

        _ ->
          {land, subject}
      end
    else
      {land, subject}
    end
  end

  defp add_transform_sound_event(%Npc{} = npc, %Object.Transform{transform_sound_name: sound_name}) do
    Npc.add_events(npc, [Event.new({:sound, sound_name})])
  end

  defp add_transform_sound_event(%Enemy{} = enemy, %Object.Transform{transform_sound_name: sound_name}) do
    Enemy.add_events(enemy, [Event.new({:sound, sound_name})])
  end

  defp add_transform_sound_event(subject, _) do
    subject
  end

  defp add_npc_shoot_event(%Npc{weapon: weapon} = npc) do
    Npc.add_events(npc, [Event.new({:shoot, weapon})])
  end

  defp trigger_enemies([], planet), do: {planet, []}

  defp trigger_enemies(enemies_coords, %__MODULE__{} = planet) do
    npc_coords = get_coords_of_visible_npc(planet)

    Enum.reduce(enemies_coords, {planet, []}, fn enemy_coord, {pl, act} ->
      enemy = get_tile(pl.land, enemy_coord)
      {updated_pl, actions} = trigger_enemy(pl, enemy_coord, enemy, npc_coords)
      {updated_pl, act ++ actions}
    end)
  end

  defp trigger_enemy(%__MODULE__{} = planet, enemy_coord, %Enemy{} = enemy, npc_coords) do
    {_, new_target} = closest_target(planet, enemy_coord, npc_coords, enemy)
    updated_enemy = trigger_enemy(enemy, new_target)
    updated_land = change_tile(planet.land, enemy_coord, updated_enemy)

    {struct!(planet, land: updated_land), []}
  end

  defp move_enemies(enemies_coords, %__MODULE__{} = planet) do
    Enum.reduce(enemies_coords, {planet, []}, fn enemy_coord, {pl, act} ->
      enemy = get_tile(pl.land, enemy_coord)
      {updated_pl, actions} = move_enemy(pl, enemy_coord, enemy)
      {updated_pl, act ++ actions}
    end)
  end

  defp trigger_enemy(%Enemy{} = enemy, %{uuid: uuid}), do: Enemy.trigger(enemy, uuid)
  defp trigger_enemy(%Enemy{} = enemy, target), do: Enemy.trigger(enemy, target)

  defp move_enemy(%__MODULE__{} = planet, enemy_coord, enemy) do
    {updated_planet, actions, _, _} =
      Enum.reduce(1..enemy.move_distance, {planet, [], enemy_coord, enemy}, fn _,
                                                                               {planet, actions, enemy_coord, enemy} ->
        move_enemy_step(planet, actions, enemy_coord, enemy)
      end)

    {updated_planet, actions}
  end

  defp move_enemy_step(%__MODULE__{} = planet, actions, enemy_coord, %Enemy{} = enemy) do
    case get_target_coord(planet, enemy) do
      nil ->
        {planet, actions, enemy_coord, enemy}

      target_coord ->
        do_move_enemy_step(planet, actions, enemy_coord, enemy, target_coord)
    end
  end

  defp do_move_enemy_step(%__MODULE__{} = planet, actions, enemy_coord, %Enemy{} = enemy, target_coord) do
    attack_position? = coords_distance(target_coord, enemy_coord) <= 1 && enemy.stand_on not in @swimable_tiles

    cond do
      attack_position? && enemy.target == :player ->
        {planet, actions ++ attack_or_miss(enemy), enemy_coord, enemy}

      attack_position? ->
        enemy_attack(planet, actions, enemy_coord, enemy, target_coord)

      true ->
        if m_to_n?(@enemy_move_possibility_from, @enemy_move_possibility_to) &&
             enemy_see_target?(enemy_coord, target_coord, enemy, planet.squad) do
          do_move_enemy(planet, enemy_coord, enemy, target_coord)
        else
          {planet, actions ++ [Action.new(enemy, :stay)], enemy_coord, enemy}
        end
    end
  end

  defp enemy_attack(%__MODULE__{} = planet, actions, enemy_coord, %Enemy{} = enemy, target_coord) do
    if m_to_n?(enemy.accuracy, @max_accuracy) do
      do_enemy_attack(planet, actions, enemy_coord, enemy, target_coord)
    else
      {planet, actions, enemy_coord, enemy}
    end
  end

  defp do_enemy_attack(%__MODULE__{} = planet, actions, enemy_coord, %Enemy{} = enemy, target_coord) do
    case get_tile(planet.land, target_coord) do
      nil ->
        {planet, [], enemy_coord, enemy}

      target ->
        do_enemy_attack_by_target_uuid(planet, actions, enemy, enemy_coord, target_coord, target)
    end
  end

  defp do_enemy_attack_by_target_uuid(
         %__MODULE__{} = planet,
         actions,
         %Enemy{} = enemy,
         enemy_coord,
         target_coord,
         target
       ) do
    updated_land = damage_object(planet.land, target_coord, target, enemy.damage, enemy.uuid)
    updated_squad = maybe_update_squad_after_attack(updated_land, target, target_coord, planet.squad)

    {struct!(planet, land: updated_land, squad: updated_squad), actions ++ attack_actions(enemy, target), enemy_coord,
     enemy}
  end

  defp do_move_enemy(%__MODULE__{} = planet, enemy_coord, enemy, target_coord) do
    case calculate_move_coord(planet, enemy_coord, target_coord, enemy) do
      coord when coord == target_coord ->
        {planet, [], enemy_coord, enemy}

      :stay ->
        {planet, [Action.new(enemy, :stay)], enemy_coord, enemy}

      new_enemy_coord ->
        target_tile = get_tile(planet.land, new_enemy_coord)
        updated_enemy = struct!(enemy, stand_on: target_tile) |> Enemy.maybe_add_speech_event()

        {updated_land, updated_enemy} =
          planet.land
          |> change_tile(enemy_coord, enemy.stand_on)
          |> change_tile(new_enemy_coord, updated_enemy)
          |> maybe_autotransform_target_object(new_enemy_coord, updated_enemy)

        actions = move_enemy_actions(updated_enemy)

        updated_planet = struct!(planet, land: updated_land)
        {updated_planet, actions, new_enemy_coord, updated_enemy}
    end
  end

  defp move_enemy_actions(%Enemy{target: :player, stand_on: tile} = enemy) when tile not in @swimable_tiles do
    [Action.new(enemy, :chasing)]
  end

  defp move_enemy_actions(_) do
    []
  end

  defp closest_target(%__MODULE__{} = planet, object_coord, target_coords, subject, opts \\ []) do
    if npc?(subject) && Squad.member?(planet.squad, subject) && planet.squad.resources.ammo == 0 do
      {nil, nil}
    else
      do_closest_target(planet, object_coord, target_coords, subject, opts)
    end
  end

  defp do_closest_target(%__MODULE__{} = planet, object_coord, target_coords, subject, opts) do
    target_coords = Enum.filter(target_coords, &(calculate_move_coord(planet, object_coord, &1, subject) != :stay))

    {closest_coord, closest_uuid} =
      if Enum.empty?(target_coords) do
        {nil, nil}
      else
        closest_coord =
          target_coords
          |> Enum.sort_by(&coords_distance(object_coord, &1))
          |> List.first()

        closest_uuid =
          case get_tile(planet.land, closest_coord) do
            %{uuid: _} = target -> target
            _ -> nil
          end

        {closest_coord, closest_uuid}
      end

    if Keyword.get(opts, :without_player) == true do
      {closest_coord, closest_uuid}
    else
      if closest_coord && closest_uuid && first_coord_closed?(closest_coord, planet.current_coord, object_coord) do
        {closest_coord, closest_uuid}
      else
        {planet.current_coord, :player}
      end
    end
  end

  defp calculate_move_coord(%__MODULE__{} = planet, {_sx, _sy} = subject_coord, {_tx, _ty} = target_coord, subject) do
    target_coord =
      if subject.stand_on in @swimable_tiles && coords_distance(subject_coord, target_coord) == 1 do
        neighbors =
          neighbor_coords(target_coord, 1)
          |> Enum.filter(&(movable_tile?(planet.land, &1, subject) && get_tile(planet.land, &1) not in @swimable_tiles))

        if Enum.empty?(neighbors) do
          :stay
        else
          Enum.random(neighbors)
        end
      else
        target_coord
      end

    if subject_coord == target_coord do
      :stay
    else
      case a_star(planet, subject_coord, target_coord, subject) do
        [_, next_coord | _rest] -> next_coord
        _ -> :stay
      end
    end
  end

  defp a_star(planet, start, target, subject) do
    open_set = %{start => {heuristic(start, target), 0}}
    came_from = %{}
    closed_set = MapSet.new()

    do_a_star(open_set, closed_set, came_from, target, planet, subject)
  end

  defp do_a_star(open_set, _closed_set, _came_from, _target, _planet, _subject) when open_set == %{}, do: :stay

  defp do_a_star(open_set, closed_set, came_from, target, planet, subject) do
    {current, {_, current_g}} = Enum.min_by(open_set, fn {_coord, {f, _g}} -> f end)

    view_distance =
      if npc_and_squad_member?(planet.squad, subject) do
        1000
      else
        @view_distance
      end

    cond do
      current == target ->
        reconstruct_path(came_from, current, [current])

      current_g >= view_distance ->
        :stay

      true ->
        open_set = Map.delete(open_set, current)
        closed_set = MapSet.put(closed_set, current)

        neighbors =
          planet
          |> get_valid_neighbors(current, target, subject)
          |> Enum.reject(&MapSet.member?(closed_set, &1))

        {next_open, next_came} =
          Enum.reduce(neighbors, {open_set, came_from}, &update_neighbor(&1, &2, current_g, current, target))

        do_a_star(next_open, closed_set, next_came, target, planet, subject)
    end
  end

  defp update_neighbor(neighbor, {open_acc, came_acc}, current_g, current, target) do
    tentative_g = current_g + 1

    case Map.get(open_acc, neighbor) do
      {_, existing_g} when tentative_g >= existing_g ->
        {open_acc, came_acc}

      _ ->
        f_score = tentative_g + heuristic(neighbor, target)
        {Map.put(open_acc, neighbor, {f_score, tentative_g}), Map.put(came_acc, neighbor, current)}
    end
  end

  defp heuristic({x1, y1}, {x2, y2}) do
    abs(x1 - x2) + abs(y1 - y2)
  end

  defp get_valid_neighbors(planet, coord, target, subject) do
    coord
    |> neighbor_coords(1, without_diagonal?: true)
    |> Enum.filter(fn coord ->
      coord == target || movable_tile?(planet.land, coord, subject)
    end)
  end

  defp reconstruct_path(came_from, current, path) do
    case Map.get(came_from, current) do
      nil -> path
      parent -> reconstruct_path(came_from, parent, [parent | path])
    end
  end

  defp attack_or_miss(%Enemy{} = enemy) do
    if m_to_n?(enemy.accuracy, @max_accuracy) do
      [Action.new(enemy, :attack)]
    else
      [Action.new(enemy, :miss_attack)]
    end
  end

  defp heal_enemies(enemies_coords, %__MODULE__{} = planet) do
    Enum.reduce(enemies_coords, {planet, []}, fn enemy_coord, {pl, act} ->
      enemy = get_tile(pl.land, enemy_coord)

      if Enemy.healer?(enemy) do
        {updated_pl, actions} = maybe_heal_enemies(pl, enemies_coords -- [enemy_coord], enemy)
        {updated_pl, act ++ actions}
      else
        {pl, act}
      end
    end)
  end

  defp maybe_heal_enemies(%__MODULE__{} = planet, enemies_coords, %Enemy{heal_unit: heal_unit} = healer_enemy) do
    Enum.reduce(enemies_coords, {planet, []}, fn enemy_coord, {pl, act} ->
      enemy = get_tile(pl.land, enemy_coord)

      if m_to_n?(1, healer_enemy.heal_possibility) && enemy.health + heal_unit <= enemy.max_health do
        healed_enemy = Enemy.heal(enemy, heal_unit)

        updated_land =
          pl.land
          |> change_tile(enemy_coord, healed_enemy)

        {struct!(pl, land: updated_land), act ++ [Action.new(healer_enemy, {:healed, healed_enemy, heal_unit})]}
      else
        {planet, []}
      end
    end)
  end

  defp maybe_tick_storm(%__MODULE__{storm: %Storm{} = storm} = planet) do
    case Storm.tick(storm) do
      {:ok, updated_storm} ->
        {struct!(planet, storm: updated_storm), [Action.new(:player, {:storm, storm})]}

      _ ->
        {struct!(planet, storm: nil), []}
    end
  end

  defp maybe_tick_storm(%__MODULE__{} = planet) do
    {planet, []}
  end

  defp maybe_perform_npc_actions(%__MODULE__{} = planet) do
    npc_actions = [
      fn npc_coords, planet -> trigger_npcs(npc_coords, planet) end,
      fn npc_coords, planet -> move_npcs(npc_coords, planet) end
    ]

    Enum.reduce(npc_actions, {planet, []}, fn action_fn, {planet, actions} ->
      npc_coords = (get_coords_of_visible_npc(planet) ++ Squad.member_coords(planet.squad)) |> Enum.uniq()

      {updated_planet, new_actions} = action_fn.(npc_coords, planet)
      {updated_planet, actions ++ new_actions}
    end)
  end

  defp damage_object(land, coord, %Enemy{} = enemy, damage, _subject) do
    if enemy.health - damage > 0 do
      updated_enemy =
        enemy
        |> Enemy.take_damage(damage)
        |> Enemy.stand_on(blood_tile(enemy.stand_on))

      change_tile(land, coord, updated_enemy)
    else
      generate_monster_body(land, coord, enemy)
    end
  end

  defp damage_object(land, coord, %Npc{} = npc, damage, subject) do
    if npc.health - damage > 0 do
      updated_npc =
        npc
        |> Npc.take_damage(damage)
        |> Npc.stand_on(blood_tile(npc.stand_on))
        |> trigger_npc(subject)

      change_tile(land, coord, updated_npc)
    else
      generate_human_body(land, coord, npc)
    end
  end

  defp damage_object(land, _, _, _, _), do: land

  defp maybe_update_squad_after_attack(land, %Npc{} = npc, npc_coord, %Squad{} = squad) do
    member? = Squad.member?(squad, npc)
    tile = get_tile(land, npc_coord)

    cond do
      member? && npc?(tile) ->
        {:ok, updated_squad} = Squad.update_member(squad, tile, npc_coord)
        updated_squad

      member? ->
        {:ok, updated_squad} = Squad.remove_member(squad, npc, :died)
        updated_squad

      true ->
        squad
    end
  end

  defp maybe_update_squad_after_attack(_, _, _, squad), do: squad

  defp movable_tile?(land, coord, subject \\ :player) do
    movable_tiles =
      case subject do
        %Enemy{} -> @enemy_movable_tiles
        _ -> @movable_tiles
      end

    case get_tile(land, coord) do
      %Loot.ItemBox{movable?: true} ->
        true

      %Object{movable?: true} ->
        true

      %Object{} = object ->
        smart_subject?(subject) && Object.autotransformable_for_npc?(object)

      tile ->
        tile in movable_tiles
    end
  end

  defp smart_subject?(%Npc{}), do: true
  defp smart_subject?(%Enemy{smart?: true}), do: true
  defp smart_subject?(_), do: false

  defp get_coords_of_structs_with_events_list(%__MODULE__{land: land} = planet) do
    not_empty_events? =
      fn events ->
        Enum.all?(events, fn
          %Event{} -> true
          _ -> false
        end) && not Enum.empty?(events)
      end

    planet.current_coord
    |> visible_land_coords()
    |> Enum.filter(fn coord ->
      case get_tile(land, coord) do
        %{uuid: _, events: events} = tile when is_struct(tile) and is_list(events) ->
          not_empty_events?.(events)

        _ ->
          false
      end
    end)
  end

  defp get_coords_of_visible_npc(%__MODULE__{land: land} = planet) do
    planet.current_coord
    |> visible_land_coords()
    |> Enum.filter(fn coord ->
      case get_tile(land, coord) do
        %Npc{} ->
          true

        _ ->
          false
      end
    end)
  end

  defp get_coords_of_visible_enemies(%__MODULE__{land: land} = planet) do
    planet.current_coord
    |> visible_land_coords()
    |> Enum.filter(fn coord ->
      case get_tile(land, coord) do
        %Enemy{} ->
          true

        _ ->
          false
      end
    end)
  end

  defp get_coords_of_visible_loot(%__MODULE__{land: land, squad: %Squad{loot_types: loot_types}} = planet) do
    planet.current_coord
    |> visible_land_coords()
    |> Enum.filter(fn coord ->
      case get_tile(land, coord) do
        %Loot.ItemBox{items: items} ->
          Enum.any?(items, &(Loot.Item.item_type(&1) in loot_types))

        _ ->
          false
      end
    end)
  end

  defp enemy_see_target?(enemy_coord, target_coord, %Enemy{target: :player}, %Squad{} = squad) do
    enemy_see_player?(enemy_coord, target_coord, squad)
  end

  defp enemy_see_target?(_, _, _, _), do: true

  defp enemy_see_player?(enemy_coord, player_coord, %Squad{} = squad) do
    members_count = Enum.count(squad.members)

    squad_penalty =
      if members_count > 0 do
        members_count + 2
      else
        0
      end

    coords_distance(enemy_coord, player_coord) <= @enemy_view_distance + squad_penalty
  end

  defp do_take_loot(
         %__MODULE__{} = planet,
         %Loot.ItemBox{} = updated_item_box,
         %Player{stand_on: %Loot.ItemBox{}} = updated_player
       ) do
    {:ok, planet, struct!(updated_player, stand_on: maybe_delete_empty_item_box(updated_item_box)), updated_item_box}
  end

  defp do_take_loot(
         %__MODULE__{} = planet,
         %Loot.ItemBox{} = updated_item_box,
         %Player{} = updated_player
       ) do
    target_coord = target_coord(planet, updated_player.view_direction)

    updated_land =
      planet.land
      |> change_tile(target_coord, maybe_delete_empty_item_box(updated_item_box))

    {:ok, struct!(planet, land: updated_land), updated_player, updated_item_box}
  end

  defp do_move(planet, target_coord, direction, player) do
    tile = get_tile(planet.land, target_coord)

    case tile do
      %Npc{player_enemy?: false} ->
        switch_positions_with_npc(planet, player, tile, target_coord)

      _ ->
        if movable_tile?(planet.land, target_coord) do
          do_move(planet, tile, target_coord, direction, player.stand_on)
        else
          attack_with_melee_weapon_or_stay(planet, player, target_coord, tile)
        end
    end
  end

  defp do_move(planet, tile, target_coord, direction, player_stand_on) do
    updated_land =
      planet.land
      |> change_tile(planet.current_coord, player_stand_on)
      |> change_tile(target_coord, @player)

    updated_planet =
      planet
      |> struct!(land: updated_land, current_coord: target_coord)
      |> maybe_generate_tiles(direction)

    move_cost = move_cost(tile) |> change_moves_count_in_storm(planet.storm, direction)
    {:moved, updated_planet, move_cost, tile, next_to_interactive_tile?(updated_planet)}
  end

  defp switch_positions_with_npc(
         %__MODULE__{} = planet,
         %Player{} = player,
         %Npc{stand_on: new_tile} = npc,
         target_coord
       ) do
    excuse = Enum.random([gettext("Sorry"), gettext("Oh.."), gettext("My bad")])

    updated_npc =
      npc
      |> Npc.stand_on(player.stand_on)
      |> Npc.add_events([Event.new({:speech, excuse})])

    updated_squad =
      if Squad.member?(planet.squad, updated_npc) do
        {:ok, updated_squad} = Squad.update_member(planet.squad, updated_npc, planet.current_coord)
        updated_squad
      else
        planet.squad
      end

    updated_land =
      planet.land
      |> change_tile(planet.current_coord, updated_npc)
      |> change_tile(target_coord, @player)

    updated_planet =
      planet
      |> struct!(land: updated_land, current_coord: target_coord, squad: updated_squad)
      |> maybe_generate_tiles(player.view_direction)

    move_cost = move_cost(new_tile)

    {:moved, updated_planet, move_cost, new_tile, next_to_interactive_tile?(updated_planet)}
  end

  defp attack_with_melee_weapon_or_stay(planet, player, target_coord, %Npc{player_enemy?: true} = npc) do
    do_attack_with_melee_weapon(planet, player, target_coord, npc)
  end

  defp attack_with_melee_weapon_or_stay(planet, player, target_coord, %Enemy{stand_on: tile} = enemy)
       when tile not in @swimable_tiles do
    do_attack_with_melee_weapon(planet, player, target_coord, enemy)
  end

  defp attack_with_melee_weapon_or_stay(_planet, _player, _target_coord, tile) do
    {:stay, tile}
  end

  defp do_attack_with_melee_weapon(%__MODULE__{} = planet, player, target_coord, enemy) do
    {damage, move_cost} =
      case PlayerManager.get_equipped_melee_weapon(player) do
        {:ok, %Loot.MeleeWeapon{hit_cost: hit_cost}} ->
          {PlayerManager.melee_weapon_damage(player), hit_cost}

        _ ->
          {1, 2}
      end

    if player.accuracy >= @max_accuracy || m_to_n?(player.accuracy, @max_accuracy) do
      {enemy, updated_land} = damage_enemy(planet.land, target_coord, enemy, damage)
      {:attack, struct!(planet, land: updated_land), [{enemy, damage}], move_cost}
    else
      {:attack, planet, [], move_cost}
    end
  end

  defp change_tile(land, {_x, _y} = coord, new_tile) do
    tiles = Map.put(land.tiles, coord, new_tile)
    struct!(land, tiles: tiles)
  end

  defp move_cost(%Loot.ItemBox{stand_on: tile, movable?: true}) do
    move_cost(tile)
  end

  defp move_cost(%Object{movable?: true, stand_on: tile}) do
    move_cost(tile)
  end

  defp move_cost(tile) do
    Map.fetch!(@move_costs, tile)
  end

  defp change_moves_count_in_storm(moves_count, %Storm{level: level, direction: storm_direction}, player_direction)
       when level > 4 do
    cond do
      player_direction == storm_direction ->
        max(moves_count - 1, 1)

      opposite_directions?(player_direction, storm_direction) ->
        moves_count + 1

      true ->
        moves_count
    end
  end

  defp change_moves_count_in_storm(moves_count, _, _), do: moves_count

  defp opposite_directions?(direction1, direction2) do
    opposite_directions = %{
      up: :down,
      down: :up,
      left: :right,
      right: :left
    }

    Map.fetch!(opposite_directions, direction1) == direction2
  end

  defp get_tile(land, {x, y}) do
    Map.get(land.tiles, {x, y})
  end

  defp map_land_intervals(%__MODULE__{current_coord: {x, y}}, view_distance, x_offset, y_offset) do
    x = x + x_offset
    y = y + y_offset

    n = div(view_distance, 2)

    x_from = x - n
    x_to = x + n
    y_from = y - n
    y_to = y + n

    {{x_from, x_to}, {y_from, y_to}}
  end

  defp visible_land_intervals({x, y}, view_distance \\ @view_distance) do
    n = div(view_distance, 2)

    x_from = x - n
    x_to = x + n
    y_from = y - n
    y_to = y + n

    {{x_from, x_to}, {y_from, y_to}}
  end

  defp visible_land_coords({_x, _y} = coord, view_distance \\ @view_distance) do
    {{x_from, x_to}, {y_from, y_to}} = visible_land_intervals(coord, view_distance)

    for y <- y_from..y_to do
      for x <- x_from..x_to do
        {x, y}
      end
    end
    |> List.flatten()
  end

  defp target_coord(planet, direction) do
    {x, y} = planet.current_coord

    case direction do
      :up -> {x, y - 1}
      :down -> {x, y + 1}
      :left -> {x - 1, y}
      :right -> {x + 1, y}
    end
  end

  defp generate_land do
    noise_coef = :rand.uniform()
    region_noise_coef = :rand.uniform()
    region_x_offset = round(:rand.uniform() * Enum.random(1..1000))
    region_y_offset = round(:rand.uniform() * Enum.random(1..1000))

    %Land{
      noise_coef: noise_coef,
      region_noise_coef: region_noise_coef,
      region_x_offset: region_x_offset,
      region_y_offset: region_y_offset
    }
    |> generate_initial_tiles()
  end

  defp generate_initial_tiles(%Land{} = land) do
    max_x = @initial_game_field_height - 1
    max_y = @initial_game_field_width - 1

    tiles =
      for x <- 0..max_x, y <- 0..max_y, into: %{} do
        {{x, y}, gen_initial_tile(x, y, land)}
      end

    struct!(land, tiles: tiles)
  end

  defp gen_initial_tile(x, y, %Land{} = land) do
    {center_x, center_y} = center_coord()

    cond do
      {x, y} == {center_x, center_y} ->
        @player

      {x, y} == {center_x + 1, center_y} ->
        tile = tile_by_perlin_noise(x, y, land)

        if tile in @movable_tiles do
          Loot.generate_item_box(:crashed_shuttle)
          |> Loot.ItemBox.stand_on(tile)
        else
          tile
        end

      true ->
        tile_by_perlin_noise(x, y, land)
    end
  end

  defp tile_by_perlin_noise({x, y}, %Land{} = land), do: tile_by_perlin_noise(x, y, land)

  defp tile_by_perlin_noise(x, y, %Land{} = land) do
    region = region_by_perlin_noise(x, y, land)
    noise_coef = land.noise_coef
    noise = PerlinNoise.noise(x * 0.1 + noise_coef, y * 0.1 + noise_coef)

    cond do
      region.city? && region.road_tile && road?(x, y) ->
        region.road_tile

      noise < -0.4 ->
        region.water_tile || @water

      noise >= -0.5 && noise <= 0.2 ->
        region.ice_tile || @ice

      true ->
        region.snow_tile || @snow
    end
  end

  defp region_by_perlin_noise(x, y, %Land{} = land) do
    freq = 0.002

    x = x + land.region_x_offset
    y = y + land.region_y_offset

    noise =
      PerlinNoise.noise(
        x * freq + land.region_noise_coef,
        y * freq + land.region_noise_coef
      )

    Enum.find(@regions, fn region -> noise <= region.noise_threshold end)
  end

  defp road?(x, y) do
    x = Integer.mod(x, @city_cell_size)
    y = Integer.mod(y, @city_cell_size)

    x < @city_road_width || y < @city_road_width
  end

  defp not_on_road?(%Region{} = region, {x, y}) do
    if region.city? && region.road_tile do
      not road?(x, y)
    else
      true
    end
  end

  defp generate_tile(%__MODULE__{} = planet, {x, y} = coord) do
    tile_by_perlin_noise(x, y, planet.land)
    |> tile_or_enemy(planet, coord)
    |> tile_or_loot(planet, coord)
    |> tile_or_npc(planet)
  end

  defp get_neighbors(land, coord, count, opts \\ []) do
    without_diagonal? = Keyword.get(opts, :without_diagonal?, false)

    coord
    |> neighbor_coords(count, without_diagonal?: without_diagonal?)
    |> Enum.map(fn coord ->
      tile = get_tile(land, coord)

      if Keyword.get(opts, :with_coords?) do
        {coord, tile}
      else
        tile
      end
    end)
  end

  defp neighbor_coords({x, y}, count, opts \\ []) do
    without_diagonal? = Keyword.get(opts, :without_diagonal?, false)

    Enum.map(1..count, fn n ->
      base_coords =
        [
          {x - n, y},
          {x, y - n},
          {x, y + n},
          {x + n, y}
        ]

      if without_diagonal? do
        base_coords
      else
        diagonals = [
          {x - n, y - n},
          {x - n, y + n},
          {x + n, y - n},
          {x + n, y + n}
        ]

        base_coords ++ diagonals
      end
    end)
    |> List.flatten()
  end

  defp tile_or_loot(tile, %__MODULE__{} = planet, {x, y}) do
    possibility =
      if tile in @high_loot_possibility_tiles do
        div(@base_loot_generate_possibility, 10) |> max(300)
      else
        @base_loot_generate_possibility
      end

    region = region_by_perlin_noise(x, y, planet.land)

    item_box_generator =
      if not Enum.empty?(region.specific_item_boxes) && m_to_n?(1, 5) do
        fn -> region.specific_item_boxes |> Enum.random() |> Loot.generate_item_box(tile) end
      else
        fn -> Loot.generate_item_box() |> Loot.ItemBox.stand_on(tile) end
      end

    if m_to_n?(1, possibility) && tile in @movable_tiles do
      item_box_generator.()
    else
      tile
    end
  end

  defp tile_or_enemy(tile, %__MODULE__{} = planet, {_x, _y} = coord) do
    {m, n} = generate_enemy_possibility(planet, coord)

    if m_to_n?(m, n) && tile in @enemy_movable_tiles do
      Enemy.generate_enemy()
      |> Enemy.stand_on(tile)
    else
      tile
    end
  end

  defp tile_or_npc(tile, planet) do
    if m_to_n?(1, @npc_generate_possibility) && tile in @movable_tiles do
      maybe_generate_npc(tile, planet)
    else
      tile
    end
  end

  defp maybe_generate_npc(tile, planet) do
    case Characters.pick(planet.characters_pid, planet.year - @disaster_year) do
      {:ok, character} -> Npc.new(character, tile)
      _ -> tile
    end
  end

  defp generate_enemy_possibility(%__MODULE__{} = planet, {x, y} = coord) do
    {m, n} =
      case region_by_perlin_noise(x, y, planet.land) do
        %Region{enemy_generate_possibility: nil} -> default_generate_enemy_possibility(planet, coord)
        %Region{enemy_generate_possibility: possibility} -> {1, possibility}
      end

    squad_members_count = Enum.count(planet.squad.members)

    if squad_members_count > 0 && m_to_n?(1, 10) do
      squad_penalty = squad_members_count * 5
      {m + squad_penalty, n}
    else
      {m, n}
    end
  end

  defp default_generate_enemy_possibility(%__MODULE__{} = planet, coord) do
    around_water_count =
      planet.land
      |> get_neighbors(coord, 3)
      |> Enum.count(fn tile -> tile in @water_tiles end)

    moves_count_factor = div(planet.moves_count, 500) * 5
    great_red_spots_factor = planet.great_red_spots * 10

    {m, n} =
      if around_water_count > 0 do
        {around_water_count, div(@base_enemy_generate_possibility - planet.year, around_water_count * 2)}
      else
        {max(moves_count_factor + great_red_spots_factor, 1), @base_enemy_generate_possibility}
      end

    {min(m, div(n, 2)), n}
  end

  defp center_coord do
    {div(@initial_game_field_width, 2), div(@initial_game_field_height, 2)}
  end

  defp initial_coord do
    center_coord()
  end

  defp maybe_generate_tiles(%__MODULE__{land: land} = planet, direction) do
    coords = visible_land_coords(planet.current_coord)

    {new_tiles, changed?} =
      Enum.reduce(coords, {%{}, false}, fn coord, {new_tiles, _changed?} = acc ->
        if get_tile(land, coord) do
          acc
        else
          {Map.put(new_tiles, coord, generate_tile(planet, coord)), true}
        end
      end)

    if changed? do
      updated_land = struct!(land, tiles: Map.merge(land.tiles, new_tiles))

      planet
      |> struct!(land: updated_land)
      |> maybe_generate_predefined(direction)
    else
      planet
    end
  end

  defp tile_or_storm(tile, _, _, nil), do: tile

  defp tile_or_storm(tile, current_coord, tile_coord, %Storm{} = storm) do
    max_view_distance = @view_distance
    view_distance = max(max_view_distance - storm.level, @min_view_distance)

    if view_distance < max_view_distance && coords_distance(current_coord, tile_coord) > view_distance do
      {:storm, storm.direction}
    else
      tile
    end
  end

  defp tile_or_darkness(tile, current_coord, tile_coord, current_hour, land, flashlight_coords) do
    max_view_distance = @view_distance

    view_distance =
      cond do
        current_hour <= 12 -> @min_view_distance + (max_view_distance - @min_view_distance) * current_hour / 12
        current_hour <= 18 -> max_view_distance
        true -> max_view_distance - (max_view_distance - @min_view_distance) * (current_hour - 18) / 6
      end

    if view_distance < max_view_distance && coords_distance(current_coord, tile_coord) > view_distance &&
         not bright_tile?(tile, tile_coord, land) && tile_coord not in flashlight_coords do
      @darkness
    else
      tile
    end
  end

  defp flashlight_coords(land, {x, y}, %Player{} = player) do
    coord_fun =
      case player.view_direction do
        :up -> fn m, n -> {x + m, y - n} end
        :down -> fn m, n -> {x + m, y + n} end
        :left -> fn m, n -> {x - n, y + m} end
        :right -> fn m, n -> {x + n, y + m} end
      end

    flashlights =
      Enum.filter(
        player.inventory,
        &(Loot.Item.item_type(&1) == :tool && &1.active? && &1.properties.illumination_range)
      )

    if Enum.empty?(flashlights) do
      []
    else
      flashlight = Enum.max_by(flashlights, & &1.properties.illumination_range)
      distance = flashlight.properties.illumination_range
      calculate_flashlight_coords(land, coord_fun, distance)
    end
  end

  defp calculate_flashlight_coords(land, coord_fun, distance) do
    Enum.map(-distance..distance, fn m_end ->
      Enum.map(1..distance, fn n ->
        m = round(m_end * n / distance)
        coord_fun.(m, n)
      end)
      |> stop_on_barrier(land)
    end)
    |> List.flatten()
  end

  defp bright_tile?(%Object{bright?: true}, _coord, _land), do: true

  defp bright_tile?(_tile, {x, y} = coord, land) do
    additional_coords = [
      {x + 2, y},
      {x - 2, y},
      {x, y + 2},
      {x, y - 2}
    ]

    (neighbor_coords(coord, 1) ++ additional_coords)
    |> Enum.any?(fn coord ->
      case get_tile(land, coord) do
        %Object{bright?: true} -> true
        _ -> false
      end
    end)
  end

  defp npc_and_squad_member?(%Squad{} = squad, %Npc{} = npc) do
    Squad.member?(squad, npc)
  end

  defp npc_and_squad_member?(%Squad{}, _), do: false

  defp coord?({x, y}) when is_integer(x) and is_integer(y), do: true
  defp coord?(_), do: false

  defp loot?(%Loot.ItemBox{}), do: true
  defp loot?(_), do: false

  defp npc?(%Npc{}), do: true
  defp npc?(_), do: false

  # TODO: figure out how to test this
  # coveralls-ignore-start

  defp maybe_generate_predefined(%__MODULE__{current_coord: {x, y}} = planet, direction) do
    in_predefined_cluster? = in_predefined_cluster?(planet.current_coord, planet.predefined_cluster_coord)
    region = region_by_perlin_noise(x, y, planet.land)

    default_predefined_possibility =
      case region do
        %Region{predefined_possibility: nil} -> @default_predefined_possibility
        %Region{predefined_possibility: possibility} -> possibility
      end

    {m, n} =
      if in_predefined_cluster? && !region.city? do
        {1, @predefined_cluster_possibility}
      else
        {1, default_predefined_possibility}
      end

    if m_to_n?(m, n) do
      if region.city? do
        generate_city_predefined(planet, region, direction)
      else
        do_generate_predefined(planet, region, direction, planet.current_coord)
      end
    else
      planet
    end
  end

  defp generate_city_predefined(%__MODULE__{} = planet, region, direction) do
    target_blocks = get_city_blocks(planet.current_coord, direction)

    Enum.reduce(target_blocks, planet, fn {bx, by}, planet_acc ->
      tile = get_tile(planet_acc.land, {bx + 2, by + 2})

      if is_nil(tile) || tile in @movable_tiles do
        do_generate_predefined(planet_acc, region, direction, {bx, by})
      else
        planet_acc
      end
    end)
  end

  # tries to generate for up to 3 times (because sometimes template not fits on landscape)
  defp do_generate_predefined(planet, region, direction, current_coord, attempts \\ 1)

  defp do_generate_predefined(%__MODULE__{} = planet, region, direction, current_coord, attempts) when attempts <= 3 do
    template = Templates.generate_random(region.predefined_subcategories)

    coord_fun = generate_template_coord_fun(direction, current_coord, region, template)
    new_tiles = generate_tiles_for_template(template, coord_fun, planet)

    all_tiles_valid? =
      Enum.all?(new_tiles, fn {{x, y} = coord, _} ->
        get_tile(planet.land, coord) |> is_nil() && tile_by_perlin_noise(x, y, planet.land) in @movable_tiles &&
          not_on_road?(region, coord) && region_by_perlin_noise(x, y, planet.land) == region
      end)

    if all_tiles_valid? do
      updated_land = struct!(planet.land, tiles: Map.merge(planet.land.tiles, new_tiles))
      struct!(planet, land: updated_land)
    else
      do_generate_predefined(planet, region, direction, current_coord, attempts + 1)
    end
  end

  defp do_generate_predefined(planet, _, _, _, _), do: planet

  defp in_predefined_cluster?(current_coord, cluster_coord) do
    distance = coords_distance(current_coord, cluster_coord)
    distance in 1..@predefined_cluster_distance
  end

  defp visible_coord?({_x1, _y1} = current_coord, {_x2, _y2} = coord) do
    coord in visible_land_coords(current_coord)
  end

  defp coords_distance({x1, y1}, {x2, y2}) do
    abs(x1 - x2) + abs(y1 - y2)
  end

  defp coords_on_same_line?({x1, y1}, {x2, y2}) do
    x1 == x2 || y1 == y2
  end

  defp coords_position({x1, y1}, {x2, y2}) do
    dx = x2 - x1
    dy = y2 - y1

    cond do
      abs(dx) >= abs(dy) and dx > 0 -> :right
      abs(dx) >= abs(dy) and dx < 0 -> :left
      abs(dy) > abs(dx) and dy > 0 -> :down
      abs(dy) > abs(dx) and dy < 0 -> :up
      true -> :up
    end
  end

  defp first_coord_closed?(first_coord, second_coord, target_coord) do
    coords_distance(first_coord, target_coord) < coords_distance(second_coord, target_coord)
  end

  defp generate_template_coord_fun(_direction, {bx, by}, %Region{city?: true}, template) do
    template_h = length(template)

    template_w =
      case template do
        [] -> 0
        [first_row | _] -> length(first_row)
      end

    diff_x = @city_block_size - template_w
    diff_y = @city_block_size - template_h

    offset_x = div(diff_x, 2)
    offset_y = div(diff_y, 2)

    target_x = bx + @city_road_width + offset_x
    target_y = by + @city_road_width + offset_y

    fn x, y -> {target_x + x, target_y + y} end
  end

  defp generate_template_coord_fun(direction, {current_x, current_y}, _region, _template) do
    padding = fn -> Enum.random(-10..10) end
    x_padding = current_x + padding.()
    y_padding = current_y + padding.()

    case direction do
      :up -> fn x, y -> {x + x_padding, y - @view_distance} end
      :down -> fn x, y -> {x + x_padding, y + @view_distance} end
      :left -> fn x, y -> {x - @view_distance, y + y_padding} end
      :right -> fn x, y -> {x + @view_distance, y + y_padding} end
    end
  end

  defp get_city_blocks({current_x, current_y}, direction) do
    view_distance = div(@view_distance, 2)

    bx_min = current_x - view_distance
    bx_max = current_x + view_distance
    by_min = current_y - view_distance
    by_max = current_y + view_distance

    {min_x, max_x, min_y, max_y} =
      case direction do
        :up -> {bx_min, bx_max, by_min - view_distance, by_max}
        :down -> {bx_min, bx_max, by_min, by_max + view_distance}
        :left -> {bx_min - view_distance, bx_max, by_min, by_max}
        :right -> {bx_min, bx_max + view_distance, by_min, by_max}
      end

    start_idx_x = Integer.floor_div(min_x, @city_cell_size)
    end_idx_x = Integer.floor_div(max_x, @city_cell_size)
    start_idx_y = Integer.floor_div(min_y, @city_cell_size)
    end_idx_y = Integer.floor_div(max_y, @city_cell_size)

    for idx_x <- start_idx_x..end_idx_x,
        idx_y <- start_idx_y..end_idx_y do
      {idx_x * @city_cell_size, idx_y * @city_cell_size}
    end
  end

  defp generate_tiles_for_template(template, coord_fun, planet) do
    Enum.with_index(template, fn row, y ->
      Enum.with_index(row, fn tile, x ->
        coord = coord_fun.(x, y)
        {coord, prepare_predefined_tile(tile, coord, planet)}
      end)
    end)
    |> List.flatten()
    |> Enum.into(%{})
  end

  defp predefined_stand_on_tile(land, {x, y}) do
    tile_by_perlin_noise(x, y, land)
  end

  # coveralls-ignore-stop
end
