defmodule Europa.Server.Enemy.Utils.FilesReaderTest do
  use Europa.DataCase

  alias Europa.Server.Enemy.Utils.FilesReader

  describe "parse_file/0" do
    test "returns parsed file as list" do
      result = FilesReader.parse_file()
      assert is_list(result)
      assert Enum.all?(result, fn {attrs, random_weight} -> is_map(attrs) && is_number(random_weight) end)
    end
  end
end
