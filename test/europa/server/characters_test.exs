defmodule Europa.Server.CharactersTest do
  use Europa.DataCase

  alias Europa.Server.Characters
  alias Europa.Server.Characters.Character

  setup do
    {:ok, pid} = Characters.start_link()
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
  alias Europa.Server.Characters
  use Europa.DataCase

  alias Europa.Server.Characters.Character

  describe "determine_current_age/2" do
    test "sets current_age" do
      character = build(:character, age_at_disaster: 10)
      current_year_after_disaster = 15
      assert %Character{current_age: 25} = Character.determine_current_age(character, current_year_after_disaster)
    end
  end

  describe "enemies?/2" do
    test "returns true when first character is enemy of second character" do
      first_character = build(:character, fraction: :wcc, enemy_fractions: [], not_playable?: true)
      second_character = build(:character, fraction: :ssb, enemy_fractions: [:wcc], not_playable?: true)

      assert Characters.enemies?(first_character, second_character) == true
    end

    test "returns true when second character is enemy of first character" do
      first_character = build(:character, fraction: :wcc, enemy_fractions: [:ssb], not_playable?: true)
      second_character = build(:character, fraction: :ssb, enemy_fractions: [], not_playable?: true)

      assert Characters.enemies?(first_character, second_character) == true
    end

    test "returns false when characters are not enemies" do
      first_character = build(:character, fraction: :wcc, enemy_fractions: [], not_playable?: true)
      second_character = build(:character, fraction: :ssb, enemy_fractions: [], not_playable?: true)

      assert Characters.enemies?(first_character, second_character) == false
    end

    test "returns false is both characters are playable" do
      first_character = build(:character, fraction: :wcc, enemy_fractions: [:ssb], not_playable?: false)
      second_character = build(:character, fraction: :ssb, not_playable?: false)

      assert Characters.enemies?(first_character, second_character) == false
    end
  end

  describe "random_story/1" do
    test "returns nil when character not playable" do
      character = build(:character, not_playable?: true)
      assert Character.random_story(character) |> is_nil()
    end

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
