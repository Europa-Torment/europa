defmodule Europa.Server.Characters.Utils.FilesReaderTest do
  use Europa.DataCase

  alias Europa.Server.Characters.Utils.FilesReader

  @characters_filename "characters.json"
  @professions_filename "professions.json"

  describe "parse_characters_file/1" do
    test "returns parsed file as map" do
      assert %{"playable" => [_ | _], "not_playable" => %{}} = FilesReader.parse_characters_file(@characters_filename)
    end
  end

  describe "parse_professions_file/1" do
    test "returns parsed file as map" do
      assert FilesReader.parse_professions_file(@professions_filename) |> is_map()
    end
  end
end
