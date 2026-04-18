defmodule Europa.Server.NpcTest do
  use Europa.DataCase, async: true

  alias Europa.Server.Npc
  alias Europa.Server.Planet.Tiles

  @snow Tiles.tile(:snow).atom_value

  describe "new/2" do
    test "creates NPC" do
      character = build(:character)
      assert %Npc{character: ^character, stand_on: @snow} = Npc.new(character, @snow)
    end
  end

  describe "readable_stats/1" do
    test "returns stats" do
      npc = build(:npc, character: build(:character, gender: :female))

      expected_stats =
        [
          {"Name", npc.character.name},
          {"Age", npc.character.current_age},
          {"Gender", "Female"}
        ]

      assert Npc.readable_stats(npc) == expected_stats
    end
  end
end
