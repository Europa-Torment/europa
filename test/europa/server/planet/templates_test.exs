defmodule Europa.Server.Planet.Templates.TemplateTest do
  use Europa.DataCase, async: true
  use ExUnitProperties

  alias Europa.Server.Planet.Templates.Template
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Planet.Tiles.Objects
  alias Europa.Server.Planet.Tiles.Objects.Object
  alias Europa.Server.Loot
  alias Europa.Server.Enemy

  @wall_up Objects.object(:wall_up)
  @broken_wall Objects.object(:broken_wall)

  @floor Tiles.tile(:floor).atom_value
  @fire Objects.object(:fire) |> Object.stand_on(@floor)

  @raw_template %{
    name: "house",
    modificators: [
      %{name: "burning", possibility: %{from: 1, to: 2}},
      %{name: "broken", possibility: %{from: 1, to: 2}}
    ],
    content: [
      [
        %{
          type: "object",
          name: "wall_up",
          or: [
            %{
              type: "object",
              name: "broken_wall",
              when: %{
                modificators: ["broken"],
                possibility: %{from: 1, to: 3}
              }
            }
          ]
        },
        %{
          type: "tile",
          name: "floor",
          or: [
            %{
              type: "object",
              name: "fire",
              stand_on: %{type: "tile", name: "floor"},
              when: %{
                modificators: ["burning"],
                possibility: %{from: 1, to: 5}
              }
            }
          ]
        }
      ],
      [
        %{
          type: "loot",
          name: "monster_body",
          or: [
            %{
              type: "npc",
              stand_on: %{
                type: "loot",
                name: "monster_body"
              },
              when: %{
                possibility: %{from: 1, to: 3}
              }
            },
            %{
              type: "npc",
              stand_on: %{
                type: "loot",
                name: "monster_body"
              },
              when: %{
                modificators: ["burning"]
              }
            }
          ]
        },
        %{
          type: "enemy",
          stand_on: %{
            type: "tile",
            name: "snow"
          }
        }
      ]
    ]
  }

  describe "from_map/1" do
    test "builds Template struct from map" do
      assert {:ok, %Template{} = template} = Template.from_map(@raw_template)

      assert template.name == "house"

      assert template.modificators == [
               %Template.Modificator{name: "burning", possibility: %Template.Possibility{from: 1, to: 2}},
               %Template.Modificator{name: "broken", possibility: %Template.Possibility{from: 1, to: 2}}
             ]

      assert template.content == [
               [
                 %Template.Unit{
                   type: :object,
                   name: :wall_up,
                   stand_on: nil,
                   or: [
                     %Template.Unit{
                       type: :object,
                       name: :broken_wall,
                       stand_on: nil,
                       when: %Template.Unit.Condition{
                         modificators: ["broken"],
                         possibility: %Template.Possibility{from: 1, to: 3}
                       }
                     }
                   ]
                 },
                 %Template.Unit{
                   type: :tile,
                   name: :floor,
                   or: [
                     %Template.Unit{
                       type: :object,
                       name: :fire,
                       stand_on: %Template.Unit{
                         type: :tile,
                         name: :floor
                       },
                       when: %Template.Unit.Condition{
                         modificators: ["burning"],
                         possibility: %Template.Possibility{from: 1, to: 5}
                       }
                     }
                   ]
                 }
               ],
               [
                 %Template.Unit{
                   type: :loot,
                   name: :monster_body,
                   or: [
                     %Template.Unit{
                       type: :npc,
                       stand_on: %Template.Unit{
                         type: :loot,
                         name: :monster_body
                       },
                       when: %Template.Unit.Condition{
                         possibility: %Template.Possibility{from: 1, to: 3}
                       }
                     },
                     %Template.Unit{
                       type: :npc,
                       stand_on: %Template.Unit{
                         type: :loot,
                         name: :monster_body
                       },
                       when: %Template.Unit.Condition{
                         modificators: ["burning"]
                       }
                     }
                   ]
                 },
                 %Template.Unit{
                   type: :enemy,
                   stand_on: %Template.Unit{
                     type: :tile,
                     name: :snow
                   }
                 }
               ]
             ]
    end

    test "returns errors when data is invalid" do
      assert {:error, _} = @raw_template |> Map.delete(:name) |> Template.from_map()
      assert {:error, _} = @raw_template |> Map.delete(:content) |> Template.from_map()
      assert {:error, _} = @raw_template |> Map.put(:modificators, "fake") |> Template.from_map()

      invalid_modificators = [
        [%{possibility: %{from: 1, to: 2}}],
        [%{name: "broken"}],
        [%{name: "broken", possibility: %{from: 1}}],
        [%{name: "broken", possibility: %{to: 1}}],
        [%{name: "broken", possibility: %{from: 2, to: 1}}],
        [%{name: "broken", possibility: %{from: "1", to: "2"}}]
      ]

      for modificators <- invalid_modificators do
        assert {:error, _} = @raw_template |> Map.put(:modificators, modificators) |> Template.from_map()
      end
    end
  end

  describe "determine/1" do
    property "determines template" do
      check all(_n <- StreamData.integer(1..100)) do
        {:ok, template} = Template.from_map(@raw_template)
        result = Template.determine(template)

        Enum.with_index(result, fn row, i ->
          Enum.with_index(row, fn e, j ->
            case {i, j} do
              {0, 0} -> assert e == @wall_up || e == @broken_wall
              {0, 1} -> assert e == @floor || e == @fire
              {1, 0} -> assert monster_body?(e) || npc?(e)
              {1, 1} -> assert enemy?(e)
            end
          end)
        end)
      end
    end
  end

  defp monster_body?(%Loot.ItemBox{type: :monster_body}), do: true
  defp monster_body?(_), do: false

  defp npc?({:npc, _}), do: true
  defp npc?(_), do: false

  defp enemy?(%Enemy{}), do: true
  defp enemy?(_), do: false
end

defmodule Europa.Server.Planet.TemplatesTest do
  use Europa.DataCase, async: true

  alias Europa.Server.Planet.Templates
  alias Europa.Server.Planet.Templates.Template

  describe "build_empty_template/0" do
    test "returns empty template" do
      assert %Template{name: "New template", modificators: nil, content: [[]]} = Templates.build_empty_template()
    end
  end

  describe "generate_random/0" do
    test "returns generated list of tiles" do
      assert Templates.generate_random() |> is_list()
    end
  end

  describe "generate/2" do
    test "returns generated list of tiles" do
      assert Templates.generate(:building) |> is_list()
    end
  end
end
