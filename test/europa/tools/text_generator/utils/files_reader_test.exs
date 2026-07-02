defmodule Europa.Tools.TextGenerator.Utils.FilesReaderTest do
  use Europa.DataCase

  alias Europa.Tools.TextGenerator.Utils.FilesReader

  @path "/texts_templates/"

  @templates %{
    great_red_spot: "story.json"
  }

  describe "parse_files/2" do
    test "returns parsed file as map" do
      result = FilesReader.parse_files(@path, @templates)
      assert is_map(result)
      assert Enum.all?(result, fn {name, content} -> is_atom(name) && is_map(content) end)
    end
  end
end
