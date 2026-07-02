defmodule Europa.Server.Planet.Predefined do
  @moduledoc """
  Predefined planet sectors generator.
  """

  alias Europa.Server.Planet
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Planet.Tiles.Objects
  alias Europa.Server.Planet.Tiles.Objects.Object
  alias Europa.Server.Enemy
  alias Europa.Server.Loot
  alias Europa.Server.Loot.Tool
  alias Europa.Server.Planet.Predefined.Utils.FilesReader

  alias Europa.Tools.Types

  import Europa.Tools.Conf
  import Europa.Tools.Randomizer

  @tempaltes_path fetch_config!([__MODULE__, :templates_path])

  @categories %{
    building: %{dir: "/buildings", weight: 1.0},
    situation: %{dir: "/situations", weight: 0.4}
  }

  @templates FilesReader.parse_files(@tempaltes_path, @categories)

  @futniture_item_box_types Loot.furniture_item_box_types()

  @floor Tiles.tile(:floor).atom_value
  @litter_floor Tiles.tile(:litter_floor).atom_value
  @bloody_floor Tiles.tile(:bloody_floor).atom_value

  @dirty_floors [@litter_floor, @bloody_floor]

  @building_enemy_generate_possibility fetch_config!([__MODULE__, :building, :enemy_generate_possibility])
  @building_loot_generate_possibility fetch_config!([__MODULE__, :building, :loot_generate_possibility])
  @locked_door_possibility fetch_config!([__MODULE__, :building, :locked_door_possibility])

  @npc_generate_possibility fetch_config!([Planet, :npc_generate_possibility])

  @skip :skip

  @type category() :: unquote(@categories |> Map.keys() |> Types.one_of())
  @type npc :: {:npc, Tiles.Tile.t() | nil}
  @type template() :: list(list(Tiles.Tile.t() | :skip | npc()))

  @spec generate_random() :: template()
  def generate_random do
    @categories
    |> Enum.map(fn {category, %{weight: weight}} -> {category, weight} end)
    |> WeightedRandom.take_one()
    |> generate()
  end

  @spec generate(category()) :: template()
  def generate(category) do
    @templates
    |> Map.fetch!(category)
    |> Enum.random()
    |> String.split("\n")
    |> Enum.map(fn row ->
      row
      |> String.graphemes()
      |> Enum.filter(fn e -> String.trim(e) != "" end)
      |> Enum.map(fn e -> elem_to_tile(category, e) end)
    end)
    |> Enum.filter(fn r -> r != [] end)
    |> add_borders()
  end

  # common
  defp elem_to_tile(_, "*"), do: @skip

  # buildings
  defp elem_to_tile(:building, "l"), do: Objects.object(:wall_left)
  defp elem_to_tile(:building, "r"), do: Objects.object(:wall_right)
  defp elem_to_tile(:building, "u"), do: Objects.object(:wall_up)
  defp elem_to_tile(:building, "d"), do: Objects.object(:wall_down)
  defp elem_to_tile(:building, "I"), do: Objects.object(:wall_vertical_inside)
  defp elem_to_tile(:building, "i"), do: Objects.object(:wall_left_up)
  defp elem_to_tile(:building, "!"), do: Objects.object(:wall_left_down)
  defp elem_to_tile(:building, "^"), do: Objects.object(:wall_right_up)
  defp elem_to_tile(:building, "v"), do: Objects.object(:wall_right_down)
  defp elem_to_tile(:building, "("), do: Objects.object(:door_left) |> maybe_lock_door()
  defp elem_to_tile(:building, ")"), do: Objects.object(:door_right) |> maybe_lock_door()
  defp elem_to_tile(:building, "1"), do: Objects.object(:door_up) |> maybe_lock_door()
  defp elem_to_tile(:building, "2"), do: Objects.object(:door_down) |> maybe_lock_door()

  defp elem_to_tile(:building, "f") do
    cond do
      m_to_n?(1, @building_enemy_generate_possibility) ->
        Enemy.generate_enemy()
        |> Enemy.stand_on(@floor)

      m_to_n?(1, 20) ->
        Enum.random(@dirty_floors)

      true ->
        @floor
    end
  end

  defp elem_to_tile(:building, "N") do
    if m_to_n?(1, @npc_generate_possibility) do
      {:npc, @floor}
    else
      @floor
    end
  end

  defp elem_to_tile(:building, "L") do
    if m_to_n?(1, @building_loot_generate_possibility) do
      type = Enum.random(@futniture_item_box_types)
      item_box = Loot.generate_item_box(type, @floor)

      item_box
    else
      @floor
    end
  end

  defp elem_to_tile(:building, "c") do
    if m_to_n?(1, 10) do
      Loot.generate_item_box(:human_body, @floor)
    else
      @floor
    end
  end

  # situations
  defp elem_to_tile(:situation, "e"), do: Enemy.generate_enemy()
  defp elem_to_tile(:situation, "c"), do: Loot.generate_item_box(:human_body)
  defp elem_to_tile(:situation, "m"), do: Loot.generate_item_box(:monster_body)
  defp elem_to_tile(:situation, "b"), do: Loot.generate_item_box(:box)
  defp elem_to_tile(:situation, "f"), do: Objects.object(:bonefire)

  defp elem_to_tile(:situation, "N") do
    if m_to_n?(1, @npc_generate_possibility) do
      {:npc, nil}
    else
      @skip
    end
  end

  defp elem_to_tile(:situation, "s") do
    crashed_shuttle = Loot.generate_item_box(:crashed_shuttle)
    Enum.random([crashed_shuttle, Objects.object(:fire_shuttle)])
  end

  # Helpers

  defp add_borders([]), do: []

  defp add_borders(template) when is_list(template) do
    inner = Enum.map(template, fn row -> [@skip | row ++ [@skip]] end)
    first_len = List.first(template) |> length()
    last_len = List.last(template) |> length()

    top_border = List.duplicate(@skip, first_len)
    bottom_border = List.duplicate(@skip, last_len)

    [top_border | inner ++ [bottom_border]]
  end

  defp maybe_lock_door(%Object{} = door) do
    if m_to_n?(1, @locked_door_possibility) do
      key = Tool.generate_key()
      Object.set_transform_requirements(door, [key])
    else
      door
    end
  end
end
