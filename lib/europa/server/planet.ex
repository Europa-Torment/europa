defmodule Europa.Server.Planet do
  # TODO: get rid of changing the player structure inside this module, move it to server module
  @behaviour Europa.Server.PlanetManager

  use TypedStruct
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Errors.NotApplicableError
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Planet.Tiles.Tile
  alias Europa.Server.Planet.Tiles.Objects
  alias Europa.Server.Planet.Tiles.Objects.Object
  alias Europa.Server.Planet.Predefined
  alias Europa.Server.Planet.Region

  alias Europa.Tools.Types
  alias Europa.Tools.PerlinNoise

  alias Europa.Server.Player
  alias Europa.Server.PlayerManager
  alias Europa.Server.Loot
  alias Europa.Server.Loot.Tool
  alias Europa.Server.Loot.Weapon
  alias Europa.Server.Enemy
  alias Europa.Server.Action
  alias Europa.Server.Event
  alias Europa.Server.Characters
  alias Europa.Server.Npc

  import Europa.Tools.Randomizer
  import Europa.Tools.Conf

  @view_distance fetch_config!([__MODULE__, :view_distance])

  @initial_game_field_width @view_distance * 2
  @initial_game_field_height @view_distance * 2

  @view_distance fetch_config!([__MODULE__, :view_distance])
  @min_view_distance fetch_config!([__MODULE__, :min_view_distance])
  @generate_distance fetch_config!([__MODULE__, :generate_distance])

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

  @disaster_year fetch_config!([:game_params, :disaster_year])

  @player :player

  @type player() :: :player

  @type coord :: {x :: pos_integer(), y :: pos_integer()}

  @directions [:up, :down, :right, :left]
  @type direction :: unquote(Types.one_of(@directions))

  @type readable_tile_name :: String.t()

  @type tile :: unquote(Types.one_of(Tiles.tiles_values())) | player() | Loot.ItemBox.t() | Object.t()

  @type land :: list(list(tile()))

  @type interaction ::
          {:confirmation, Object.transform_confirmation_info()}
          | {:confirmation, :danger_action}
          | {:confirmation, {:pick_transform, list(Object.Transform.t())}}
          | {:talk, Npc.t()}
          | {:drink, :radioactive_water}
          | {:transform, Object.t()}
          | {:transform, Object.t(), Object.Transform.t()}

  @ice Tiles.tile(:ice).atom_value
  @ice_spikes Tiles.tile(:ice_spikes).atom_value
  @thin_ice Tiles.tile(:thin_ice).atom_value

  @water Tiles.tile(:water).atom_value
  @radioactive_water Tiles.tile(:radioactive_water).atom_value
  @warm_water Tiles.tile(:warm_water).atom_value

  @snow Tiles.tile(:snow).atom_value

  @concrete Tiles.tile(:concrete).atom_value
  @concrete_snow Tiles.tile(:concrete_snow).atom_value
  @ruins Tiles.tile(:ruins).atom_value

  @darkness Tiles.tile(:darkness).atom_value

  @movable_tiles Tiles.movable_tiles()
  @swimable_tiles Tiles.swimable_tiles()
  @enemy_movable_tiles @movable_tiles ++ @swimable_tiles

  @high_tiles Tiles.high_tiles()
  @warm_tiles Tiles.warm_tiles()
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
    %Region{water_tile: @water, ice_tile: @ice, snow_tile: @snow, noise_threshold: -0.16},
    %Region{water_tile: @thin_ice, ice_tile: @ice, snow_tile: @snow, noise_threshold: -0.11},
    %Region{water_tile: @warm_water, ice_tile: @ice, snow_tile: @snow, noise_threshold: -0.08},
    %Region{
      water_tile: @ruins,
      ice_tile: @concrete,
      snow_tile: @concrete_snow,
      enemy_generate_possibility: div(@base_enemy_generate_possibility, 20),
      predefined_possibility: div(@default_predefined_possibility, 10),
      predefined_subcategories: ["city"],
      specific_item_boxes: [:sun_battery],
      noise_threshold: 0.07
    },
    %Region{water_tile: @ice, ice_tile: @ice, snow_tile: @ice_spikes, noise_threshold: 0.18},
    %Region{water_tile: @radioactive_water, ice_tile: @ice, snow_tile: @thin_ice, noise_threshold: 0.47},
    %Region{water_tile: @ice, ice_tile: @ice, snow_tile: @snow, noise_threshold: 1.0}
  ]

  typedstruct module: Land, enforce: true do
    field :tiles, map(), default: %{}
    field :min_x, integer()
    field :max_x, integer()
    field :min_y, integer()
    field :max_y, integer()
    field :noise_coef, number()
    field :region_noise_coef, number()
    field :region_x_offset, number()
    field :region_y_offset, number()
  end

  typedstruct enforce: true do
    field :land, Land.t()
    field :current_coord, coord()
    field :predefined_cluster_coord, coord()
    field :year, pos_integer()
    field :moves_count, non_neg_integer()
    field :great_red_spots, non_neg_integer()
    field :characters_pid, pid(), enforce: true
    field :player_fraction, Characters.Character.fraction(), enforce: true
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
        player_fraction: player_fraction
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
  def get_visible_land(%__MODULE__{land: land, current_coord: current_coord} = planet, %DateTime{} = current_datetime) do
    current_hour = current_datetime.hour
    {{x_from, x_to}, {y_from, y_to}} = visible_land_intervals(planet)

    for y <- y_from..y_to do
      for x <- x_from..x_to do
        get_tile(land, {x, y}) |> tile_or_darkness(current_coord, {x, y}, current_hour, land)
      end
    end
  end

  @impl true
  def land_size(%__MODULE__{land: land}) do
    Enum.count(land.tiles)
  end

  @impl true
  def crop_land(%__MODULE__{land: land} = planet) do
    {{x_from, x_to}, {y_from, y_to}} = visible_land_intervals(planet)

    new_tiles =
      for x <- x_from..x_to do
        for y <- y_from..y_to do
          get_tile(land, {x, y})
        end
      end
      |> Enum.with_index(fn row, x ->
        Enum.with_index(row, fn tile, y ->
          {{x, y}, tile}
        end)
      end)
      |> List.flatten()
      |> Enum.into(%{})

    max_x = @view_distance
    max_y = @view_distance

    updated_land = struct!(land, tiles: new_tiles, min_x: 0, max_x: max_x, min_y: 0, max_y: max_y)
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
    with {:ok, weapon} <- PlayerManager.get_equiped_weapon(player) do
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
  def interact(%__MODULE__{land: land} = planet, direction, opts \\ []) do
    target_coord = target_coord(planet, direction)
    target_tile = get_tile(land, target_coord)

    do_interact(target_tile, planet, direction, opts)
  end

  @impl true
  def tick(%__MODULE__{} = planet, moves_count) when moves_count > 0 do
    planet
    |> maybe_set_new_predefined_cluster_coord()
    |> increment_moves_count(moves_count)
    |> do_tick(moves_count, [])
  end

  def tick(%__MODULE__{} = planet, _) do
    {:ok, planet, []}
  end

  @impl true
  def remove_last_events(%__MODULE__{} = planet) do
    coords = get_coords_of_structs_with_events_list(planet)

    {planet, events} =
      Enum.reduce(coords, {planet, []}, fn coord, {pl, events} ->
        %{uuid: uuid, events: [event | rest_events]} = tile = get_tile(pl.land, coord)
        updated_tile = struct!(tile, events: rest_events)
        updated_land = change_tile(pl.land, coord, updated_tile)
        {struct!(planet, land: updated_land), [{uuid, event} | events]}
      end)

    {:ok, planet, events}
  end

  ### PRIVATE ###

  defp next_to_interactive_tile?(%__MODULE__{} = planet) do
    Enum.any?(@directions, fn direction ->
      # Just checking for the possibility of interaction without planet updation.
      case interact(planet, direction, check: true) do
        {:error, :nothing} -> false
        _ -> true
      end
    end)
  end

  defp do_interact(%Npc{target: nil} = npc, planet, _view_direction, _opts) do
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
        |> prepare_predefined_tile(planet.land, target_coord, planet.characters_pid, planet.year)

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
      fn planet -> maybe_perform_npc_actions(planet) end,
      fn planet -> maybe_perform_enemies_actions(planet) end,
      fn planet -> maybe_warm_up(planet) end,
      fn planet -> maybe_add_radiation(planet) end
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
        rounds_per_shot = Loot.Weapon.rounds_per_shot(weapon)
        updated_weapon = Loot.Weapon.decrease_rounds_loaded(weapon, rounds_per_shot)
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

  defp find_targets(planet, coord, view_direction, %Loot.Weapon{shooting_type: st} = weapon)
       when st in [:bullet, :burst] do
    shooting_distance = weapon.shooting_distance
    find_direct_targets(planet, coord, view_direction, shooting_distance)
  end

  defp find_targets(planet, coord, view_direction, %Loot.Weapon{shooting_type: :shot} = weapon) do
    shooting_distance = weapon.shooting_distance
    find_shotgun_targets(planet, coord, view_direction, shooting_distance)
  end

  defp find_direct_targets(
         %__MODULE__{land: land},
         {x, y},
         view_direction,
         shooting_distance
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
          %Npc{} -> true
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
         %__MODULE__{land: land},
         coord,
         view_direction,
         shooting_distance
       ) do
    coord
    |> shotgun_targets(shooting_distance, land, view_direction)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.filter(fn coord ->
      case get_tile(land, coord) do
        %Enemy{stand_on: tile} when tile not in @swimable_tiles -> true
        %Npc{} -> true
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

  defp shoot_enemies(%__MODULE__{} = planet, %Player{} = player, %Loot.Weapon{} = weapon, enemies_coords)
       when is_list(enemies_coords) do
    rounds_per_shot = Loot.Weapon.rounds_per_shot(weapon)
    damage = weapon.damage * rounds_per_shot

    %{planet: updated_planet, shooted_enemies: shooted_enemies} =
      Enum.reduce(enemies_coords, %{shooted_enemies: [], planet: planet}, fn coord, acc ->
        distance_to_target = coords_distance(planet.current_coord, coord)

        accuracy =
          if distance_to_target == 1 do
            player.accuracy + 2
          else
            max(player.accuracy - distance_to_target, 1)
          end

        if accuracy >= @max_accuracy || m_to_n?(accuracy, @max_accuracy) do
          {enemy, updated_land} = shoot_enemy(acc.planet.land, coord, damage)

          acc
          |> Map.put(:planet, struct!(planet, land: updated_land))
          |> Map.put(:shooted_enemies, [{enemy, damage} | acc.shooted_enemies])
        else
          acc
        end
      end)

    updated_weapon = Loot.Weapon.decrease_rounds_loaded(weapon, rounds_per_shot)
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
      {updated_enemy, change_tile(land, coord, generate_monster_body(updated_enemy))}
    end
  end

  defp damage_enemy(land, coord, %Npc{} = npc, damage) do
    updated_npc =
      npc
      |> Npc.take_damage(damage)
      |> Npc.stand_on(blood_tile(npc.stand_on))
      |> maybe_trigger_npc(:player)

    if updated_npc.health > 0 do
      {updated_npc, change_tile(land, coord, updated_npc)}
    else
      {updated_npc, change_tile(land, coord, generate_human_body(updated_npc))}
    end
  end

  defp generate_monster_body(%Enemy{stand_on: %Loot.ItemBox{items: items, stand_on: stand_on}} = enemy) do
    monster_body =
      enemy
      |> Enemy.stand_on(stand_on)
      |> Loot.generate_item_box_from_enemy()

    struct!(monster_body, items: items ++ monster_body.items)
  end

  defp generate_monster_body(%Enemy{stand_on: tile}) when tile in @swimable_tiles do
    tile
  end

  defp generate_monster_body(%Enemy{} = enemy) do
    Loot.generate_item_box_from_enemy(enemy)
  end

  defp generate_human_body(%Npc{stand_on: %Loot.ItemBox{items: items, stand_on: stand_on}} = npc) do
    human_body =
      npc
      |> Npc.stand_on(stand_on)
      |> Loot.generate_item_box_from_npc()

    struct!(human_body, items: items ++ human_body.items)
  end

  defp generate_human_body(%Npc{} = npc) do
    Loot.generate_item_box_from_npc(npc)
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

  defp maybe_set_new_predefined_cluster_coord(%__MODULE__{} = planet) do
    if coords_distance(planet.current_coord, planet.predefined_cluster_coord) >= @predefined_cluster_update_distance do
      struct!(planet, predefined_cluster_coord: planet.current_coord)
    else
      planet
    end
  end

  defp increment_moves_count(%__MODULE__{} = planet, moves_count) when is_integer(moves_count) do
    struct!(planet, moves_count: planet.moves_count + moves_count)
  end

  defp maybe_warm_up(%__MODULE__{} = planet) do
    if next_to_warm_tile?(planet) do
      {planet, [Action.new(:player, :warm_up)]}
    else
      {planet, []}
    end
  end

  defp maybe_add_radiation(%__MODULE__{} = planet) do
    if next_to_radioactive_tile?(planet) && m_to_n?(1, 4) do
      {planet, [Action.new(:player, :radiation_contamination)]}
    else
      {planet, []}
    end
  end

  defp next_to_warm_tile?(%__MODULE__{land: land, current_coord: current_coord}) do
    land
    |> get_neighbors(current_coord, 1)
    |> Enum.any?(fn
      %Object{warm?: true} -> true
      tile -> tile in @warm_tiles and tile not in @movable_tiles
    end)
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
      enemies_coords = get_coords_of_enemies_which_see_player(planet)

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
    enemy_npc_coords =
      other_npc_coords
      |> Enum.filter(fn coord ->
        case get_tile(planet.land, coord) do
          %Npc{} = other_npc ->
            Characters.enemies?(npc.character, other_npc.character)

          _ ->
            false
        end
      end)

    {new_target_coord, new_target} =
      closest_target(planet, npc_coord, enemy_coords ++ enemy_npc_coords, without_player: true)

    enemy_fraction? = planet.player_fraction in npc.character.enemy_fractions

    new_target =
      cond do
        new_target && enemy_fraction? &&
            first_coord_closed?(planet.current_coord, new_target_coord, npc_coord) ->
          :player

        is_nil(new_target) && enemy_fraction? ->
          :player

        new_target ->
          new_target

        true ->
          {planet, []}
      end

    updated_npc = Npc.trigger(npc, new_target)
    updated_land = change_tile(planet.land, npc_coord, updated_npc)

    {struct!(planet, land: updated_land), []}
  end

  defp trigger_npc(%__MODULE__{} = planet, _, _, _, _), do: {planet, []}

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
    updated_npc = Npc.maybe_add_speech_event(npc)
    updated_land = change_tile(planet.land, npc_coord, updated_npc)

    {struct!(planet, land: updated_land), []}
  end

  defp move_npc(%__MODULE__{} = planet, npc_coord, %Npc{weapon: %Weapon{shooting_distance: shooting_distance}} = npc) do
    case get_target_coord(planet, npc) do
      nil ->
        skip_npc_trigger(planet, npc_coord, npc)

      target_coord ->
        target = get_tile(planet.land, target_coord)
        new_view_direction = coords_position(npc_coord, target_coord)
        npc = Npc.change_view_direction(npc, new_view_direction)

        find_targets(planet, npc_coord, npc.view_direction, npc.weapon)

        cond do
          !m_to_n?(@npc_move_possibility_from, @npc_move_possibility_to) ->
            {planet, []}

          target != nil && coords_on_same_line?(npc_coord, target_coord) &&
            coords_distance(npc_coord, target_coord) in 1..shooting_distance &&
              target_coord in find_targets(planet, npc_coord, npc.view_direction, npc.weapon) ->
            npc_attack(planet, npc_coord, npc, target_coord)

          target != nil ->
            do_move_npc(planet, npc_coord, npc, target_coord)

          true ->
            skip_npc_trigger(planet, npc_coord, npc)
        end
    end
  end

  defp skip_npc_trigger(%__MODULE__{} = planet, npc_coord, npc) do
    updated_npc = maybe_trigger_npc(npc, nil)
    updated_land = change_tile(planet.land, npc_coord, updated_npc)
    {struct!(planet, land: updated_land), []}
  end

  defp maybe_trigger_npc(%Npc{target: :player} = npc, _), do: npc
  defp maybe_trigger_npc(%Npc{} = npc, target), do: Npc.trigger(npc, target)

  defp npc_attack(%__MODULE__{} = planet, npc_coord, %Npc{} = npc, target_coord) do
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
    updated_target = damage_object(target, npc.weapon.damage, npc.uuid)
    updated_npc = add_npc_shoot_event(npc)

    updated_land =
      planet.land
      |> change_tile(target_coord, updated_target)
      |> change_tile(npc_coord, updated_npc)

    {struct!(planet, land: updated_land), attack_actions(npc, target)}
  end

  defp get_target_coord(%__MODULE__{current_coord: current_coord}, %{target: :player}), do: current_coord

  defp get_target_coord(%__MODULE__{} = planet, %{target: uuid}) when is_binary(uuid) do
    planet
    |> visible_land_coords()
    |> Enum.find(fn coord ->
      case get_tile(planet.land, coord) do
        %{uuid: ^uuid} -> true
        _ -> false
      end
    end)
  end

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
    case calculate_move_coord(planet, npc_coord, target_coord, :npc) do
      :stay ->
        {planet, []}

      new_npc_coord ->
        target_tile = get_tile(planet.land, new_npc_coord)

        new_view_direction = coords_position(npc_coord, target_coord)

        updated_npc =
          npc
          |> Npc.stand_on(target_tile)
          |> Npc.change_view_direction(new_view_direction)

        updated_land =
          planet.land
          |> change_tile(npc_coord, npc.stand_on)
          |> change_tile(new_npc_coord, updated_npc)

        updated_planet = struct!(planet, land: updated_land)
        {updated_planet, []}
    end
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
    {_, new_target} = closest_target(planet, enemy_coord, npc_coords)
    updated_enemy = Enemy.trigger(enemy, new_target)
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
        if m_to_n?(@enemy_move_possibility_from, @enemy_move_possibility_to) do
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
    updated_target = damage_object(target, enemy.damage, enemy.uuid)

    updated_land =
      planet.land
      |> change_tile(target_coord, updated_target)

    {struct!(planet, land: updated_land), actions ++ attack_actions(enemy, target), enemy_coord, enemy}
  end

  defp do_move_enemy(%__MODULE__{} = planet, enemy_coord, enemy, target_coord) do
    case calculate_move_coord(planet, enemy_coord, target_coord, :enemy) do
      :stay ->
        {planet, [Action.new(enemy, :stay)], enemy_coord, enemy}

      new_enemy_coord ->
        target_tile = get_tile(planet.land, new_enemy_coord)
        updated_enemy = struct!(enemy, stand_on: target_tile) |> Enemy.maybe_add_speech_event()

        updated_land =
          planet.land
          |> change_tile(enemy_coord, enemy.stand_on)
          |> change_tile(new_enemy_coord, updated_enemy)

        actions = move_enemy_actions(updated_enemy)

        updated_planet = struct!(planet, land: updated_land)
        {updated_planet, actions, new_enemy_coord, updated_enemy}
    end
  end

  defp move_enemy_actions(%Enemy{stand_on: tile}) when tile in @swimable_tiles do
    []
  end

  defp move_enemy_actions(enemy) do
    [Action.new(enemy, :chasing)]
  end

  defp closest_target(%__MODULE__{} = planet, object_coord, target_coords, opts \\ []) do
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
            %{uuid: uuid} -> uuid
            _ -> nil
          end

        {closest_coord, closest_uuid}
      end

    if Keyword.get(opts, :without_player) == true do
      {closest_coord, closest_uuid}
    else
      if closest_coord && closest_uuid &&
           first_coord_closed?(closest_coord, planet.current_coord, object_coord) do
        {closest_coord, closest_uuid}
      else
        {planet.current_coord, :player}
      end
    end
  end

  defp calculate_move_coord(%__MODULE__{} = planet, {ox, oy} = _moving_object, {tx, ty} = _target, subject) do
    x_diff = abs(ox - tx)
    y_diff = abs(oy - ty)

    new_ox = if ox > tx, do: ox - 1, else: ox + 1
    new_oy = if oy > ty, do: oy - 1, else: oy + 1

    move_x_coord = {new_ox, oy}
    move_y_coord = {ox, new_oy}

    move_x =
      if movable_tile?(planet.land, move_x_coord, subject) do
        move_x_coord
      else
        nil
      end

    move_y =
      if movable_tile?(planet.land, move_y_coord, subject) do
        move_y_coord
      else
        nil
      end

    desperate_moves =
      [{ox + 1, oy}, {ox - 1, oy}, {ox, oy + 1}, {ox, oy - 1}]
      |> Enum.filter(fn coord -> movable_tile?(planet.land, coord, subject) end)

    cond do
      x_diff > y_diff && move_x ->
        move_x

      y_diff > x_diff && move_y ->
        move_y

      y_diff == x_diff && move_x && move_y ->
        Enum.random([move_x, move_y])

      move_x != nil ->
        move_x

      move_y != nil ->
        move_y

      !Enum.empty?(desperate_moves) ->
        Enum.random(desperate_moves)

      true ->
        :stay
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

  defp maybe_perform_npc_actions(%__MODULE__{} = planet) do
    npc_actions = [
      fn npc_coords, planet -> trigger_npcs(npc_coords, planet) end,
      fn npc_coords, planet -> move_npcs(npc_coords, planet) end
    ]

    Enum.reduce(npc_actions, {planet, []}, fn action_fn, {planet, actions} ->
      npc_coords = get_coords_of_visible_npc(planet)

      {updated_planet, new_actions} = action_fn.(npc_coords, planet)
      {updated_planet, actions ++ new_actions}
    end)
  end

  defp damage_object(%Enemy{} = enemy, damage, _subject) do
    if enemy.health - damage > 0 do
      enemy
      |> Enemy.take_damage(damage)
      |> Enemy.stand_on(blood_tile(enemy.stand_on))
    else
      generate_monster_body(enemy)
    end
  end

  defp damage_object(%Npc{} = npc, damage, subject) do
    if npc.health - damage > 0 do
      npc
      |> Npc.take_damage(damage)
      |> Npc.stand_on(blood_tile(npc.stand_on))
      |> maybe_trigger_npc(subject)
    else
      generate_human_body(npc)
    end
  end

  defp damage_object(object, _, _), do: object

  defp movable_tile?(land, coord, subject \\ :player) do
    movable_tiles =
      case subject do
        :enemy -> @enemy_movable_tiles
        _ -> @movable_tiles
      end

    case get_tile(land, coord) do
      %Loot.ItemBox{movable?: true} ->
        true

      %Object{movable?: true} ->
        true

      tile ->
        tile in movable_tiles
    end
  end

  defp get_coords_of_structs_with_events_list(%__MODULE__{land: land} = planet) do
    not_empty_events? =
      fn events ->
        Enum.all?(events, fn
          %Event{} -> true
          _ -> false
        end) && not Enum.empty?(events)
      end

    planet
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
    planet
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
    planet
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

  defp get_coords_of_enemies_which_see_player(%__MODULE__{current_coord: current_coord, land: land} = planet) do
    planet
    |> get_coords_of_visible_enemies()
    |> Enum.filter(fn coord ->
      case get_tile(land, coord) do
        %Enemy{} ->
          enemy_see_player?(current_coord, coord)

        _ ->
          false
      end
    end)
  end

  defp enemy_see_player?(coord1, coord2) do
    coords_distance(coord1, coord2) <= @enemy_view_distance
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

    if movable_tile?(planet.land, target_coord) do
      do_move(planet, tile, target_coord, direction, player.stand_on)
    else
      attack_with_melee_weapon_or_stay(planet, player, target_coord, tile)
    end
  end

  defp maybe_delete_empty_item_box(%Loot.ItemBox{type: :bag, items: [], stand_on: stand_on}), do: stand_on
  defp maybe_delete_empty_item_box(item_box), do: item_box

  defp do_move(planet, tile, target_coord, direction, player_stand_on) do
    updated_land =
      planet.land
      |> change_tile(planet.current_coord, player_stand_on)
      |> change_tile(target_coord, @player)

    updated_planet =
      planet
      |> struct!(land: updated_land, current_coord: target_coord)
      |> maybe_generate_tiles(direction)

    move_cost = move_cost(tile)

    {:moved, updated_planet, move_cost, tile, next_to_interactive_tile?(updated_planet)}
  end

  defp attack_with_melee_weapon_or_stay(planet, player, target_coord, %Npc{target: :player} = npc) do
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
      case PlayerManager.get_equiped_melee_weapon(player) do
        {:ok, %Loot.MeleeWeapon{damage: damage, hit_cost: hit_cost}} -> {damage, hit_cost}
        _ -> {1, 2}
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

  defp get_tile(land, {x, y}) do
    Map.get(land.tiles, {x, y})
  end

  defp visible_land_intervals(%__MODULE__{current_coord: {x, y}, land: land}) do
    n = div(@view_distance, 2)

    x_from = x - n
    x_to = min(x + n, land.max_x)
    y_from = y - n
    y_to = min(y + n, land.max_y)

    {{x_from, x_to}, {y_from, y_to}}
  end

  defp visible_land_coords(%__MODULE__{} = planet) do
    {{x_from, x_to}, {y_from, y_to}} = visible_land_intervals(planet)

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
    max_x = @initial_game_field_height - 1
    max_y = @initial_game_field_width - 1

    noise_coef = :rand.uniform()
    region_noise_coef = :rand.uniform()
    region_x_offset = round(:rand.uniform() * Enum.random(1..1000))
    region_y_offset = round(:rand.uniform() * Enum.random(1..1000))

    %Land{
      min_x: 0,
      max_x: max_x,
      min_y: 0,
      max_y: max_y,
      noise_coef: noise_coef,
      region_noise_coef: region_noise_coef,
      region_x_offset: region_x_offset,
      region_y_offset: region_y_offset
    }
    |> generate_initial_tiles()
  end

  defp generate_initial_tiles(%Land{} = land) do
    tiles =
      for x <- 0..land.max_x, y <- 0..land.max_y, into: %{} do
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

  defp tile_by_perlin_noise(x, y, %Land{} = land) do
    region = region_by_perlin_noise(x, y, land)
    noise_coef = land.noise_coef
    noise = PerlinNoise.noise(x * 0.1 + noise_coef, y * 0.1 + noise_coef)

    cond do
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

  defp generate_tile(%__MODULE__{} = planet, {x, y} = coord) do
    tile_by_perlin_noise(x, y, planet.land)
    |> tile_or_enemy(planet, coord)
    |> tile_or_loot(planet, coord)
    |> tile_or_npc(planet)
  end

  defp get_neighbors(land, coord, count, with_coord? \\ false) do
    coord
    |> neighbor_coords(count)
    |> Enum.map(fn coord ->
      tile = get_tile(land, coord)

      if with_coord? do
        {coord, tile}
      else
        tile
      end
    end)
  end

  defp neighbor_coords({x, y}, count) do
    Enum.map(1..count, fn n ->
      [
        {x - n, y - n},
        {x - n, y},
        {x - n, y + n},
        {x, y - n},
        {x, y + n},
        {x + n, y - n},
        {x + n, y},
        {x + n, y + n}
      ]
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
    case region_by_perlin_noise(x, y, planet.land) do
      %Region{enemy_generate_possibility: nil} -> default_generate_enemy_possibility(planet, coord)
      %Region{enemy_generate_possibility: possibility} -> {1, possibility}
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

  defp maybe_generate_tiles(%__MODULE__{current_coord: {x, _y}} = planet, :right) do
    if (planet.land.max_x - x) in 1..@generate_distance do
      struct!(planet, land: add_right_column(planet))
    else
      planet
    end
  end

  defp maybe_generate_tiles(%__MODULE__{current_coord: {x, _y}} = planet, :left) do
    if x in planet.land.min_x..@generate_distance do
      struct!(planet, land: add_left_column(planet))
    else
      planet
    end
  end

  defp maybe_generate_tiles(%__MODULE__{current_coord: {_x, y}} = planet, :up) do
    if y in planet.land.min_y..@generate_distance do
      struct!(planet, land: add_top_row(planet))
    else
      planet
    end
  end

  defp maybe_generate_tiles(%__MODULE__{current_coord: {_x, y}} = planet, :down) do
    if (planet.land.max_y - y) in 1..@generate_distance do
      struct!(planet, land: add_bottom_row(planet))
    else
      planet
    end
  end

  defp maybe_generate_tiles(planet, _), do: planet

  defp add_right_column(%__MODULE__{land: land} = planet) do
    new_max_x = land.max_x + 1

    new_tiles =
      for y <- land.min_y..land.max_y, into: %{} do
        {{new_max_x, y}, generate_tile(planet, {new_max_x, y})}
      end
      |> filter_exist_tiles(land)

    struct!(land, tiles: Map.merge(land.tiles, new_tiles), max_x: new_max_x)
    |> maybe_generate_predefined(:right, planet.characters_pid, planet)
  end

  defp add_left_column(%__MODULE__{land: land} = planet) do
    new_min_x = land.min_x - 1

    new_tiles =
      for y <- land.min_y..land.max_y, into: %{} do
        {{new_min_x, y}, generate_tile(planet, {new_min_x, y})}
      end
      |> filter_exist_tiles(land)

    struct!(land, tiles: Map.merge(land.tiles, new_tiles), min_x: new_min_x)
    |> maybe_generate_predefined(:left, planet.characters_pid, planet)
  end

  defp add_top_row(%__MODULE__{land: land} = planet) do
    new_min_y = land.min_y - 1

    new_tiles =
      for x <- land.min_x..land.max_x, into: %{} do
        {{x, new_min_y}, generate_tile(planet, {x, new_min_y})}
      end
      |> filter_exist_tiles(land)

    struct!(land, tiles: Map.merge(land.tiles, new_tiles), min_y: new_min_y)
    |> maybe_generate_predefined(:up, planet.characters_pid, planet)
  end

  defp add_bottom_row(%__MODULE__{land: land} = planet) do
    new_max_y = land.max_y + 1

    new_tiles =
      for x <- land.min_x..land.max_x, into: %{} do
        {{x, new_max_y}, generate_tile(planet, {x, new_max_y})}
      end
      |> filter_exist_tiles(land)

    struct!(land, tiles: Map.merge(land.tiles, new_tiles), max_y: new_max_y)
    |> maybe_generate_predefined(:down, planet.characters_pid, planet)
  end

  defp filter_exist_tiles(tiles, land) do
    tiles
    |> Enum.filter(fn {coord, _} -> get_tile(land, coord) |> is_nil() end)
    |> Enum.into(%{})
  end

  defp tile_or_darkness(tile, current_coord, tile_coord, current_hour, land) do
    max_view_distance = @view_distance

    view_distance =
      cond do
        current_hour <= 12 -> @min_view_distance + (max_view_distance - @min_view_distance) * current_hour / 12
        current_hour <= 18 -> max_view_distance
        true -> max_view_distance - (max_view_distance - @min_view_distance) * (current_hour - 18) / 6
      end

    if view_distance < max_view_distance && coords_distance(current_coord, tile_coord) > view_distance &&
         not bright_tile?(tile, tile_coord, land) do
      @darkness
    else
      tile
    end
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

  # TODO: figure out how to test this
  # coveralls-ignore-start

  defp maybe_generate_predefined(land, direction, characters_pid, %__MODULE__{current_coord: {x, y}} = planet) do
    in_predefined_cluster? = in_predefined_cluster?(planet.current_coord, planet.predefined_cluster_coord)
    region = region_by_perlin_noise(x, y, land)

    default_predefined_possibility =
      case region do
        %Region{predefined_possibility: nil} -> @default_predefined_possibility
        %Region{predefined_possibility: possibility} -> possibility
      end

    {m, n} =
      if in_predefined_cluster? do
        {1, @predefined_cluster_possibility}
      else
        {1, default_predefined_possibility}
      end

    if m_to_n?(m, n) do
      do_generate_predefined(land, region, direction, characters_pid, planet)
    else
      land
    end
  end

  # tries to generate for up to 5 times (because sometimes template not fits on landscape)
  defp do_generate_predefined(land, region, direction, characters_pid, planet, attempts \\ 1)

  defp do_generate_predefined(land, region, direction, characters_pid, planet, attempts) when attempts <= 5 do
    template = Predefined.generate_random(region.predefined_subcategories)

    coord_fun = generate_template_coord_fun(land, direction, planet.current_coord)
    new_tiles = generate_tiles_for_template(template, coord_fun, land, characters_pid, planet.year)

    is_all_tiles_movable =
      Enum.all?(new_tiles, fn {{x, y}, _} ->
        get_tile(land, {x, y}) |> is_nil() && tile_by_perlin_noise(x, y, land) in @movable_tiles
      end)

    # Avoid placing region specific predefines in other regions
    is_all_tiles_in_current_region =
      if Enum.empty?(region.predefined_subcategories) do
        true
      else
        Enum.all?(new_tiles, fn {{x, y}, _} -> region_by_perlin_noise(x, y, land) == region end)
      end

    if is_all_tiles_movable && is_all_tiles_in_current_region do
      struct!(land, tiles: Map.merge(land.tiles, new_tiles))
    else
      do_generate_predefined(land, region, direction, characters_pid, planet, attempts + 1)
    end
  end

  defp do_generate_predefined(land, _, _, _, _, _), do: land

  defp in_predefined_cluster?(current_coord, cluster_coord) do
    distance = coords_distance(current_coord, cluster_coord)
    distance in 1..@predefined_cluster_distance
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
    end
  end

  defp first_coord_closed?(first_coord, second_coord, target_coord) do
    coords_distance(first_coord, target_coord) < coords_distance(second_coord, target_coord)
  end

  defp generate_template_coord_fun(land, direction, {current_x, current_y}) do
    padding = fn -> Enum.random(-10..10) end

    x_padding = current_x + padding.()
    y_padding = current_y + padding.()

    case direction do
      :up -> fn x, y -> {x + x_padding, y - abs(land.min_y - @view_distance)} end
      :down -> fn x, y -> {x + x_padding, y + (land.max_y + @view_distance)} end
      :left -> fn x, y -> {x - abs(land.min_x - @view_distance), y + y_padding} end
      :right -> fn x, y -> {x + (land.max_x + @view_distance), y + y_padding} end
    end
  end

  defp generate_tiles_for_template(template, coord_fun, land, characters_pid, year) do
    Enum.with_index(template, fn row, y ->
      Enum.with_index(row, fn tile, x ->
        coord = coord_fun.(x, y)
        {coord, prepare_predefined_tile(tile, land, coord, characters_pid, year)}
      end)
    end)
    |> List.flatten()
    |> Enum.into(%{})
  end

  defp prepare_predefined_tile(%Enemy{stand_on: nil} = enemy, land, coord, _, _) do
    stand_on = predefined_stand_on_tile(land, coord)
    Enemy.stand_on(enemy, stand_on)
  end

  defp prepare_predefined_tile(%Loot.ItemBox{stand_on: nil} = item_box, land, coord, _, _) do
    stand_on = predefined_stand_on_tile(land, coord)
    Loot.ItemBox.stand_on(item_box, stand_on)
  end

  defp prepare_predefined_tile(%Object{stand_on: nil} = object, land, coord, _, _) do
    stand_on = predefined_stand_on_tile(land, coord)
    Object.stand_on(object, stand_on)
  end

  defp prepare_predefined_tile({:npc, stand_on}, land, coord, characters_pid, year) do
    stand_on = stand_on || predefined_stand_on_tile(land, coord)

    case Characters.pick(characters_pid, year - @disaster_year) do
      {:ok, character} ->
        Npc.new(character, stand_on)

      _ ->
        stand_on
    end
  end

  defp prepare_predefined_tile(tile, _, _, _, _), do: tile

  defp predefined_stand_on_tile(land, {x, y}) do
    tile_by_perlin_noise(x, y, land)
  end

  # coveralls-ignore-stop
end
