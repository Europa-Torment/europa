defmodule Europa.Server.Planet.PredefinedTest do
  use Europa.DataCase, async: true
  use ExUnitProperties

  alias Europa.Server.Planet.Predefined
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Planet.Tiles.Objects
  alias Europa.Server.Planet.Tiles.Objects.Object
  alias Europa.Server.Loot.ItemBox
  alias Europa.Server.Enemy

  @floor Tiles.tile(:floor).atom_value
  @litter_floor Tiles.tile(:litter_floor).atom_value
  @bloody_floor Tiles.tile(:bloody_floor).atom_value
  @floors [@floor, @bloody_floor, @litter_floor]

  @wall_up Objects.object(:wall_up)
  @wall_down Objects.object(:wall_down)
  @wall_right Objects.object(:wall_right)
  @wall_right_up Objects.object(:wall_right_up)
  @wall_right_down Objects.object(:wall_right_down)
  @wall_left Objects.object(:wall_left)
  @wall_left_up Objects.object(:wall_left_up)
  @wall_left_down Objects.object(:wall_left_down)
  @wall_vertical_inside Objects.object(:wall_vertical_inside)

  @door_left Objects.object(:door_left)
  @door_right Objects.object(:door_right)
  @door_up Objects.object(:door_up)
  @door_down Objects.object(:door_down)

  @fire_shuttle Objects.object(:fire_shuttle)

  describe "generate/1" do
    property "generates building" do
      check all(_n <- StreamData.integer(1..100)) do
        Predefined.generate(:building)
        |> Enum.with_index(fn row, i ->
          Enum.with_index(row, fn e, j ->
            case {i, j} do
              {0, 0} -> assert e == @wall_left_up
              {0, 1} -> assert e == @wall_up
              {0, 2} -> assert_door_object(e, @door_up)
              {0, 3} -> assert e == @wall_up
              {0, 4} -> assert e == @wall_up
              {0, 5} -> assert e == @wall_right_up
              {1, 0} -> assert_door_object(e, @door_left)
              {1, 1} -> assert e in @floors || loot?(e)
              {1, 2} -> assert e == @wall_vertical_inside
              {1, 3} -> assert e in @floors || enemy?(e)
              {1, 4} -> assert e in @floors || enemy?(e) || {:npc, @floor}
              {1, 5} -> assert_door_object(e, @door_right)
              {2, 0} -> assert e == @wall_left
              {2, 1} -> assert e in @floors || loot?(e)
              {2, 2} -> assert e in @floors || loot?(e)
              {2, 3} -> assert e in @floors || loot?(e)
              {2, 4} -> assert e in @floors || loot?(e)
              {2, 5} -> assert e == @wall_right
              {3, 0} -> assert e == @wall_left_down
              {3, 1} -> assert e == @wall_down
              {3, 2} -> assert_door_object(e, @door_down)
              {3, 3} -> assert e == @wall_down
              {3, 4} -> assert e == @wall_down
              {3, 5} -> assert e == @wall_right_down
              {3, 6} -> assert e == :skip
            end
          end)
        end)
      end
    end

    test "generates situation" do
      assert [
               [
                 %Enemy{},
                 %ItemBox{type: :human_body},
                 %Enemy{},
                 %ItemBox{type: :box},
                 shuttle,
                 npc_or_skip,
                 %ItemBox{type: :monster_body}
               ]
             ] =
               Predefined.generate(:situation)

      is_shuttle =
        case shuttle do
          %ItemBox{type: :crashed_shuttle} -> true
          @fire_shuttle -> true
        end

      assert is_shuttle
      assert npc_or_skip in [{:npc, nil}, :skip]
    end

    defp assert_door_object(object, expected_object) do
      assert Object.set_transform_requirements(object, nil) == Object.set_transform_requirements(expected_object, nil)
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
