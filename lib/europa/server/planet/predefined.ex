defmodule Europa.Server.Planet.Predefined do
  @moduledoc """
  Predefined planet sectors generator.
  """

  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Planet.Tiles.Object
  alias Europa.Server.Enemy
  alias Europa.Server.Loot

  alias Europa.Tools.FilesCache
  alias Europa.Tools.Types

  import Europa.Tools.Conf
  import Europa.Tools.Randomizer

  @default_templates_path "/planet"

  @categories %{
    building: %{dir: "/buildings", weight: 0.3},
    situation: %{dir: "/situations", weight: 0.7}
  }

  @floor Tiles.tile(:floor).atom_value

  @wall_horizontal %Object{name: "wall", image_name: "wall_horizontal", high?: true}
  @wall_right %Object{name: "wall", image_name: "wall_right", high?: true}
  @wall_left %Object{name: "wall", image_name: "wall_left", high?: true}
  @wall_vertical_inside %Object{name: "wall", image_name: "wall_vertical_inside", high?: true, stand_on: @floor}

  @bonefire %Object{name: "bonefire", image_name: "bonefire", warm?: true}

  @building_enemy_generate_possibility fetch_config!([__MODULE__, :building, :enemy_generate_possibility])
  @building_loot_generate_possibility fetch_config!([__MODULE__, :building, :loot_generate_possibility])

  @type category() :: unquote(@categories |> Map.keys() |> Types.one_of())
  @type template() :: list(Tiles.Tile.t() | :skip)

  @spec generate_random() :: template()
  def generate_random do
    @categories
    |> Enum.map(fn {category, %{weight: weight}} -> {category, weight} end)
    |> WeightedRandom.take_one()
    |> generate()
  end

  @spec generate(category()) :: template()
  def generate(category) do
    category
    |> parse_random_file()
    |> String.split("\n")
    |> Enum.map(fn row ->
      row
      |> String.graphemes()
      |> Enum.filter(fn e -> String.trim(e) != "" end)
      |> Enum.map(fn e -> elem_to_tile(category, e) end)
    end)
    |> Enum.filter(fn r -> r != [] end)
  end

  # common
  defp elem_to_tile(_, "*"), do: :skip

  # buildings
  defp elem_to_tile(:building, "l"), do: @wall_left
  defp elem_to_tile(:building, "r"), do: @wall_right
  defp elem_to_tile(:building, "h"), do: @wall_horizontal
  defp elem_to_tile(:building, "i"), do: @wall_vertical_inside

  defp elem_to_tile(:building, "f") do
    if m_to_n?(1, @building_enemy_generate_possibility) do
      Enemy.generate_enemy()
      |> Enemy.stand_on(@floor)
    else
      @floor
    end
  end

  defp elem_to_tile(:building, "L") do
    item_box = Loot.generate_item_box(:box, @floor)

    if m_to_n?(1, @building_loot_generate_possibility) do
      item_box
    else
      @floor
    end
  end

  # situations
  defp elem_to_tile(:situation, "e"), do: Enemy.generate_enemy()
  defp elem_to_tile(:situation, "c"), do: Loot.generate_item_box(:human_body)
  defp elem_to_tile(:situation, "s"), do: Loot.generate_item_box(:crashed_shuttle)
  defp elem_to_tile(:situation, "b"), do: Loot.generate_item_box(:box)
  defp elem_to_tile(:situation, "f"), do: @bonefire

  defp parse_random_file(category) do
    priv_dir = :code.priv_dir(:europa)
    path = Path.join([priv_dir, templates_path(), Map.fetch!(@categories, category) |> Map.fetch!(:dir)])

    filename =
      path
      |> File.ls!()
      |> Enum.random()

    path = Path.join(path, filename)

    case FilesCache.get(path) do
      {:ok, cached_file} when not is_nil(cached_file) ->
        cached_file

      _ ->
        do_parse_file(path)
    end
  end

  defp do_parse_file(path) do
    path
    |> File.read!()
    |> tap(fn file_content -> FilesCache.put(path, file_content) end)
  end

  defp templates_path do
    get_config(__MODULE__, []) |> Keyword.get(:templates_path, @default_templates_path)
  end
end
