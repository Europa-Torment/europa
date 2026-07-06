defmodule Europa.Support.PlanetLandConverter do
  alias Europa.Server.Planet
  alias Europa.Server.Planet.Region
  alias Europa.Server.Planet.Tiles

  @ice Tiles.tile(:ice).atom_value
  @snow Tiles.tile(:snow).atom_value
  @water Tiles.tile(:water).atom_value

  @doc """
  Converts matrix (list of lists) to planet land.
  Useful for tests with manual land declaration.
  """
  @spec from_matrix(list(list(Planet.tile()))) :: Planet.Land.t()
  def from_matrix(matrix) when is_list(matrix) do
    tiles =
      matrix
      |> Enum.with_index()
      |> Enum.flat_map(fn {row, y} ->
        row
        |> Enum.with_index()
        |> Enum.map(fn {value, x} ->
          {{x, y}, value}
        end)
      end)
      |> Map.new()

    %Planet.Land{
      tiles: tiles,
      min_y: 0,
      max_y: Enum.count(matrix) - 1,
      min_x: 0,
      max_x: Enum.count(List.first(matrix)) - 1,
      regions: [%Region{snow_tile: @snow, ice_tile: @ice, water_tile: @water}],
      noise_coef: 0.1,
      region_noise_coef: 0.1
    }
  end

  @doc """
  Converts planet land to matrix (list of lists).
  """
  @spec to_matrix(Planet.Land.t()) :: list(list(Planet.tile()))
  def to_matrix(%Planet.Land{} = land) do
    for y <- land.min_y..land.max_y do
      for x <- land.min_x..land.max_x do
        Map.get(land.tiles, {x, y})
      end
    end
  end
end
