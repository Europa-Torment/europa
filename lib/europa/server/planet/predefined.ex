defmodule Europa.Server.Planet.Predefined do
  @moduledoc """
  Predefined planet sectors generator.
  """

  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Enemy
  alias Europa.Server.Loot

  alias Europa.Tools.FilesCache
  alias Europa.Tools.Types

  import Europa.Tools.Conf

  @default_templates_path "/planet"

  @categories %{
    building: %{dir: "/buildings", weight: 0.08},
    situation: %{dir: "/situations", weight: 0.3}
  }

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
  defp elem_to_tile(:building, "w"), do: Tiles.tile(:wall).atom_value
  defp elem_to_tile(:building, "f"), do: Tiles.tile(:floor).atom_value

  # situations
  defp elem_to_tile(:situation, "e"), do: Enemy.generate_enemy()
  defp elem_to_tile(:situation, "c"), do: Loot.generate_item_box(:human_body)
  defp elem_to_tile(:situation, "s"), do: Loot.generate_item_box(:crashed_shuttle)
  defp elem_to_tile(:situation, "b"), do: Loot.generate_item_box(:box)

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
