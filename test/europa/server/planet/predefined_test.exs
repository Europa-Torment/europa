defmodule Europa.Server.Planet.PredefinedTest do
  use Europa.DataCase

  alias Europa.Server.Planet.Predefined
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Planet.Tiles.Object
  alias Europa.Server.Loot.ItemBox
  alias Europa.Server.Enemy

  @floor Tiles.tile(:floor).atom_value
  @wall_horizontal %Object{name: "wall", image_name: "wall_horizontal", high?: true}
  @wall_right %Object{name: "wall", image_name: "wall_right", high?: true}
  @wall_left %Object{name: "wall", image_name: "wall_left", high?: true}
  @wall_vertical_inside %Object{name: "wall", image_name: "wall_vertical_inside", high?: true, stand_on: @floor}

  @expected_house [
    [@wall_left, @wall_horizontal, @wall_horizontal, @wall_horizontal, @wall_horizontal, @wall_right],
    [@wall_left, @floor, @wall_vertical_inside, @floor, @floor, @wall_right],
    [@wall_left, @wall_horizontal, @floor, @wall_horizontal, @wall_horizontal, @wall_right, :skip]
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
