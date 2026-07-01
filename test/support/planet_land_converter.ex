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
      min_y: 0,
      max_y: Enum.count(matrix) - 1,
      min_x: 0,
      max_x: Enum.count(List.first(matrix)) - 1,
      noise_coef: 0.1,
      region: :regular
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
