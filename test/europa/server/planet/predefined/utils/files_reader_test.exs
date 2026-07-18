defmodule Europa.Server.Planet.Predefined.Utils.FilesReaderTest do
  use Europa.DataCase

  alias Europa.Server.Planet.Predefined.Utils.FilesReader

  @path "/planet/"

  @categories %{
    building: %{dir: "/buildings"},
    situation: %{dir: "/situations"}
  }

  describe "parse_files/2" do
    test "returns parsed file as map" do
      result = FilesReader.parse_files(@path, @categories)
      assert is_map(result)

      assert Enum.all?(result, fn {category, %{"base_templates" => base_templates}} ->
               is_atom(category) && is_list(base_templates)
             end)
    end
  end
end
