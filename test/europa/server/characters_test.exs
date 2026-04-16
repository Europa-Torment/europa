defmodule Europa.Server.CharactersTest do
  use Europa.DataCase

  alias Europa.Server.Characters
  alias Europa.Server.Characters.Character

  @filename "test_characters.json"

  setup do
    {:ok, pid} = Characters.start_link(@filename)
    {:ok, pid: pid}
  end

  describe "pick_main/1" do
    test "picks main character", %{pid: pid} do
      assert {:ok, %Character{} = character} = Characters.pick_main(pid)

      assert is_binary(character.name)
      assert character.gender in [:male, :female]
      assert is_integer(character.age_at_disaster)
      assert is_integer(character.current_age)
      assert %Range{} = character.years
      assert character.current_age - character.age_at_disaster <= character.years |> Enum.to_list() |> List.last()
      assert is_list(character.stories)
    end

    test "returns error when already picked", %{pid: pid} do
      assert {:ok, %Character{}} = Characters.pick_main(pid)
      assert {:error, :already_picked} = Characters.pick_main(pid)
    end
  end

  describe "pick/2" do
    test "picks character lived in given year", %{pid: pid} do
      assert {:ok, %Character{name: "name2"}} = Characters.pick(pid, 40)
    end

    test "returns error when no characters left", %{pid: pid} do
      assert {:ok, %Character{}} = Characters.pick(pid, 40)
      assert {:error, :no_characters} = Characters.pick(pid, 40)
    end
  end
end
