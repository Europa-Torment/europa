defmodule Europa.Support.PlanetLandConverter do
  alias Europa.Server.Planet

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
      noise_coef: 0.1,
      region_noise_coef: 0.1,
      region_x_offset: 0,
      region_y_offset: 0
    }
  end

  @doc """
  Converts planet land to matrix (list of lists).
  """
  @spec to_matrix(Planet.Land.t()) :: list(list(Planet.tile()))
  def to_matrix(%Planet.Land{} = land) do
    {{max_x, _}, _} = Enum.max_by(land.tiles, fn {{x, _}, _} -> x end)
    {{max_y, _}, _} = Enum.max_by(land.tiles, fn {{_, y}, _} -> y end)

    for y <- 0..max_y do
      for x <- 0..max_x do
        Map.get(land.tiles, {x, y})
      end
    end
  end
end
