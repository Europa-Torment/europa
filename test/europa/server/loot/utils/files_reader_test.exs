defmodule Europa.Server.Loot.Utils.FilesReaderTest do
  use Europa.DataCase, async: true

  alias Europa.Server.Loot.Utils.FilesReader

  @filenames %{
    weapon: "weapons.json",
    ammo: "ammo.json"
  }

  describe "parse_files/1" do
    test "returns parsed files as map" do
      result = FilesReader.parse_files(@filenames)
      assert is_map(result)
      assert Enum.all?(result, fn {category, content} -> is_atom(category) && is_list(content) end)
    end
  end
end
