defmodule Europa.Server.Planet.PredefinedTest do
  use Europa.DataCase

  alias Europa.Server.Planet.Predefined
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Loot.ItemBox
  alias Europa.Server.Enemy

  @wall Tiles.tile(:wall).atom_value
  @floor Tiles.tile(:floor).atom_value

  @expected_house [
    [@wall, @wall, @wall, @wall],
    [@wall, @floor, @floor, @wall],
    [@wall, @floor, @wall, @wall, :skip]
  ]

  describe "generate/1" do
    test "generates building" do
      assert Predefined.generate(:building) == @expected_house
    end

    test "generates situation" do
      assert [[%Enemy{}, %ItemBox{type: :human_body}, %Enemy{}, %ItemBox{type: :box}, %ItemBox{type: :crashed_shuttle}]] =
               Predefined.generate(:situation)
    end
  end

  describe "generate_random/0" do
    test "returns generated list of tiles" do
      assert Predefined.generate_random() |> is_list()
    end
  end
end
