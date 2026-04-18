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

defmodule Europa.Server.Characters.CharacterTest do
  use Europa.DataCase

  alias Europa.Server.Characters.Character

  describe "determine_current_age/2" do
    test "sets current_age" do
      character = build(:character, age_at_disaster: 10)
      current_year_after_disaster = 15
      assert %Character{current_age: 25} = Character.determine_current_age(character, current_year_after_disaster)
    end
  end

  describe "random_story/1" do
    test "returns one character's story" do
      character = build(:character)
      assert Character.random_story(character) in character.stories
    end
  end

  describe "random_special_story/2" do
    test "returns one special story" do
      special_stories = ["story1", "story 2"]

      main_character = build(:character)
      character = build(:character, special_stories: %{main_character.name => special_stories})

      assert Character.random_special_story(character, main_character) in special_stories
    end

    test "returns nil when no special storeis" do
      [character, main_character] = build_pair(:character)
      assert Character.random_special_story(character, main_character) |> is_nil()
    end
  end

  describe "short_phrase/1" do
    test "returns one short phrase" do
      character = build(:character, short_phrases: ["phrase1", "phrase2"])
      assert Character.short_phrase(character) in character.short_phrases
    end

    test "returns nil when no short_phrases" do
      character = build(:character, short_phrases: [])
      assert Character.short_phrase(character) |> is_nil()
    end
  end
end
