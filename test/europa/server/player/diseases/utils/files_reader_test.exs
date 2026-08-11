defmodule Europa.Server.Player.Diseases.Utils.FilesReaderTest do
  use Europa.DataCase, async: true

  alias Europa.Server.Player.Diseases.Utils.FilesReader

  @filename "diseases.json"

  describe "parse_file/1" do
    test "returns parsed file as list" do
      result = FilesReader.parse_file(@filename)
      assert is_list(result)
      assert Enum.all?(result, &is_map/1)
    end
  end
end
