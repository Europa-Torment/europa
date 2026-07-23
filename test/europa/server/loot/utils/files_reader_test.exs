defmodule Europa.Server.Loot.Utils.FilesReaderTest do
  use Europa.DataCase, async: true

  alias Europa.Server.Loot.Utils.FilesReader
  alias Europa.Server.Loot.ItemBox

  @item_filenames %{
    weapon: "weapons.json",
    ammo: "ammo.json"
  }

  @item_boxes_filename "item_boxes.json"

  describe "parse_items_files/1" do
    test "returns parsed files as map" do
      result = FilesReader.parse_items_files(@item_filenames)
      assert is_map(result)
      assert Enum.all?(result, fn {category, content} -> is_atom(category) && is_list(content) end)
    end
  end

  describe "parse_item_boxes_file/1" do
    test "returns parsed file as list" do
      result = FilesReader.parse_item_boxes_file(@item_boxes_filename)

      assert is_list(result)

      assert Enum.all?(result, fn {attrs, random_weight} -> is_map(attrs) && is_number(random_weight) end)
    end

    test "all item boxes converts to ItemBox struct" do
      result = FilesReader.parse_item_boxes_file(@item_boxes_filename)

      assert Enum.all?(result, fn {attrs, _} ->
               %ItemBox{} = ItemBox.from_map(attrs)
             end)
    end
  end
end
