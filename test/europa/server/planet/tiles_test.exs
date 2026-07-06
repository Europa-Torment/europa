defmodule Europa.Server.Planet.TilesTest do
  use Europa.DataCase, async: true

  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Planet.Tiles.Tile

  describe "tiles/0" do
    test "returns list of tiles" do
      assert Tiles.tiles() |> Enum.all?(fn {name, tile} -> is_atom(name) && tile?(tile) end)
    end
  end

  describe "movable_tiles/0" do
    test "returns list of movable tiles atom values" do
      assert Tiles.movable_tiles() |> Enum.all?(&movable_tile?/1)
    end
  end

  describe "gif_tiles/0" do
    test "returns list of gif tiles atom values" do
      assert Tiles.gif_tiles() |> Enum.all?(&gif_tile?/1)
    end
  end

  describe "high_tiles/0" do
    test "returns list of high tiles atom values" do
      assert Tiles.high_tiles() |> Enum.all?(&high_tile?/1)
    end
  end

  describe "warm_tiles/0" do
    test "returns list of warm tiles atom values" do
      assert Tiles.warm_tiles() |> Enum.all?(&warm_tile?/1)
    end
  end

  describe "radioactive_tiles/0" do
    test "returns list of radioactive tiles atom values" do
      assert Tiles.radioactive_tiles() |> Enum.all?(&radioactive_tile?/1)
    end
  end

  describe "lethal_tiles/0" do
    test "returns list of lethal tiles atom values" do
      assert Tiles.lethal_tiles() |> Enum.all?(&lethal_tile?/1)
    end
  end

  describe "changeable_tiles/0" do
    test "returns list of changeable tiles atom values" do
      assert Tiles.changeable_tiles() |> Enum.all?(&changeable_tile?/1)
    end
  end

  describe "high_loot_possibility_tiles/0" do
    test "returns list of atom values of tiles with high loot possibility" do
      assert Tiles.high_loot_possibility_tiles() |> Enum.all?(&high_loot_possibility_tile?/1)
    end
  end

  describe "move_cots/0" do
    test "returns tiles move costs" do
      assert Tiles.move_costs() |> valid_move_costs?()
    end
  end

  describe "readable_names/0" do
    test "returns tiles readable names" do
      assert Tiles.readable_names() |> valid_readable_names?()
    end
  end

  describe "image_names/0" do
    test "returns tiles image names" do
      assert Tiles.image_names() |> valid_image_names?()
    end
  end

  describe "tile/1" do
    test "returns tile by name" do
      assert %Tile{} = Tiles.tile(:snow)
    end
  end

  describe "tile_by_atom_value/1" do
    test "returns tile by atom value" do
      assert %Tile{atom_value: :s} = Tiles.tile_by_atom_value(:s)
    end
  end

  describe "tile_by_blood_version/1" do
    test "returns tile by blood version" do
      assert %Tile{atom_value: :s} = Tiles.tile_by_blood_version(:sb)
    end
  end

  defp tile?(%Tile{}), do: true
  defp tile?(_), do: false

  defp valid_move_costs?(move_costs) when is_map(move_costs) do
    Enum.all?(move_costs, fn {tile, cost} ->
      tile = from_atom_value(tile)
      tile?(tile) && tile.move_cost == cost
    end)
  end

  defp valid_move_costs?(_), do: false

  defp valid_readable_names?(readable_names) when is_map(readable_names) do
    Enum.all?(readable_names, fn {tile, name} ->
      tile = from_atom_value(tile)
      tile?(tile) && name in [tile.readable_name, "bloody #{tile.readable_name}"]
    end)
  end

  defp valid_readable_names?(_), do: false

  defp valid_image_names?(image_names) when is_map(image_names) do
    Enum.all?(image_names, fn {tile, image_name} ->
      tile = from_atom_value(tile)
      tile?(tile) && image_name in [tile.image_name, "blood_#{tile.image_name}"]
    end)
  end

  defp valid_image_names?(_), do: false

  defp movable_tile?(tile) do
    tile = from_atom_value(tile)
    tile.movable?
  end

  defp gif_tile?(tile) do
    tile = from_atom_value(tile)
    tile.gif_tile?
  end

  defp high_tile?(tile) do
    tile = from_atom_value(tile)
    tile.high?
  end

  defp warm_tile?(tile) do
    tile = from_atom_value(tile)
    tile.warm?
  end

  defp radioactive_tile?(tile) do
    tile = from_atom_value(tile)
    tile.radioactive?
  end

  defp lethal_tile?(tile) do
    tile = from_atom_value(tile)
    tile.lethal?
  end

  defp changeable_tile?(tile) do
    tile = from_atom_value(tile)
    tile.changes_to && tile.change_possibility
  end

  defp high_loot_possibility_tile?(tile) do
    tile = from_atom_value(tile)
    tile.high_loot_possibility?
  end

  defp from_atom_value(tile) do
    Tiles.tile_by_atom_value(tile) || Tiles.tile_by_blood_version(tile)
  end
end
