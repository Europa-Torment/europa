defmodule Europa.Server.Planet.Tiles do
  use TypedStruct
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Planet.Tiles.Tile

  @tiles %{
    snow: %Tile{
      atom_value: :s,
      blood_version: :sb,
      readable_name: gettext("snow"),
      move_cost: 2,
      movable?: true,
      image_name: "snow"
    },
    path: %Tile{
      atom_value: :p,
      blood_version: :pb,
      readable_name: gettext("path"),
      move_cost: 1,
      movable?: true,
      image_name: "path"
    },
    ice: %Tile{
      atom_value: :i,
      blood_version: :ib,
      readable_name: gettext("ice"),
      move_cost: 1,
      movable?: true,
      image_name: "ice"
    },
    water: %Tile{
      atom_value: :w,
      blood_version: nil,
      readable_name: gettext("water"),
      move_cost: nil,
      movable?: false,
      image_name: "water",
      gif_tile?: true
    },
    wall: %Tile{
      atom_value: :wl,
      blood_version: nil,
      readable_name: gettext("wall"),
      move_cost: nil,
      movable?: false,
      high?: true,
      image_name: "wall"
    },
    floor: %Tile{
      atom_value: :fl,
      blood_version: :flb,
      readable_name: gettext("floor"),
      move_cost: 1,
      movable?: true,
      image_name: "floor"
    }
  }

  @spec tiles() :: %{required(atom()) => Tile.t()}
  def tiles, do: @tiles

  @spec tiles_values() :: atom()
  def tiles_values do
    Enum.reduce(@tiles, [], fn {_, tile}, acc ->
      acc ++ [tile.atom_value, tile.blood_version]
    end)
    |> Enum.filter(fn tile -> not is_nil(tile) end)
  end

  @spec movable_tiles() :: list(atom())
  def movable_tiles do
    Enum.reduce(@tiles, [], fn {_, tile}, acc ->
      if tile.movable? do
        acc ++ [tile.atom_value, tile.blood_version]
      else
        acc
      end
    end)
    |> Enum.filter(fn tile -> not is_nil(tile) end)
  end

  @spec gif_tiles() :: list(atom())
  def gif_tiles do
    Enum.reduce(@tiles, [], fn {_, tile}, acc ->
      if tile.gif_tile? do
        acc ++ [tile.atom_value, tile.blood_version]
      else
        acc
      end
    end)
    |> Enum.filter(fn tile -> not is_nil(tile) end)
  end

  @spec high_tiles() :: list(atom())
  def high_tiles do
    Enum.reduce(@tiles, [], fn {_, tile}, acc ->
      if tile.high? do
        acc ++ [tile.atom_value, tile.blood_version]
      else
        acc
      end
    end)
    |> Enum.filter(fn tile -> not is_nil(tile) end)
  end

  @spec move_costs() :: %{required(atom()) => pos_integer()}
  def move_costs do
    Enum.reduce(@tiles, [], fn {_, tile}, acc ->
      if tile.movable? do
        acc ++ [{tile.atom_value, tile.move_cost}, {tile.blood_version, tile.move_cost}]
      else
        acc
      end
    end)
    |> Enum.filter(fn {_, move_cost} -> not is_nil(move_cost) end)
    |> Enum.into(%{})
  end

  @spec readable_names() :: %{required(atom()) => String.t()}
  def readable_names do
    Enum.reduce(@tiles, [], fn {_, tile}, acc ->
      acc ++
        [{tile.atom_value, tile.readable_name}, {tile.blood_version, gettext("bloody") <> " " <> tile.readable_name}]
    end)
    |> Enum.filter(fn {tile, _} -> not is_nil(tile) end)
    |> Enum.into(%{})
  end

  @spec image_names() :: %{required(atom()) => String.t()}
  def image_names do
    Enum.reduce(@tiles, [], fn {_, tile}, acc ->
      acc ++ [{tile.atom_value, tile.image_name}, {tile.blood_version, "blood_" <> tile.image_name}]
    end)
    |> Enum.filter(fn {tile, _} -> not is_nil(tile) end)
    |> Enum.into(%{})
  end

  @spec tile(atom()) :: Tile.t()
  def tile(name), do: Map.fetch!(@tiles, name)

  @spec tile_by_atom_value(atom()) :: Tile.t() | nil
  def tile_by_atom_value(atom_value) do
    case Enum.find(@tiles, fn {_, tile} -> tile.atom_value == atom_value end) do
      {_, tile} -> tile
      _ -> nil
    end
  end

  @spec tile_by_blood_version(atom()) :: Tile.t() | nil
  def tile_by_blood_version(blood_version) do
    case Enum.find(@tiles, fn {_, tile} -> tile.blood_version == blood_version end) do
      {_, tile} -> tile
      _ -> nil
    end
  end
end
