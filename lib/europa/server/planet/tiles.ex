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
    ice_cracked: %Tile{
      atom_value: :ic,
      blood_version: nil,
      readable_name: gettext("cracked ice"),
      move_cost: nil,
      movable?: false,
      image_name: "ice_cracked",
      gif_tile?: true
    },
    thin_ice: %Tile{
      atom_value: :ti,
      blood_version: :tib,
      readable_name: gettext("thin ice"),
      move_cost: 1,
      movable?: true,
      image_name: "thin_ice",
      gif_tile?: true,
      changes_to: :thin_ice_cracked,
      change_possibility: 30
    },
    thin_ice_cracked: %Tile{
      atom_value: :tic,
      blood_version: nil,
      readable_name: gettext("cracked thin ice"),
      move_cost: nil,
      movable?: false,
      image_name: "thin_ice_cracked",
      gif_tile?: true,
      lethal?: true,
      lethal_event: :ice_cracked
    },
    ice_spikes: %Tile{
      atom_value: :is,
      blood_version: nil,
      readable_name: gettext("ice spikes"),
      move_cost: nil,
      movable?: false,
      image_name: "ice_spikes",
      gif_tile?: false
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
    radioactive_water: %Tile{
      atom_value: :rw,
      blood_version: nil,
      readable_name: gettext("radioactive water"),
      move_cost: nil,
      movable?: false,
      image_name: "radioactive_water",
      gif_tile?: true,
      radioactive?: true
    },
    warm_water: %Tile{
      atom_value: :ww,
      blood_version: nil,
      readable_name: gettext("bubbling water"),
      move_cost: nil,
      movable?: false,
      image_name: "warm_water",
      gif_tile?: true,
      warm?: true
    },
    floor: %Tile{
      atom_value: :fl,
      blood_version: :flb,
      readable_name: gettext("floor"),
      move_cost: 1,
      movable?: true,
      warm?: true,
      image_name: "floor"
    },
    bloody_floor: %Tile{
      atom_value: :bfl,
      blood_version: :bflb,
      readable_name: gettext("bloody floor"),
      move_cost: 1,
      movable?: true,
      warm?: true,
      image_name: "bloody_floor"
    },
    litter_floor: %Tile{
      atom_value: :lfl,
      blood_version: :lflb,
      readable_name: gettext("floor with litter"),
      move_cost: 1,
      movable?: true,
      warm?: true,
      image_name: "litter_floor"
    },
    open_left_door: %Tile{
      atom_value: :old,
      blood_version: :oldb,
      readable_name: gettext("door"),
      move_cost: 1,
      movable?: true,
      warm?: true,
      image_name: "door_open_left"
    },
    open_right_door: %Tile{
      atom_value: :ord,
      blood_version: :ordb,
      readable_name: gettext("door"),
      move_cost: 1,
      movable?: true,
      warm?: true,
      image_name: "door_open_right"
    },
    open_up_door: %Tile{
      atom_value: :oud,
      blood_version: :oudb,
      readable_name: gettext("door"),
      move_cost: 1,
      movable?: true,
      warm?: true,
      image_name: "door_open_up"
    },
    open_down_door: %Tile{
      atom_value: :odd,
      blood_version: :oddb,
      readable_name: gettext("door"),
      move_cost: 1,
      movable?: true,
      warm?: true,
      image_name: "door_open_down"
    },
    darkness: %Tile{
      atom_value: :d,
      blood_version: nil,
      readable_name: gettext("darkness"),
      move_cost: nil,
      movable?: false,
      image_name: "darkness",
      gif_tile?: false
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

  @spec warm_tiles() :: list(atom())
  def warm_tiles do
    Enum.reduce(@tiles, [], fn {_, tile}, acc ->
      if tile.warm? do
        acc ++ [tile.atom_value, tile.blood_version]
      else
        acc
      end
    end)
    |> Enum.filter(fn tile -> not is_nil(tile) end)
  end

  @spec radioactive_tiles() :: list(atom())
  def radioactive_tiles do
    Enum.reduce(@tiles, [], fn {_, tile}, acc ->
      if tile.radioactive? do
        acc ++ [tile.atom_value, tile.blood_version]
      else
        acc
      end
    end)
    |> Enum.filter(fn tile -> not is_nil(tile) end)
  end

  @spec lethal_tiles() :: list(atom())
  def lethal_tiles do
    Enum.reduce(@tiles, [], fn {_, tile}, acc ->
      if tile.lethal? do
        acc ++ [tile.atom_value, tile.blood_version]
      else
        acc
      end
    end)
    |> Enum.filter(fn tile -> not is_nil(tile) end)
  end

  @spec changeable_tiles() :: list(atom())
  def changeable_tiles do
    Enum.reduce(@tiles, [], fn {_, tile}, acc ->
      if tile.changes_to && tile.change_possibility do
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
