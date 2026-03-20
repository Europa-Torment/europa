defmodule Europa.Server.Planet.PredefinedTest do
  use Europa.DataCase, async: true
  use ExUnitProperties

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

  describe "generate/1" do
    property "generates building" do
      check all(_n <- StreamData.integer(1..100)) do
        Predefined.generate(:building)
        |> Enum.with_index(fn row, i ->
          Enum.with_index(row, fn e, j ->
            case {i, j} do
              {0, 0} -> assert e == @wall_left
              {0, 1} -> assert e == @wall_horizontal
              {0, 2} -> assert e == @wall_horizontal
              {0, 3} -> assert e == @wall_horizontal
              {0, 4} -> assert e == @wall_horizontal
              {0, 5} -> assert e == @wall_right
              {1, 0} -> assert e == @wall_left
              {1, 1} -> assert e == @floor || loot?(e)
              {1, 2} -> assert e == @wall_vertical_inside
              {1, 3} -> assert e == @floor || enemy?(e)
              {1, 4} -> assert e == @floor || enemy?(e)
              {1, 5} -> assert e == @wall_right
              {2, 0} -> assert e == @wall_left
              {2, 1} -> assert e == @wall_horizontal
              {2, 2} -> assert e == @floor || enemy?(e)
              {2, 3} -> assert e == @wall_horizontal
              {2, 4} -> assert e == @wall_horizontal
              {2, 5} -> assert e == @wall_right
              {2, 6} -> assert e == :skip
            end
          end)
        end)
      end
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

  defp enemy?(%Enemy{}), do: true
  defp enemy?(_), do: false

  defp loot?(%ItemBox{}), do: true
  defp loot?(_), do: false
end
