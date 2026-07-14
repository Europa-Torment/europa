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

  @skip Objects.object(:skip)
  @broken_wall Objects.object(:broken_wall)

  @fire Objects.object(:fire)

  describe "generate/1" do
    property "generates building" do
      check all(_n <- StreamData.integer(1..100)) do
        Predefined.generate(:building)
        |> Enum.with_index(fn row, i ->
          Enum.with_index(row, fn e, j ->
            case {i, j} do
              {0, 0} -> assert e == @skip
              {0, 1} -> assert e == @skip
              {0, 2} -> assert e == @skip
              {0, 3} -> assert e == @skip
              {0, 4} -> assert e == @skip
              {0, 5} -> assert e == @skip
              {0, 6} -> assert e == @skip
              {1, 0} -> assert e == @skip
              {1, 1} -> assert e == @wall_left_up || e == @broken_wall
              {1, 2} -> assert e == @wall_up || e == @broken_wall
              {1, 3} -> assert_door_object(e, @door_up)
              {1, 4} -> assert e == @wall_up || e == @broken_wall
              {1, 5} -> assert e == @wall_up || e == @broken_wall
              {1, 6} -> assert e == @wall_right_up || e == @broken_wall
              {1, 7} -> assert e == @skip
              {2, 0} -> assert e == @skip
              {2, 1} -> assert_door_object(e, @door_left)
              {2, 2} -> assert e in @floors || loot?(e)
              {2, 3} -> assert e == @wall_vertical_inside
              {2, 4} -> assert e in @floors || enemy?(e) || fire?(e)
              {2, 5} -> assert e in @floors || enemy?(e) || {:npc, @floor}
              {2, 6} -> assert_door_object(e, @door_right)
              {2, 7} -> assert e == @skip
              {3, 0} -> assert e == @skip
              {3, 1} -> assert e == @wall_left || e == @broken_wall
              {3, 2} -> assert e in @floors || loot?(e) || fire?(e)
              {3, 3} -> assert e in @floors || loot?(e) || fire?(e)
              {3, 4} -> assert e in @floors || loot?(e) || fire?(e)
              {3, 5} -> assert e in @floors || loot?(e) || fire?(e)
              {3, 6} -> assert e == @wall_right || e == @broken_wall
              {3, 7} -> assert e == @skip
              {4, 0} -> assert e == @skip
              {4, 1} -> assert e == @wall_left_down || e == @broken_wall
              {4, 2} -> assert e == @wall_down || e == @broken_wall
              {4, 3} -> assert_door_object(e, @door_down)
              {4, 4} -> assert e == @wall_down || e == @broken_wall
              {4, 5} -> assert e == @wall_down || e == @broken_wall
              {4, 6} -> assert e == @wall_right_down || e == @broken_wall
              {4, 7} -> assert e == @skip
              {4, 8} -> assert e == @skip
              {5, 0} -> assert e == @skip
              {5, 1} -> assert e == @skip
              {5, 2} -> assert e == @skip
              {5, 3} -> assert e == @skip
              {5, 4} -> assert e == @skip
              {5, 5} -> assert e == @skip
              {5, 6} -> assert e == @skip
              {5, 7} -> assert e == @skip
              {5, 8} -> assert e == @skip
            end
          end)
        end)
      end
    end

    test "generates situation" do
      assert [
               [@skip, @skip, @skip, @skip, @skip, @skip, @skip],
               [
                 @skip,
                 %Enemy{},
                 %ItemBox{type: :human_body},
                 %Enemy{},
                 %ItemBox{type: :box},
                 shuttle,
                 npc_or_skip,
                 %ItemBox{type: :monster_body},
                 @skip
               ],
               [@skip, @skip, @skip, @skip, @skip, @skip, @skip]
             ] =
               Predefined.generate(:situation)

      is_shuttle =
        case shuttle do
          %ItemBox{type: :crashed_shuttle} -> true
          @fire_shuttle -> true
        end

      assert is_shuttle
      assert npc_or_skip in [{:npc, nil}, @skip]
    end

    defp assert_door_object(object, expected_object) do
      assert struct!(object, transforms: []) == struct!(expected_object, transforms: [])
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

  defp fire?(%Object{} = object) do
    Object.stand_on(object, nil) == @fire
  end

  defp fire?(_), do: false
end
