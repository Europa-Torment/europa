defmodule Europa.Server.Planet do
  @behaviour Europa.Server.PlanetManager

  use TypedStruct
  use Gettext, backend: Europa.Gettext

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
  alias Europa.Server.Enemy
  alias Europa.Server.Action
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

  @region_switch_possibility fetch_config!([__MODULE__, :region_switch_possibility])

  @enemy_move_possibility_from fetch_config!([__MODULE__, :enemy_move_possibility, :from])
  @enemy_move_possibility_to fetch_config!([__MODULE__, :enemy_move_possibility, :to])

  @max_accuracy fetch_config!([:weapons, :max_accuracy])

  @base_loot_generate_possibility fetch_config!([__MODULE__, :base_loot_generate_possibility])

  @npc_generate_possibility fetch_config!([__MODULE__, :npc_generate_possibility])

  @predefined_cluster_distance fetch_config!([__MODULE__, :predefined_cluster_distance])
  @predefined_cluster_update_distance fetch_config!([__MODULE__, :predefined_cluster_update_distance])

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
          {:talk, Npc.t()}
          | {:drink, :radioactive_water}
          | {:confirmation, {:required_tools, list(Loot.Tool.t())} | :danger_action}
          | {:transform, Object.t()}

  @ice Tiles.tile(:ice).atom_value
  @water Tiles.tile(:water).atom_value
  @radioactive_water Tiles.tile(:radioactive_water).atom_value
  @warm_water Tiles.tile(:warm_water).atom_value
  @snow Tiles.tile(:snow).atom_value
  @path Tiles.tile(:path).atom_value
  @snow_blood Tiles.tile(:snow).blood_version
  @path_blood Tiles.tile(:path).blood_version

  @darkness Tiles.tile(:darkness).atom_value

  @movable_tiles Tiles.movable_tiles()
  @high_tiles Tiles.high_tiles()
  @warm_tiles Tiles.warm_tiles()
  @radioactive_tiles Tiles.radioactive_tiles()

  @water_tiles [@water, @radioactive_water, @warm_water]

  @move_costs Tiles.move_costs()

  @tiles_readable_names Tiles.readable_names()

  @open_left_door Tiles.tile(:open_left_door)
  @open_right_door Tiles.tile(:open_right_door)
  @open_up_door Tiles.tile(:open_up_door)
  @open_down_door Tiles.tile(:open_down_door)

  @transforms %{
    @open_left_door.atom_value => Objects.object(:door_left),
    @open_right_door.atom_value => Objects.object(:door_right),
    @open_up_door.atom_value => Objects.object(:door_up),
    @open_down_door.atom_value => Objects.object(:door_down),
    @open_left_door.blood_version => Objects.object(:door_left),
    @open_right_door.blood_version => Objects.object(:door_right),
    @open_up_door.blood_version => Objects.object(:door_up),
    @open_down_door.blood_version => Objects.object(:door_down)
  }

  @regions [
    {{:regular, %Region{water_tile: @water}}, _random_weight = 1.5},
    {{:radioactive, %Region{water_tile: @radioactive_water}}, _random_weight = 1.0},
    {{:warm, %Region{water_tile: @warm_water}}, _random_weight = 0.4}
  ]

  @region_names Enum.map(@regions, fn {{name, _}, _} -> name end)

  @type region :: unquote(Types.one_of(@region_names))

  typedstruct module: Land, enforce: true do
    alias Europa.Server.Planet

    field :tiles, map(), default: %{}
    field :min_x, integer()
    field :max_x, integer()
    field :min_y, integer()
    field :max_y, integer()
    field :noise_coef, number()
    field :region, Planet.region()
  end

  typedstruct enforce: true do
    field :land, Land.t()
    field :current_coord, coord()
    field :predefined_cluster_coord, coord()
    field :year, pos_integer()
    field :moves_count, non_neg_integer()
    field :great_red_spots, non_neg_integer()
    field :characters_pid, pid(), enforce: true
  end

  ### PUBLIC INTERFACE ###

  @impl true
  def new(options) do
    year = Keyword.fetch!(options, :year)
    characters_pid = Keyword.fetch!(options, :characters_pid)

    planet =
      %__MODULE__{
        land: generate_land(),
        current_coord: initial_coord(),
        predefined_cluster_coord: initial_coord(),
        year: year,
        moves_count: 0,
        great_red_spots: 0,
        characters_pid: characters_pid
      }

    # Re-generate planet if player spawned on non movable tile
    if player_initial_stand_on_tile(planet) in @movable_tiles do
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
  def readable_tile_name(%Object{name: name}), do: name
  def readable_tile_name(%Npc{}), do: gettext("person")
  def readable_tile_name(tile), do: Map.get(@tiles_readable_names, tile)

  @impl true
  def get_visible_land(%__MODULE__{land: land, current_coord: current_coord} = planet, %DateTime{} = current_datetime) do
    current_hour = current_datetime.hour
    {{x_from, x_to}, {y_from, y_to}} = visible_land_intervals(planet)

    for y <- y_from..y_to do
      for x <- x_from..x_to do
        get_tile(land, {x, y}) |> tile_or_darkness(current_coord, {x, y}, current_hour)
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
  def interact(%__MODULE__{land: land} = planet, %Player{view_direction: view_direction} = player, opts \\ []) do
    target_coord = target_coord(planet, view_direction)
    target_tile = get_tile(land, target_coord)

    do_interact(target_tile, planet, player, opts)
  end

  @impl true
  def tick(%__MODULE__{} = planet, moves_count) when moves_count > 0 do
    planet
    |> maybe_set_new_predefined_cluster_coord()
    |> maybe_switch_region()
    |> increment_moves_count(moves_count)
    |> do_tick(moves_count, [])
  end

  def tick(%__MODULE__{} = planet, _) do
    {:ok, planet, []}
  end

  ### PRIVATE ###

  defp pick_region do
    {region_name, _} = WeightedRandom.take_one(@regions)
    region_name
  end

  defp fetch_region(region_name) do
    {{_, region}, _} = Enum.find(@regions, fn {{name, _}, _} -> name == region_name end)
    region
  end

  defp switch_region(%__MODULE__{} = planet) do
    region = pick_region()
    land = struct!(planet.land, region: region)

    struct!(planet, land: land)
  end

  defp do_interact(%Npc{} = npc, planet, _player, _opts) do
    {:ok, planet, {:talk, npc}}
  end

  defp do_interact(@water, planet, _player, opts) do
    if forced_interaction?(opts) do
      {:ok, planet, {:drink, :radioactive_water}}
    else
      {:ok, planet, {:confirmation, :danger_action}}
    end
  end

  defp do_interact(%Object{transforms_to_tile: tile_name} = object, planet, player, opts) when not is_nil(tile_name) do
    if (object.transform_requirements && forced_interaction?(opts)) || is_nil(object.transform_requirements) do
      target_coord = target_coord(planet, player.view_direction)
      transformed_tile = Object.transform(object)

      updated_land =
        planet.land
        |> change_tile(target_coord, transformed_tile)

      {:ok, struct!(planet, land: updated_land), {:transform, object}}
    else
      {:ok, planet, {:confirmation, {:required_tools, object.transform_requirements}}}
    end
  end

  defp do_interact(tile, planet, player, _opts) do
    object = Map.get(@transforms, tile)

    if object do
      target_coord = target_coord(planet, player.view_direction)
      stand_on_tile = predefined_stand_on_tile(planet.land, target_coord)
      object = Object.stand_on(object, stand_on_tile)

      updated_land =
        planet.land
        |> change_tile(target_coord, object)

      {:ok, struct!(planet, land: updated_land), {:transform, object}}
    else
      {:error, :nothing}
    end
  end

  defp forced_interaction?(opts) do
    Keyword.get(opts, :forced, false)
  end

  defp do_tick(%__MODULE__{} = planet, 0, actions) do
    {:ok, planet, actions}
  end

  defp do_tick(%__MODULE__{} = planet, moves_count, actions) do
    ticks = [
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
    case find_targets(planet, player, weapon) do
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

  defp find_targets(planet, player, %Loot.Weapon{shooting_type: st} = weapon) when st in [:bullet, :burst] do
    shooting_distance = weapon.shooting_distance
    find_direct_targets(planet, player, shooting_distance)
  end

  defp find_targets(planet, player, %Loot.Weapon{shooting_type: :shot} = weapon) do
    shooting_distance = weapon.shooting_distance
    find_shotgun_targets(planet, player, shooting_distance)
  end

  defp find_direct_targets(
         %__MODULE__{land: land, current_coord: {x, y}},
         %Player{view_direction: view_direction},
         shooting_distance
       ) do
    target_coord =
      case view_direction do
        :right -> Enum.map(1..shooting_distance, fn n -> {x + n, y} end)
        :left -> Enum.map(1..shooting_distance, fn n -> {x - n, y} end)
        :up -> Enum.map(1..shooting_distance, fn n -> {x, y - n} end)
        :down -> Enum.map(1..shooting_distance, fn n -> {x, y + n} end)
      end
      |> stop_on_barrier(land)
      |> Enum.find(fn coord ->
        case get_tile(land, coord) do
          %Enemy{} -> true
          %Npc{} -> true
          _ -> false
        end
      end)

    case target_coord do
      nil -> []
      coord -> [coord]
    end
  end

  defp find_shotgun_targets(
         %__MODULE__{land: land, current_coord: {x, y}},
         %Player{view_direction: view_direction},
         shooting_distance
       ) do
    case view_direction do
      :right ->
        shotgun_targets_right(x, y, shooting_distance, land)

      :left ->
        shotgun_targets_left(x, y, shooting_distance, land)

      :up ->
        shotgun_targets_up(x, y, shooting_distance, land)

      :down ->
        shotgun_targets_down(x, y, shooting_distance, land)
    end
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.filter(fn coord ->
      case get_tile(land, coord) do
        %Enemy{} -> true
        %Npc{} -> true
        _ -> false
      end
    end)
  end

  defp shotgun_targets_up(x, y, shooting_distance, land) do
    Enum.map(-shooting_distance..shooting_distance, fn m_end ->
      Enum.map(1..shooting_distance, fn n ->
        m = round(m_end * n / shooting_distance)
        {x + m, y - n}
      end)
      |> stop_on_barrier(land)
    end)
  end

  defp shotgun_targets_down(x, y, shooting_distance, land) do
    Enum.map(-shooting_distance..shooting_distance, fn m_end ->
      Enum.map(1..shooting_distance, fn n ->
        m = round(m_end * n / shooting_distance)
        {x + m, y + n}
      end)
      |> stop_on_barrier(land)
    end)
  end

  defp shotgun_targets_left(x, y, shooting_distance, land) do
    Enum.map(-shooting_distance..shooting_distance, fn m_end ->
      Enum.map(1..shooting_distance, fn n ->
        m = round(m_end * n / shooting_distance)
        {x - n, y + m}
      end)
      |> stop_on_barrier(land)
    end)
  end

  defp shotgun_targets_right(x, y, shooting_distance, land) do
    Enum.map(-shooting_distance..shooting_distance, fn m_end ->
      Enum.map(1..shooting_distance, fn n ->
        m = round(m_end * n / shooting_distance)
        {x + n, y + m}
      end)
      |> stop_on_barrier(land)
    end)
  end

  defp stop_on_barrier(coords, land) do
    closest_barrier_index =
      Enum.find_index(coords, fn coord ->
        case get_tile(land, coord) do
          nil -> false
          %Enemy{} -> true
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

  defp damage_enemy(land, coord, %Npc{} = npc, _damage) do
    {npc, change_tile(land, coord, generate_human_body(npc))}
  end

  defp generate_monster_body(%Enemy{stand_on: %Loot.ItemBox{items: items}} = enemy) do
    monster_body = Loot.generate_item_box(:monster_body, tile_without_blood(enemy.stand_on))
    struct!(monster_body, items: items ++ monster_body.items)
  end

  defp generate_monster_body(%Enemy{} = enemy) do
    Loot.generate_item_box(:monster_body, tile_without_blood(enemy.stand_on))
  end

  defp generate_human_body(%Npc{} = npc) do
    Loot.generate_item_box(:human_body, tile_without_blood(npc.stand_on))
  end

  defp blood_tile(tile) do
    case Tiles.tile_by_atom_value(tile) do
      %Tile{blood_version: blood_tile} when not is_nil(blood_tile) -> blood_tile
      _ -> tile
    end
  end

  defp tile_without_blood(%Loot.ItemBox{type: :monster_body, stand_on: stand_on}) do
    tile_without_blood(stand_on)
  end

  defp tile_without_blood(tile) do
    case Tiles.tile_by_blood_version(tile) do
      %Tiles.Tile{atom_value: atom_value} -> atom_value
      _ -> tile
    end
  end

  defp maybe_switch_region(%__MODULE__{} = planet) do
    if m_to_n?(1, @region_switch_possibility) do
      switch_region(planet)
    else
      planet
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
    if next_to_radioactive_tile?(planet) && m_to_n?(1, 10) do
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
    enemies = get_visible_enemies(planet)

    Enum.reduce(enemies, {planet, []}, fn enemy_coord, {pl, act} ->
      enemy = get_tile(pl.land, enemy_coord)
      {updated_pl, actions} = move_enemy(pl, enemy_coord, enemy)
      {updated_pl, act ++ actions}
    end)
  end

  defp move_enemy(%__MODULE__{current_coord: current_coord} = planet, enemy_coord, enemy) do
    if coords_distance(current_coord, enemy_coord) <= 1 do
      {planet, attack_or_miss(enemy)}
    else
      # Give player chance to run away
      if m_to_n?(@enemy_move_possibility_from, @enemy_move_possibility_to) do
        do_move_enemy(planet, enemy_coord, enemy)
      else
        {planet, [Action.new(enemy, :stay)]}
      end
    end
  end

  defp do_move_enemy(%__MODULE__{} = planet, enemy_coord, enemy) do
    case calculate_enemy_move_coord(planet, enemy_coord, enemy) do
      :stay ->
        {planet, [Action.new(enemy, :stay)]}

      new_enemy_coord ->
        target_tile = get_tile(planet.land, new_enemy_coord)

        neighbor_npc =
          planet.land
          |> get_neighbors(enemy_coord, 1, _with_coord? = true)
          |> Enum.filter(fn
            {_coord, %Npc{}} -> true
            _ -> false
          end)

        updated_land =
          planet.land
          |> change_tile(enemy_coord, enemy.stand_on)
          |> change_tile(new_enemy_coord, struct!(enemy, stand_on: target_tile))

        updated_land =
          Enum.reduce(neighbor_npc, updated_land, fn {npc_coord, npc}, land ->
            land
            |> change_tile(npc_coord, generate_human_body(npc))
          end)

        actions = move_enemy_actions(enemy, neighbor_npc)

        updated_planet = struct!(planet, land: updated_land)
        {updated_planet, actions}
    end
  end

  defp move_enemy_actions(enemy, neighbor_npc) do
    if Enum.empty?(neighbor_npc) do
      [Action.new(enemy, :chasing)]
    else
      Enum.map(neighbor_npc, fn {_coord, npc} -> Action.new({enemy, npc}, :enemy_killed_npc) end)
    end
  end

  defp calculate_enemy_move_coord(%__MODULE__{current_coord: {px, py}} = planet, {ex, ey}, %Enemy{move_distance: md}) do
    x_diff = abs(ex - px)
    y_diff = abs(ey - py)

    md_x = min(x_diff, md)
    md_y = min(y_diff, md)

    move_x =
      Enum.reduce(md_x..1//-1, nil, fn
        md, nil ->
          new_ex = if ex > px, do: ex - md, else: ex + md
          coord = {new_ex, ey}

          if movable_tile?(planet.land, coord) do
            coord
          else
            nil
          end

        _, coord ->
          coord
      end)

    move_y =
      Enum.reduce(md_y..1//-1, nil, fn
        md, nil ->
          new_ey = if ey > py, do: ey - md, else: ey + md
          coord = {ex, new_ey}

          if movable_tile?(planet.land, coord) do
            coord
          else
            nil
          end

        _, coord ->
          coord
      end)

    desperate_moves =
      [{ex + 1, ey}, {ex - 1, ey}, {ex, ey + 1}, {ex, ey - 1}]
      |> Enum.filter(fn coord -> movable_tile?(planet.land, coord) end)

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

  defp movable_tile?(land, coord) do
    case get_tile(land, coord) do
      tile when tile in @movable_tiles ->
        true

      %Loot.ItemBox{type: type} when type in [:monster_body, :bunch] ->
        true

      _ ->
        false
    end
  end

  defp get_visible_enemies(%__MODULE__{current_coord: current_coord, land: land}) do
    land.tiles
    |> Enum.filter(fn {enemy_coord, tile} ->
      case tile do
        %Enemy{} ->
          enemy_visible?(current_coord, enemy_coord)

        _ ->
          false
      end
    end)
    |> Enum.map(fn {enemy_coord, _} -> enemy_coord end)
  end

  defp enemy_visible?(coord1, coord2) do
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

  defp maybe_delete_empty_item_box(%Loot.ItemBox{type: :bunch, items: [], stand_on: stand_on}), do: stand_on
  defp maybe_delete_empty_item_box(item_box), do: item_box

  defp do_move(planet, tile, target_coord, direction, player_stand_on) do
    updated_land =
      planet.land
      |> maybe_make_path(planet.current_coord, player_stand_on)
      |> change_tile(target_coord, @player)

    updated_planet =
      planet
      |> struct!(land: updated_land, current_coord: target_coord)
      |> maybe_generate_tiles(direction)

    move_cost = move_cost(tile)

    {:moved, updated_planet, move_cost, tile}
  end

  defp attack_with_melee_weapon_or_stay(planet, player, target_coord, %Enemy{} = enemy) do
    {damage, move_cost} =
      case PlayerManager.get_equiped_melee_weapon(player) do
        {:ok, %Loot.MeleeWeapon{damage: damage, hit_cost: hit_cost}} -> {damage, hit_cost}
        _ -> {1, 1}
      end

    if player.accuracy >= @max_accuracy || m_to_n?(player.accuracy, @max_accuracy) do
      {enemy, updated_land} = damage_enemy(planet.land, target_coord, enemy, damage)
      {:attack, struct!(planet, land: updated_land), [{enemy, damage}], move_cost}
    else
      {:attack, planet, [], move_cost}
    end
  end

  defp attack_with_melee_weapon_or_stay(_planet, _player, _target_coord, tile) do
    {:stay, tile}
  end

  defp maybe_make_path(land, current_coord, @snow) do
    change_tile(land, current_coord, @path)
  end

  defp maybe_make_path(land, current_coord, @snow_blood) do
    change_tile(land, current_coord, @path_blood)
  end

  defp maybe_make_path(land, current_coord, tile) do
    change_tile(land, current_coord, tile)
  end

  defp change_tile(land, {_x, _y} = coord, new_tile) do
    tiles = Map.put(land.tiles, coord, new_tile)
    struct!(land, tiles: tiles)
  end

  defp move_cost(%Loot.ItemBox{type: type, stand_on: tile}) when type in [:monster_body, :bunch] do
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

    %Land{
      min_x: 0,
      max_x: max_x,
      min_y: 0,
      max_y: max_y,
      noise_coef: noise_coef,
      region: :regular
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
    region = fetch_region(land.region)
    noise_coef = land.noise_coef
    noise = PerlinNoise.noise(x * 0.1 + noise_coef, y * 0.1 + noise_coef)

    cond do
      noise < -0.4 ->
        # do not stack diff water tiles
        neighbor_water_type(land, {x, y}) || region.water_tile

      noise >= -0.5 && noise <= 0.2 ->
        @ice

      true ->
        @snow
    end
  end

  defp neighbor_water_type(land, coord) do
    frequencies =
      land
      |> get_neighbors(coord, 4)
      |> Enum.filter(fn tile -> tile in @water_tiles end)
      |> Enum.frequencies()

    if Enum.empty?(frequencies) do
      nil
    else
      frequencies
      |> Enum.max_by(fn {_tile, count} -> count end)
      |> elem(0)
    end
  end

  defp generate_tile(%__MODULE__{} = planet, {x, y} = coord) do
    tile_by_perlin_noise(x, y, planet.land)
    |> tile_or_enemy(planet, coord)
    |> tile_or_loot()
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

  defp tile_or_loot(tile) do
    if m_to_n?(1, @base_loot_generate_possibility) && tile in @movable_tiles do
      Loot.generate_item_box()
      |> Loot.ItemBox.stand_on(tile)
    else
      tile
    end
  end

  defp tile_or_enemy(tile, %__MODULE__{} = planet, {_x, _y} = coord) do
    {m, n} = generate_enemy_possibility(planet, coord)

    if m_to_n?(m, n) && tile in @movable_tiles do
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

  defp generate_enemy_possibility(%__MODULE__{} = planet, {_x, _y} = coord) do
    around_water_count =
      planet.land
      |> get_neighbors(coord, 3)
      |> Enum.count(fn tile -> tile == @water end)

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

  defp tile_or_darkness(tile, current_coord, tile_coord, current_hour) do
    max_view_distance = @view_distance

    view_distance =
      cond do
        current_hour <= 12 -> @min_view_distance + (max_view_distance - @min_view_distance) * current_hour / 12
        current_hour <= 18 -> max_view_distance
        true -> max_view_distance - (max_view_distance - @min_view_distance) * (current_hour - 18) / 6
      end

    if view_distance < max_view_distance && coords_distance(current_coord, tile_coord) > view_distance do
      @darkness
    else
      tile
    end
  end

  # TODO: figure out how to test this
  # coveralls-ignore-start

  defp maybe_generate_predefined(land, direction, characters_pid, planet) do
    in_predefined_cluster? = in_predefined_cluster?(planet.current_coord, planet.predefined_cluster_coord)

    {m, n} =
      if in_predefined_cluster? do
        {1, 10}
      else
        {1, 50}
      end

    if m_to_n?(m, n) do
      template = Predefined.generate_random()

      coord_fun = generate_template_coord_fun(land, direction, planet.current_coord, in_predefined_cluster?)
      new_tiles = generate_tiles_for_template(template, coord_fun, land, characters_pid, planet.year)

      is_all_tiles_movable =
        Enum.all?(new_tiles, fn {{x, y}, _} ->
          get_tile(land, {x, y}) |> is_nil() && tile_by_perlin_noise(x, y, land) in @movable_tiles
        end)

      if is_all_tiles_movable do
        struct!(land, tiles: Map.merge(land.tiles, new_tiles))
      else
        land
      end
    else
      land
    end
  end

  defp in_predefined_cluster?(current_coord, cluster_coord) do
    distance = coords_distance(current_coord, cluster_coord)
    distance in 1..@predefined_cluster_distance
  end

  defp coords_distance({x1, y1}, {x2, y2}) do
    abs(x1 - x2) + abs(y1 - y2)
  end

  defp generate_template_coord_fun(land, direction, {current_x, current_y}, in_predefined_cluster?) do
    padding =
      fn ->
        if in_predefined_cluster? do
          Enum.random(-10..10)
        else
          Enum.random(-30..30)
        end
      end

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
    |> Enum.filter(fn {_, tile} -> tile != :skip end)
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
