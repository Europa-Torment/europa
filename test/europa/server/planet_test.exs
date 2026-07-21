defmodule Europa.Server.PlanetTest do
  use Europa.DataCase, async: true
  use ExUnitProperties

  alias Europa.Server.Planet
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Planet.Tiles.Objects
  alias Europa.Server.Planet.Tiles.Objects.Object
  alias Europa.Server.Player
  alias Europa.Server.PlayerManagerMock
  alias Europa.Server.Enemy
  alias Europa.Server.Action
  alias Europa.Server.Event
  alias Europa.Server.Characters
  alias Europa.Server.Npc
  alias Europa.Server.Loot.ItemBox
  alias Europa.Server.Loot.Item
  alias Europa.Server.Loot.Weapon
  alias Europa.Server.Loot.Weapon.Ammo
  alias Europa.Server.Errors.NotApplicableError
  alias Europa.Support.PlanetLandConverter

  import Europa.Tools.Conf

  @year 100

  @max_accuracy fetch_config!([:weapons, :max_accuracy]) + 10
  @burst_bullets_per_shot fetch_config!([:weapons, :burst_bullets_per_shot])

  @predefined_cluster_update_distance fetch_config!([Planet, :predefined_cluster_update_distance])

  @view_distance fetch_config!([Planet, :view_distance])

  @initial_enemy_health 20

  @i Tiles.tile(:ice).atom_value
  @p Tiles.tile(:path).atom_value
  @w Tiles.tile(:water).atom_value
  @d Tiles.tile(:darkness).atom_value
  @pl Planet.player()

  @wl Objects.object(:wall_left)

  @dl Objects.object(:door_left)
  @dr Objects.object(:door_right)
  @du Objects.object(:door_up)
  @dd Objects.object(:door_down)

  @dlo Object.transform(@dl, :open)
  @dro Object.transform(@dr, :open)
  @duo Object.transform(@du, :open)
  @ddo Object.transform(@dd, :open)

  @dll_transform build(:object_transform, transform_requirements: {:tools, build_list(2, :tool)})
  @dll_transform2 build(:object_transform, transform_requirements: {:tools, build_list(2, :tool)})

  @dll Objects.object(:door_left) |> struct!(transforms: []) |> Object.add_transform(@dll_transform)
  @dll2 Objects.object(:door_left)
        |> struct!(transforms: [])
        |> Object.add_transform(@dll_transform)
        |> Object.add_transform(@dll_transform2)

  @bf Objects.object(:bonfire) |> Object.stand_on(@i)
  @skip Objects.object(:skip) |> Object.stand_on(@i)

  @ib build(:loot_item_box, items: [build(:weapon)])
  @ib2 build(:loot_item_box, type: :monster_body, items: [build(:weapon)], movable?: true)

  @enemy_events_count 5

  @en build(:enemy,
        name: "E1",
        move_distance: 1,
        health: @initial_enemy_health,
        events: build_list(@enemy_events_count, :event),
        target: :player,
        accuracy: 1000
      )
  @en2 build(:enemy,
         name: "E2",
         move_distance: 1,
         health: @initial_enemy_health,
         events: build_list(@enemy_events_count, :event),
         target: :player
       )
  @en3 build(:enemy,
         name: "E3",
         move_distance: 1,
         health: @initial_enemy_health,
         events: build_list(@enemy_events_count, :event),
         target: :player
       )
  @en4 build(:enemy,
         name: "E4",
         move_distance: 1,
         health: @initial_enemy_health,
         events: build_list(@enemy_events_count, :event),
         target: :player
       )
  @en5 build(:enemy,
         name: "E5",
         move_distance: 1,
         health: @initial_enemy_health,
         events: build_list(@enemy_events_count, :event),
         target: :player
       )
  @en6 build(:enemy,
         name: "E6",
         move_distance: 1,
         health: @initial_enemy_health,
         events: build_list(@enemy_events_count, :event),
         target: :player
       )
  @en7 build(:enemy,
         name: "E7",
         move_distance: 1,
         health: @initial_enemy_health,
         events: build_list(@enemy_events_count, :event),
         target: :player
       )

  @en8 build(:enemy,
         name: "E8",
         move_distance: 1,
         health: @initial_enemy_health,
         events: build_list(@enemy_events_count, :event),
         healer?: true,
         heal_possibility: 1,
         heal_unit: 2,
         target: :player
       )

  @n2_uuid Ecto.UUID.generate()

  @en9 build(:enemy,
         name: "E9",
         move_distance: 1,
         health: @initial_enemy_health,
         events: build_list(@enemy_events_count, :event),
         accuracy: 0,
         target: @n2_uuid
       )

  @n build(:npc, accuracy: 0)

  @n2 build(:npc,
        uuid: @n2_uuid,
        accuracy: 1000,
        weapon: build(:weapon, damage: 1, shooting_distance: 1),
        target: @en9.uuid,
        view_direction: :left
      )

  @n3 build(:npc,
        accuracy: 1000,
        weapon: build(:weapon, damage: 1, shooting_distance: 1),
        target: :player,
        view_direction: :right
      )

  @n4 build(:npc,
        accuracy: 1000,
        weapon: build(:weapon, damage: 1, shooting_distance: 1),
        target: nil,
        view_direction: :right,
        character: build(:character, enemy_fractions: [:neutral, :wcc, :etc, :ssb])
      )

  @move_costs Tiles.move_costs()

  @tiles [
    @i,
    @w,
    @i,
    @p,
    @ib,
    @en,
    @bf,
    @skip
  ]

  @midday Timex.parse!("2016-02-29T12:00:00-06:00", "{ISO:Extended}")

  @land_player_look_up_at_loot [
                                 [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @ib, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @pl, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                               ]
                               |> PlanetLandConverter.from_matrix()

  @land_player_look_down_at_loot [
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @pl, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @ib, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                 ]
                                 |> PlanetLandConverter.from_matrix()

  @land_player_look_right_at_loot [
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @pl, @ib, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                  ]
                                  |> PlanetLandConverter.from_matrix()

  @land_player_look_right_at_monster_body [
                                            [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                            [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                            [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                            [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                            [@i, @i, @i, @i, @pl, @ib2, @i, @i, @i, @i],
                                            [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                            [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                            [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                            [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                            [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                          ]
                                          |> PlanetLandConverter.from_matrix()

  @land_player_look_left_at_loot [
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @ib, @pl, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                 ]
                                 |> PlanetLandConverter.from_matrix()

  @land_player_up_close_to_bonfire [
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @bf, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @ib, @pl, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                   ]
                                   |> PlanetLandConverter.from_matrix()

  @land_player_near_left_border [
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @pl, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                ]
                                |> PlanetLandConverter.from_matrix()

  @land_player_near_right_border [
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @pl, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                 ]
                                 |> PlanetLandConverter.from_matrix()

  @land_player_near_top_border [
                                 [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @pl, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                               ]
                               |> PlanetLandConverter.from_matrix()

  @land_player_near_down_border [
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @pl, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                ]
                                |> PlanetLandConverter.from_matrix()

  @land_player_look_up_at_enemy [
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @en, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @pl, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                ]
                                |> PlanetLandConverter.from_matrix()

  @land_player_up_close_to_enemy [
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @en, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @pl, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                 ]
                                 |> PlanetLandConverter.from_matrix()

  @land_player_look_down_at_enemy [
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @pl, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @en, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                  ]
                                  |> PlanetLandConverter.from_matrix()

  @land_player_down_close_to_enemy [
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @pl, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @en, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                   ]
                                   |> PlanetLandConverter.from_matrix()

  @land_player_look_right_at_enemy [
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @pl, @i, @en, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                   ]
                                   |> PlanetLandConverter.from_matrix()

  @land_player_left_close_to_enemy [
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @pl, @en, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                   ]
                                   |> PlanetLandConverter.from_matrix()

  @land_player_look_left_at_enemy [
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @en, @i, @pl, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                  ]
                                  |> PlanetLandConverter.from_matrix()

  @land_player_right_close_to_enemy [
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @en, @pl, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                    ]
                                    |> PlanetLandConverter.from_matrix()

  @land_player_look_up_at_enemies [
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @en, @en2, @en3, @en4, @en5, @en6, @en7, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @pl, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                  ]
                                  |> PlanetLandConverter.from_matrix()

  @land_player_look_down_at_enemies [
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @pl, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                      [@i, @en, @en2, @en3, @en4, @en5, @en6, @en7, @i, @i],
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                    ]
                                    |> PlanetLandConverter.from_matrix()

  @land_player_look_right_at_enemies [
                                       [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                       [@i, @i, @i, @i, @en, @i, @i, @i, @i, @i],
                                       [@i, @i, @i, @i, @en2, @i, @i, @i, @i, @i],
                                       [@i, @i, @i, @i, @en3, @i, @i, @i, @i, @i],
                                       [@i, @i, @pl, @i, @en4, @i, @i, @i, @i, @i],
                                       [@i, @i, @i, @i, @en5, @i, @i, @i, @i, @i],
                                       [@i, @i, @i, @i, @en6, @i, @i, @i, @i, @i],
                                       [@i, @i, @i, @i, @en7, @i, @i, @i, @i, @i],
                                       [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                       [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                     ]
                                     |> PlanetLandConverter.from_matrix()

  @land_player_look_left_at_enemies [
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @en, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @en2, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @en3, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @en4, @i, @i, @pl, @i, @i],
                                      [@i, @i, @i, @i, @en5, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @en6, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @en7, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                    ]
                                    |> PlanetLandConverter.from_matrix()

  @land_player_look_down_at_enemies_with_healer [
                                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                  [@i, @i, @i, @en2, @pl, @en4, @i, @i, @i, @i],
                                                  [@i, @i, @i, @i, @en8, @i, @i, @i, @i, @i],
                                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                  [@i, @en, @i, @en3, @i, @en5, @en6, @en7, @i, @i],
                                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                                ]
                                                |> PlanetLandConverter.from_matrix()

  @land_player_look_up_at_enemies_behind_wall [
                                                [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                [@i, @en, @en2, @en3, @en4, @en5, @en6, @en7, @i, @i],
                                                [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                [@wl, @wl, @wl, @wl, @wl, @wl, @wl, @wl, @wl, @wl],
                                                [@i, @i, @i, @i, @pl, @i, @i, @i, @i, @i],
                                                [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                              ]
                                              |> PlanetLandConverter.from_matrix()

  @land_player_look_down_at_enemies_behind_wall [
                                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                  [@i, @i, @i, @i, @pl, @i, @i, @i, @i, @i],
                                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                  [@i, @wl, @wl, @wl, @wl, @wl, @wl, @wl, @wl, @wl],
                                                  [@i, @en, @en2, @en3, @en4, @en5, @en6, @en7, @i, @i],
                                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                                ]
                                                |> PlanetLandConverter.from_matrix()

  @land_player_look_right_at_enemies_behind_wall [
                                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                   [@i, @i, @i, @wl, @en, @i, @i, @i, @i, @i],
                                                   [@i, @i, @i, @wl, @en2, @i, @i, @i, @i, @i],
                                                   [@i, @i, @i, @wl, @en3, @i, @i, @i, @i, @i],
                                                   [@i, @i, @pl, @wl, @en4, @i, @i, @i, @i, @i],
                                                   [@i, @i, @i, @wl, @en5, @i, @i, @i, @i, @i],
                                                   [@i, @i, @i, @wl, @en6, @i, @i, @i, @i, @i],
                                                   [@i, @i, @i, @wl, @en7, @i, @i, @i, @i, @i],
                                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                                 ]
                                                 |> PlanetLandConverter.from_matrix()

  @land_player_look_left_at_enemies_behind_wall [
                                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                  [@i, @i, @i, @i, @en, @wl, @i, @i, @i, @i],
                                                  [@i, @i, @i, @i, @en2, @wl, @i, @i, @i, @i],
                                                  [@i, @i, @i, @i, @en3, @wl, @i, @i, @i, @i],
                                                  [@i, @i, @i, @i, @en4, @wl, @i, @pl, @i, @i],
                                                  [@i, @i, @i, @i, @en5, @wl, @i, @i, @i, @i],
                                                  [@i, @i, @i, @i, @en6, @wl, @i, @i, @i, @i],
                                                  [@i, @i, @i, @i, @en7, @wl, @i, @i, @i, @i],
                                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                                ]
                                                |> PlanetLandConverter.from_matrix()

  @land_player_up_close_to_npc [
                                 [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @n, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @pl, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                 [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                               ]
                               |> PlanetLandConverter.from_matrix()

  @land_player_down_close_to_npc [
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @pl, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @n, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                 ]
                                 |> PlanetLandConverter.from_matrix()

  @land_player_left_close_to_npc [
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @pl, @n, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                 ]
                                 |> PlanetLandConverter.from_matrix()

  @land_player_right_close_to_npc [
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @n, @pl, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                  ]
                                  |> PlanetLandConverter.from_matrix()

  @land_player_right_close_to_enemy_npc [
                                          [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                          [@i, @i, @i, @n3, @pl, @i, @i, @i, @i, @i],
                                          [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                          [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                          [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                          [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                          [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                          [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                          [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                          [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                        ]
                                        |> PlanetLandConverter.from_matrix()

  @land_player_right_close_to_fraction_enemy_npc [
                                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                   [@i, @i, @i, @n4, @pl, @i, @i, @i, @i, @i],
                                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                                 ]
                                                 |> PlanetLandConverter.from_matrix()

  @land_player_up_close_to_water [
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @w, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @pl, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                 ]
                                 |> PlanetLandConverter.from_matrix()

  @land_player_down_close_to_water [
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @pl, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @w, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                   ]
                                   |> PlanetLandConverter.from_matrix()

  @land_player_left_close_to_water [
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @pl, @w, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                   ]
                                   |> PlanetLandConverter.from_matrix()

  @land_player_right_close_to_water [
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @w, @pl, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                      [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                    ]
                                    |> PlanetLandConverter.from_matrix()

  @land_player_up_close_to_door [
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @dd, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @pl, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                  [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                ]
                                |> PlanetLandConverter.from_matrix()

  @land_player_down_close_to_door [
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @pl, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @du, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                  ]
                                  |> PlanetLandConverter.from_matrix()

  @land_player_left_close_to_door [
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @pl, @dl, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                    [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                  ]
                                  |> PlanetLandConverter.from_matrix()

  @land_player_right_close_to_door [
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @dr, @pl, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                     [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                   ]
                                   |> PlanetLandConverter.from_matrix()

  @land_player_up_close_to_open_door [
                                       [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                       [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                       [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                       [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                       [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                       [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                       [@i, @i, @i, @i, @ddo, @i, @i, @i, @i, @i],
                                       [@i, @i, @i, @i, @pl, @i, @i, @i, @i, @i],
                                       [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                       [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                     ]
                                     |> PlanetLandConverter.from_matrix()

  @land_player_down_close_to_open_door [
                                         [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                         [@i, @i, @i, @i, @pl, @i, @i, @i, @i, @i],
                                         [@i, @i, @i, @i, @duo, @i, @i, @i, @i, @i],
                                         [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                         [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                         [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                         [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                         [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                         [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                         [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                       ]
                                       |> PlanetLandConverter.from_matrix()

  @land_player_left_close_to_open_door [
                                         [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                         [@i, @i, @i, @i, @pl, @dlo, @i, @i, @i, @i],
                                         [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                         [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                         [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                         [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                         [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                         [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                         [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                         [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                       ]
                                       |> PlanetLandConverter.from_matrix()

  @land_player_right_close_to_open_door [
                                          [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                          [@i, @i, @i, @dro, @pl, @i, @i, @i, @i, @i],
                                          [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                          [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                          [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                          [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                          [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                          [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                          [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                          [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                        ]
                                        |> PlanetLandConverter.from_matrix()

  @land_player_left_close_to_locked_door [
                                           [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                           [@i, @i, @i, @i, @pl, @dll, @i, @i, @i, @i],
                                           [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                           [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                           [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                           [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                           [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                           [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                           [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                           [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                         ]
                                         |> PlanetLandConverter.from_matrix()

  @land_player_left_close_to_locked_door_with_multipe_transforms [
                                                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                                   [@i, @i, @i, @i, @pl, @dll2, @i, @i, @i, @i],
                                                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                                                 ]
                                                                 |> PlanetLandConverter.from_matrix()

  @land_enemy_right_close_to_npc [
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @en, @n, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @pl, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                 ]
                                 |> PlanetLandConverter.from_matrix()

  @land_npc_right_close_to_enemy [
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @en9, @n2, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @pl, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                                   [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                                 ]
                                 |> PlanetLandConverter.from_matrix()

  @land_npc_near_to_enemy [
                            [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                            [@i, @i, @en9, @i, @n2, @i, @i, @i, @i, @i],
                            [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                            [@i, @i, @i, @pl, @i, @i, @i, @i, @i, @i],
                            [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                            [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                            [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                            [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                            [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i],
                            [@i, @i, @i, @i, @i, @i, @i, @i, @i, @i]
                          ]
                          |> PlanetLandConverter.from_matrix()

  setup do
    {:ok, characters_pid} = Characters.start_link()
    planet = Planet.new(year: @year, characters_pid: characters_pid, player_fraction: :neutral)
    {:ok, planet: planet, characters_pid: characters_pid}
  end

  describe "new/1" do
    test "creates planet", %{characters_pid: characters_pid} do
      fraction = :wcc

      assert %Planet{land: land, current_coord: {x, y}, year: year, player_fraction: player_fraction} =
               Planet.new(year: @year, characters_pid: characters_pid, player_fraction: fraction)

      assert %Planet.Land{tiles: %{}} = land
      assert is_integer(x)
      assert is_integer(y)

      assert year == @year
      assert player_fraction == fraction
    end
  end

  describe "view_distance/0" do
    test "returns pos integer" do
      distance = Planet.view_distance()
      assert is_integer(distance)
      assert distance > 0
    end
  end

  describe "player/0" do
    test "returns :player atom" do
      assert Planet.player() == :player
    end
  end

  describe "allow_directions/0" do
    test "returns list of allowed move directions" do
      assert Planet.allowed_directions() == [:up, :down, :right, :left]
    end
  end

  describe "readable_tile_name/1" do
    test "returns string name for tile" do
      for tile <- @tiles do
        assert Planet.readable_tile_name(tile) |> is_binary()
      end
    end
  end

  describe "get_visible_land/2" do
    setup do
      planet = build(:planet, land: @land_player_look_up_at_loot, current_coord: {4, 4})
      {:ok, planet: planet}
    end

    test "returns visible part of land (full view distance)", %{planet: planet} do
      expected_visible_land =
        [
          [@i, @i, @i, @i, @i],
          [@i, @i, @ib, @i, @i],
          [@i, @i, @pl, @i, @i],
          [@i, @i, @i, @i, @i],
          [@i, @i, @i, @i, @i]
        ]

      assert Planet.get_visible_land(planet, @midday) == expected_visible_land
    end

    test "returns visible part of land (with darkness)", %{planet: planet} do
      expected_visible_land =
        [
          [@d, @i, @i, @i, @d],
          [@i, @i, @ib, @i, @i],
          [@i, @i, @pl, @i, @i],
          [@i, @i, @i, @i, @i],
          [@d, @i, @i, @i, @d]
        ]

      evening = Timex.parse!("2016-02-29T20:00:00-06:00", "{ISO:Extended}")
      assert Planet.get_visible_land(planet, evening) == expected_visible_land
    end
  end

  describe "move/2" do
    test "moves player right" do
      planet =
        %Planet{current_coord: {x, y}} = build(:planet, land: @land_player_look_up_at_loot, current_coord: {4, 4})

      player = build_player_stand_on(@i)

      assert {:moved, %Planet{current_coord: {x2, ^y}} = updated_planet, move_cost, _, _next_to_interactive = false} =
               Planet.move(planet, :right, player)

      assert x2 == x + 1
      assert move_cost == Map.fetch!(@move_costs, @i)

      expected_visible_land =
        [
          [@i, @i, @i, @i, @i],
          [@i, @ib, @i, @i, @i],
          [@i, @i, @pl, @i, @i],
          [@i, @i, @i, @i, @i],
          [@i, @i, @i, @i, @i]
        ]

      assert Planet.get_visible_land(updated_planet, @midday) == expected_visible_land
    end

    test "moves player left" do
      planet =
        %Planet{current_coord: {x, y}} = build(:planet, land: @land_player_look_up_at_loot, current_coord: {4, 4})

      player = build_player_stand_on(@i)

      assert {:moved, %Planet{current_coord: {x2, ^y}} = updated_planet, move_cost, _, _next_to_interactive = false} =
               Planet.move(planet, :left, player)

      assert x2 == x - 1
      assert move_cost == Map.fetch!(@move_costs, @i)

      expected_visible_land =
        [
          [@i, @i, @i, @i, @i],
          [@i, @i, @i, @ib, @i],
          [@i, @i, @pl, @i, @i],
          [@i, @i, @i, @i, @i],
          [@i, @i, @i, @i, @i]
        ]

      assert Planet.get_visible_land(updated_planet, @midday) == expected_visible_land
    end

    test "moves player up" do
      planet =
        %Planet{current_coord: {x, y}} = build(:planet, land: @land_player_look_right_at_loot, current_coord: {4, 4})

      player = build_player_stand_on(@i)

      assert {:moved, %Planet{current_coord: {^x, y2}} = updated_planet, move_cost, _, _next_to_interactive = false} =
               Planet.move(planet, :up, player)

      assert y2 == y - 1
      assert move_cost == Map.fetch!(@move_costs, @i)

      expected_visible_land =
        [
          [@i, @i, @i, @i, @i],
          [@i, @i, @i, @i, @i],
          [@i, @i, @pl, @i, @i],
          [@i, @i, @i, @ib, @i],
          [@i, @i, @i, @i, @i]
        ]

      assert Planet.get_visible_land(updated_planet, @midday) == expected_visible_land
    end

    test "moves at monster body" do
      planet = build(:planet, land: @land_player_look_right_at_monster_body, current_coord: {4, 4})
      player = build_player_stand_on(@i)

      assert {:moved, %Planet{}, move_cost, stand_on_tile, _next_to_interactive = false} =
               Planet.move(planet, :right, player)

      assert stand_on_tile == @ib2
      assert move_cost == Map.fetch!(@move_costs, @ib2.stand_on)
    end

    test "not moves on not movable tile" do
      planet = build(:planet, land: @land_player_look_right_at_loot, current_coord: {4, 4})
      player = build_player_stand_on(@i)
      assert {:stay, @ib} = Planet.move(planet, :right, player)
    end

    test "switches position with npc" do
      player = build(:player, view_direction: :up)

      planet =
        %Planet{current_coord: {x, y}} = build(:planet, land: @land_player_up_close_to_npc, current_coord: {4, 7})

      assert {:moved, %Planet{current_coord: {^x, y2}} = updated_planet, move_cost, _, _next_to_interactive = true} =
               Planet.move(planet, :up, player)

      assert y2 == y - 1
      assert move_cost == Map.fetch!(@move_costs, @i)
      assert %Npc{} = Map.get(updated_planet.land.tiles, {x, y})
    end

    test "generates left column" do
      planet =
        %Planet{current_coord: {x, y}, land: land} =
        build(:planet, land: @land_player_near_left_border, current_coord: {2, 4})

      player = build_player_stand_on(@i)

      assert {:moved, %Planet{current_coord: {x2, ^y}, land: updated_land}, _, _, _next_to_interactive = false} =
               Planet.move(planet, :left, player)

      assert x - x2 == 1
      assert updated_land.min_x == land.min_x - 1
    end

    test "generates right column" do
      planet =
        %Planet{current_coord: {x, y}, land: land} =
        build(:planet, land: @land_player_near_right_border, current_coord: {7, 4})

      player = build_player_stand_on(@i)

      assert {:moved, %Planet{current_coord: {x2, ^y}, land: updated_land}, _, _, _next_to_interactive = false} =
               Planet.move(planet, :right, player)

      assert x2 == x + 1

      assert updated_land.max_x - land.max_x == 1
    end

    test "generates top row" do
      planet =
        %Planet{current_coord: {x, y}, land: land} =
        build(:planet, land: @land_player_near_top_border, current_coord: {4, 2})

      player = build_player_stand_on(@i)

      assert {:moved, %Planet{current_coord: {^x, y2}, land: updated_land}, _, _, _next_to_interactive = false} =
               Planet.move(planet, :up, player)

      assert y2 == y - 1

      assert updated_land.min_y == land.min_y - 1
    end

    test "generates bottom row" do
      planet =
        %Planet{current_coord: {x, y}, land: land} =
        build(:planet, land: @land_player_near_down_border, current_coord: {4, 7})

      player = build_player_stand_on(@i)

      assert {:moved, %Planet{current_coord: {^x, y2}, land: updated_land}, _, _, _next_to_interactive = false} =
               Planet.move(planet, :down, player)

      assert y2 == y + 1

      assert updated_land.max_y == land.max_y + 1
    end

    test "damages top enemy" do
      planet = build(:planet, land: @land_player_up_close_to_enemy, current_coord: {4, 7})
      player = build(:player, accuracy: @max_accuracy)
      melee_weapon = build(:melee_weapon)

      test_damage_enemy(planet, player, :up, melee_weapon.damage, melee_weapon.hit_cost, melee_weapon)
    end

    test "damages top enemy (no melee weapon equipped)" do
      planet = build(:planet, land: @land_player_up_close_to_enemy, current_coord: {4, 7})
      player = build(:player, accuracy: @max_accuracy)

      test_damage_enemy(planet, player, :up, _damage = 1, _move_cost = 2, _melee_weapon = nil)
    end

    test "damages bottom enemy" do
      planet = build(:planet, land: @land_player_down_close_to_enemy, current_coord: {4, 1})
      player = build(:player, accuracy: @max_accuracy)
      melee_weapon = build(:melee_weapon)

      test_damage_enemy(planet, player, :down, melee_weapon.damage, melee_weapon.hit_cost, melee_weapon)
    end

    test "damages bottom enemy (no melee weapon equipped)" do
      planet = build(:planet, land: @land_player_down_close_to_enemy, current_coord: {4, 1})
      player = build(:player, accuracy: @max_accuracy)

      test_damage_enemy(planet, player, :down, _damage = 1, _move_cost = 2, _melee_weapon = nil)
    end

    test "damages right enemy" do
      planet = build(:planet, land: @land_player_left_close_to_enemy, current_coord: {4, 1})
      player = build(:player, accuracy: @max_accuracy)
      melee_weapon = build(:melee_weapon)

      test_damage_enemy(planet, player, :right, melee_weapon.damage, melee_weapon.hit_cost, melee_weapon)
    end

    test "damages right enemy (no melee weapon equipped)" do
      planet = build(:planet, land: @land_player_left_close_to_enemy, current_coord: {4, 1})
      player = build(:player, accuracy: @max_accuracy)

      test_damage_enemy(planet, player, :right, _damage = 1, _move_cost = 2, _melee_weapon = nil)
    end

    test "damages left enemy" do
      planet = build(:planet, land: @land_player_right_close_to_enemy, current_coord: {4, 1})
      player = build(:player, accuracy: @max_accuracy)
      melee_weapon = build(:melee_weapon)

      test_damage_enemy(planet, player, :left, melee_weapon.damage, melee_weapon.hit_cost, melee_weapon)
    end

    test "damages left enemy (no melee weapon equipped)" do
      planet = build(:planet, land: @land_player_right_close_to_enemy, current_coord: {4, 1})
      player = build(:player, accuracy: @max_accuracy)

      test_damage_enemy(planet, player, :left, _damage = 1, _move_cost = 2, _melee_weapon = nil)
    end

    defp test_damage_enemy(planet, player, direction, expected_damage, expected_move_cost, melee_weapon) do
      PlayerManagerMock
      |> expect(:get_equipped_melee_weapon, fn %Player{} ->
        if melee_weapon do
          {:ok, melee_weapon}
        else
          {:error, :no_melee_weapon}
        end
      end)
      |> expect(:melee_weapon_damage, fn _ -> expected_damage end)

      assert {:attack, %Planet{} = updated_planet, damaged_enemies, ^expected_move_cost} =
               Planet.move(planet, direction, player)

      assert Enum.count(damaged_enemies) == 1
      assert_damaged_enemies(updated_planet, damaged_enemies, expected_damage)
    end
  end

  describe "tick/2" do
    test "enemy moves down to player" do
      planet = build(:planet, land: @land_player_look_up_at_enemy, current_coord: {4, 7})

      assert {:ok, %Planet{land: updated_land}, [%Action{subject: @en, action_type: :chasing}]} =
               Planet.tick(planet, 1)

      assert updated_land == @land_player_up_close_to_enemy
    end

    test "enemy moves up to player" do
      planet = build(:planet, land: @land_player_look_down_at_enemy, current_coord: {4, 1})

      assert {:ok, %Planet{land: updated_land}, [%Action{subject: @en, action_type: :chasing}]} =
               Planet.tick(planet, 1)

      assert updated_land == @land_player_down_close_to_enemy
    end

    test "enemy moves left to player" do
      planet = build(:planet, land: @land_player_look_right_at_enemy, current_coord: {4, 1})

      assert {:ok, %Planet{land: updated_land}, [%Action{subject: @en, action_type: :chasing}]} =
               Planet.tick(planet, 1)

      assert updated_land.tiles == @land_player_left_close_to_enemy.tiles
    end

    test "enemy moves right to player" do
      planet = build(:planet, land: @land_player_look_left_at_enemy, current_coord: {4, 1})

      assert {:ok, %Planet{land: updated_land}, [%Action{subject: @en, action_type: :chasing}]} =
               Planet.tick(planet, 1)

      assert updated_land == @land_player_right_close_to_enemy
    end

    test "enemy attacks npc" do
      planet = build(:planet, land: @land_enemy_right_close_to_npc, current_coord: {3, 3})

      assert {:ok, %Planet{} = updated_planet, [%Action{subject: {%Enemy{}, %Npc{}}, action_type: :attack}]} =
               Planet.tick(planet, 1)

      assert Enum.find(updated_planet.land.tiles, fn
               {_, %Npc{} = npc} -> npc.uuid == @n.uuid && npc.health == @n.health - @en.damage
               _ -> false
             end)
    end

    test "npc attacks enemy" do
      planet = build(:planet, land: @land_npc_right_close_to_enemy, current_coord: {3, 3})

      assert {:ok, %Planet{} = updated_planet, [%Action{subject: {%Npc{}, %Enemy{}}, action_type: :attack}]} =
               Planet.tick(planet, 1)

      assert Enum.find(updated_planet.land.tiles, fn
               {_, %Enemy{} = enemy} -> enemy.uuid == @en9.uuid && enemy.health == @en9.health - @n2.weapon.damage
               _ -> false
             end)
    end

    test "npc attacks player (triggered to player)" do
      planet = build(:planet, land: @land_player_right_close_to_enemy_npc, current_coord: {4, 1})
      assert {:ok, %Planet{}, [%Action{subject: %Npc{}, action_type: :attack}]} = Planet.tick(planet, 1)
    end

    test "npc attacks player (enemy fraction)" do
      planet = build(:planet, land: @land_player_right_close_to_fraction_enemy_npc, current_coord: {4, 1})
      assert {:ok, %Planet{}, [%Action{subject: %Npc{}, action_type: :attack}]} = Planet.tick(planet, 1)
    end

    test "npc moves to enemy" do
      planet = build(:planet, land: @land_npc_near_to_enemy, current_coord: {3, 3})
      assert {:ok, %Planet{land: @land_npc_right_close_to_enemy}, _} = Planet.tick(planet, 1)
    end

    test "doesn't update predefined_cluster_coord when player not to far from current cluster" do
      current_coord = {4, 7}

      planet =
        build(:planet,
          land: @land_player_look_up_at_enemy,
          current_coord: current_coord,
          predefined_cluster_coord: current_coord
        )

      assert {:ok, %Planet{land: updated_land, predefined_cluster_coord: ^current_coord},
              [%Action{subject: @en, action_type: :chasing}]} =
               Planet.tick(planet, 1)

      assert updated_land == @land_player_up_close_to_enemy
    end

    test "updates predefined_cluster_coord" do
      current_x = 4
      current_y = 7
      current_coord = {current_x, current_y}
      predefined_cluster_coord = {current_x + @predefined_cluster_update_distance, current_y}

      planet =
        build(:planet,
          land: @land_player_look_up_at_enemy,
          current_coord: current_coord,
          predefined_cluster_coord: predefined_cluster_coord
        )

      assert {:ok, %Planet{land: updated_land, predefined_cluster_coord: ^current_coord},
              [%Action{subject: @en, action_type: :chasing}]} =
               Planet.tick(planet, 1)

      assert updated_land == @land_player_up_close_to_enemy
    end

    test "updates moves_count" do
      planet = build(:planet, moves_count: 100, land: @land_player_look_up_at_enemy, current_coord: {4, 7})
      moves_count = 5
      expected_moves_count = planet.moves_count + moves_count

      assert {:ok, %Planet{moves_count: ^expected_moves_count}, _} = Planet.tick(planet, moves_count)
    end

    test "healer heals other enemies" do
      moves_count = 1

      planet = build(:planet, land: @land_player_look_down_at_enemies_with_healer, current_coord: {4, 1})
      assert {:ok, %Planet{land: land}, actions} = Planet.tick(planet, moves_count)

      healed_names = [@en2.name, @en4.name]

      heal_unit = @en8.heal_unit
      expected_health = @initial_enemy_health + heal_unit

      assert Enum.count(actions, fn
               %Action{action_type: {:healed, %Enemy{name: name}, ^heal_unit}} -> name in healed_names
               _ -> false
             end) == 2

      Enum.each(healed_names, fn name ->
        assert Enum.find(land.tiles, fn
                 {_, %Enemy{name: ^name, health: ^expected_health, events: events}} ->
                   Enum.find(events, fn
                     %Event{type: {:healed, ^heal_unit}} -> true
                     _ -> false
                   end)

                 _ ->
                   false
               end)
      end)
    end

    @tag perfomance: true
    test "tick is fast enough" do
      acceptable_time_ms = 200

      cols = 1_000
      rows = 1_000

      moves_count = 3

      player_coord = {px, py} = {div(cols, 2), div(cols, 2)}

      # generate land with enemies around player
      land =
        for _ <- 1..cols do
          for _ <- 1..rows do
            @i
          end
        end
        |> change_tile(player_coord, @pl)
        |> change_tile({px - 1, py - 1}, @en)
        |> change_tile({px + 1, py}, @en)
        |> change_tile({px + 2, py}, @en)
        |> change_tile({px, py + 2}, @en)
        |> PlanetLandConverter.from_matrix()

      planet = build(:planet, land: land, current_coord: player_coord)

      {time, {:ok, _, _}} = :timer.tc(fn -> Planet.tick(planet, moves_count) end)

      exact_time_ms = time / 1000
      rounded_time_ms = div(time, 1000)

      IO.puts("Tick (#{moves_count} moves) in #{cols}x#{rows} land took #{exact_time_ms} ms")

      assert rounded_time_ms in 0..acceptable_time_ms
    end
  end

  describe "remove_last_events/1" do
    test "removes enemies events" do
      current_coord = {2, 4}
      planet = build(:planet, land: @land_player_look_right_at_enemies, current_coord: current_coord)

      assert {:ok, %Planet{land: land}, events} = Planet.remove_last_events(planet)
      assert Enum.count(events) == 5

      assert Enum.all?(land.tiles, fn {coord, tile} ->
               if coords_distance(coord, current_coord) > div(@view_distance, 2) do
                 true
               else
                 case tile do
                   %Enemy{events: events} -> Enum.count(events) == @enemy_events_count - 1
                   _ -> true
                 end
               end
             end)
    end
  end

  describe "loot/2" do
    test "opens right item box" do
      planet = build(:planet, land: @land_player_look_right_at_loot, current_coord: {4, 4})
      assert {:open_item_box, @ib} = Planet.loot(planet, build(:player, view_direction: :right))
    end

    test "opens left item box" do
      planet = build(:planet, land: @land_player_look_left_at_loot, current_coord: {4, 4})
      assert {:open_item_box, @ib} = Planet.loot(planet, build(:player, view_direction: :left))
    end

    test "opens top item box" do
      planet = build(:planet, land: @land_player_look_up_at_loot, current_coord: {4, 4})
      assert {:open_item_box, @ib} = Planet.loot(planet, build(:player, view_direction: :up))
    end

    test "opens bottom item box" do
      planet = build(:planet, land: @land_player_look_down_at_loot, current_coord: {4, 4})
      assert {:open_item_box, @ib} = Planet.loot(planet, build(:player, view_direction: :down))
    end

    test "opens under player item box" do
      planet = build(:planet)
      player = build(:player, stand_on: @ib2)
      assert {:open_item_box, @ib2} = Planet.loot(planet, player)
    end

    test "retunrs {:error, :noting} when there is not item box next to player view direction" do
      planet = build(:planet, land: @land_player_look_right_at_loot, current_coord: {4, 4})
      assert {:error, :nothing} = Planet.loot(planet, build(:player, view_direction: :left))
    end
  end

  describe "take_loot/3" do
    test "takes item from right item box" do
      planet = build(:planet, land: @land_player_look_right_at_loot, current_coord: {4, 4})
      player = build(:player, view_direction: :right)

      test_take_loot(planet, player, {4 + 1, 4})
    end

    test "takes item from left item box" do
      planet = build(:planet, land: @land_player_look_left_at_loot, current_coord: {4, 4})
      player = build(:player, view_direction: :left)

      test_take_loot(planet, player, {4 - 1, 4})
    end

    test "takes item from top item box" do
      planet = build(:planet, land: @land_player_look_up_at_loot, current_coord: {4, 4})
      player = build(:player, view_direction: :up)

      test_take_loot(planet, player, {4, 4 - 1})
    end

    test "takes item from bottom item box" do
      planet = build(:planet, land: @land_player_look_down_at_loot, current_coord: {4, 4})
      player = build(:player, view_direction: :down)

      test_take_loot(planet, player, {4, 4 + 1})
    end

    test "takes item from item box under player" do
      planet = build(:planet, land: @land_player_look_down_at_loot, current_coord: {4, 4})
      player = build(:player, view_direction: :down, stand_on: @ib2)

      item = Enum.random(@ib2.items)

      PlayerManagerMock
      |> expect(:add_item, fn ^player, ^item ->
        {:ok, player}
      end)
      |> expect(:stand_on, fn ^player, %ItemBox{items: []} -> player end)

      assert {:ok, %Planet{}, %Player{}, %ItemBox{items: []}} = Planet.take_loot(planet, player, item.uuid)
    end

    test "retunrs {:error, :noting} when there is not item box next to player view direction" do
      planet = build(:planet, land: @land_player_look_down_at_loot, current_coord: {4, 4})
      player = build(:player, view_direction: :up)
      item_uuid = 0

      assert {:error, :nothing} = Planet.take_loot(planet, player, item_uuid)
    end

    test "returns {:error, :no_item} when there is no item with given uuid" do
      planet = build(:planet, land: @land_player_look_down_at_loot, current_coord: {4, 4})
      player = build(:player, view_direction: :down)
      item_uuid = 10

      assert {:error, :no_item} = Planet.take_loot(planet, player, item_uuid)
    end

    defp test_take_loot(planet, player, target_coord) do
      item = Enum.random(@ib.items)

      PlayerManagerMock
      |> expect(:add_item, fn ^player, ^item ->
        {:ok, player}
      end)

      assert {:ok, updated_planet, %Player{}, %ItemBox{items: []}} = Planet.take_loot(planet, player, item.uuid)

      assert %ItemBox{items: []} = tile_at(updated_planet.land, target_coord)
    end
  end

  describe "use_tool/3" do
    setup do
      tool = build(:tool, using_type: {:put_object, :bonfire}, use_cost: 1)
      {:ok, tool: tool}
    end

    test "adds object", %{tool: tool} do
      planet = build(:planet, land: @land_player_look_left_at_loot, current_coord: {4, 4})
      assert {:ok, %Planet{land: @land_player_up_close_to_bonfire}} = Planet.use_tool(planet, tool, :up)
    end

    test "returns NotApplicableError", %{tool: tool} do
      planet = build(:planet, land: @land_player_look_left_at_loot, current_coord: {4, 4})
      assert {:error, %NotApplicableError{}} = Planet.use_tool(planet, tool, :left)
    end
  end

  describe "crop_land/1" do
    test "crops planet land to size of visible land" do
      planet = build(:planet, land: @land_player_look_up_at_loot, current_coord: {4, 4})

      %Planet.Land{tiles: expected_tiles} =
        Planet.get_visible_land(planet, @midday) |> PlanetLandConverter.from_matrix()

      assert {:ok, %Planet{land: %Planet.Land{tiles: tiles}, current_coord: {2, 2}, great_red_spots: 1}} =
               Planet.crop_land(planet)

      assert Enum.count(tiles) == Enum.count(expected_tiles)
      assert Map.values(tiles) == Map.values(expected_tiles)
    end
  end

  describe "land_size/1" do
    test "retursn land size (cols*rows)" do
      planet = build(:planet, land: @land_player_look_up_at_loot, current_coord: {4, 4})
      assert Planet.land_size(planet) == 100
    end
  end

  describe "interact/2" do
    test "returns talk with up npc" do
      player = build(:player, view_direction: :up)
      planet = build(:planet, land: @land_player_up_close_to_npc, current_coord: {4, 7})
      assert {:ok, %Planet{}, {:talk, @n}} = Planet.interact(planet, player.view_direction)
    end

    test "returns talk with down npc" do
      player = build(:player, view_direction: :down)
      planet = build(:planet, land: @land_player_down_close_to_npc, current_coord: {4, 1})
      assert {:ok, %Planet{}, {:talk, @n}} = Planet.interact(planet, player.view_direction)
    end

    test "returns talk with left npc" do
      player = build(:player, view_direction: :left)
      planet = build(:planet, land: @land_player_right_close_to_npc, current_coord: {4, 1})
      assert {:ok, %Planet{}, {:talk, @n}} = Planet.interact(planet, player.view_direction)
    end

    test "returns talk with right npc" do
      player = build(:player, view_direction: :right)
      planet = build(:planet, land: @land_player_left_close_to_npc, current_coord: {4, 1})
      assert {:ok, %Planet{}, {:talk, @n}} = Planet.interact(planet, player.view_direction)
    end

    test "returns drink radioactive water (up)" do
      player = build(:player, view_direction: :up)
      planet = build(:planet, land: @land_player_up_close_to_water, current_coord: {4, 7})

      assert {:ok, %Planet{}, {:drink, :radioactive_water}} =
               Planet.interact(planet, player.view_direction, forced: true)
    end

    test "returns drink radioactive water (down)" do
      player = build(:player, view_direction: :down)
      planet = build(:planet, land: @land_player_down_close_to_water, current_coord: {4, 1})

      assert {:ok, %Planet{}, {:drink, :radioactive_water}} =
               Planet.interact(planet, player.view_direction, forced: true)
    end

    test "returns drink radioactive water (left)" do
      player = build(:player, view_direction: :left)
      planet = build(:planet, land: @land_player_right_close_to_water, current_coord: {4, 1})

      assert {:ok, %Planet{}, {:drink, :radioactive_water}} =
               Planet.interact(planet, player.view_direction, forced: true)
    end

    test "returns drink radioactive water (right)" do
      player = build(:player, view_direction: :right)
      planet = build(:planet, land: @land_player_left_close_to_water, current_coord: {4, 1})

      assert {:ok, %Planet{}, {:drink, :radioactive_water}} =
               Planet.interact(planet, player.view_direction, forced: true)
    end

    test "returns danger_action confirmation when trying to drink radioactive water" do
      player = build(:player, view_direction: :right)
      planet = build(:planet, land: @land_player_left_close_to_water, current_coord: {4, 1})
      assert {:ok, %Planet{}, {:confirmation, :danger_action}} = Planet.interact(planet, player.view_direction)
    end

    test "opens right door" do
      player = build(:player, view_direction: :right)
      planet = build(:planet, land: @land_player_left_close_to_door, current_coord: {4, 1})

      assert {:ok, %Planet{land: @land_player_left_close_to_open_door}, {:transform, @dl, transform}} =
               Planet.interact(planet, player.view_direction)

      assert transform == List.first(@dl.transforms)
    end

    test "opens left door" do
      player = build(:player, view_direction: :left)
      planet = build(:planet, land: @land_player_right_close_to_door, current_coord: {4, 1})

      assert {:ok, %Planet{land: @land_player_right_close_to_open_door}, {:transform, @dr, transform}} =
               Planet.interact(planet, player.view_direction)

      assert transform == List.first(@dr.transforms)
    end

    test "opens bottom door" do
      player = build(:player, view_direction: :down)
      planet = build(:planet, land: @land_player_down_close_to_door, current_coord: {4, 1})

      assert {:ok, %Planet{land: @land_player_down_close_to_open_door}, {:transform, @du, transform}} =
               Planet.interact(planet, player.view_direction)

      assert transform == List.first(@du.transforms)
    end

    test "opens top door" do
      player = build(:player, view_direction: :up)
      planet = build(:planet, land: @land_player_up_close_to_door, current_coord: {4, 7})

      assert {:ok, %Planet{land: @land_player_up_close_to_open_door}, {:transform, @dd, transform}} =
               Planet.interact(planet, player.view_direction)

      assert transform == List.first(@dd.transforms)
    end

    test "opens locked door" do
      player = build(:player, view_direction: :right)
      planet = build(:planet, land: @land_player_left_close_to_locked_door, current_coord: {4, 1})

      {:tools, required_tools} = Object.fetch_transform!(@dll, @dll_transform.name).transform_requirements

      assert {:ok, %Planet{land: @land_player_left_close_to_locked_door},
              {:confirmation, {:required_tools, ^required_tools}}} =
               Planet.interact(planet, player.view_direction)
    end

    test "opens locked door (with transform_name)" do
      player = build(:player, view_direction: :right)
      planet = build(:planet, land: @land_player_left_close_to_locked_door, current_coord: {4, 1})

      {:tools, required_tools} = Object.fetch_transform!(@dll, @dll_transform.name).transform_requirements

      assert {:ok, %Planet{land: @land_player_left_close_to_locked_door},
              {:confirmation, {:required_tools, ^required_tools}}} =
               Planet.interact(planet, player.view_direction, transform_name: @dll_transform.name)
    end

    test "opens locked door (with transform_name + multiple transforms)" do
      player = build(:player, view_direction: :right)

      planet =
        build(:planet, land: @land_player_left_close_to_locked_door_with_multipe_transforms, current_coord: {4, 1})

      {:tools, required_tools} = Object.fetch_transform!(@dll2, @dll_transform2.name).transform_requirements

      assert {:ok, %Planet{land: @land_player_left_close_to_locked_door_with_multipe_transforms},
              {:confirmation, {:required_tools, ^required_tools}}} =
               Planet.interact(planet, player.view_direction, transform_name: @dll_transform2.name)
    end

    test "closes right door" do
      player = build(:player, view_direction: :right)
      planet = build(:planet, land: @land_player_left_close_to_open_door, current_coord: {4, 1})

      assert {:ok, planet, {:transform, %Object{}, %Object.Transform{}}} =
               Planet.interact(planet, player.view_direction)

      test_closes_door(planet, {4 + 1, 1})
    end

    test "closes left door" do
      player = build(:player, view_direction: :left)
      planet = build(:planet, land: @land_player_right_close_to_open_door, current_coord: {4, 1})

      assert {:ok, planet, {:transform, %Object{}, %Object.Transform{}}} =
               Planet.interact(planet, player.view_direction)

      test_closes_door(planet, {4 - 1, 1})
    end

    test "closes bottom door" do
      player = build(:player, view_direction: :down)
      planet = build(:planet, land: @land_player_down_close_to_open_door, current_coord: {4, 1})

      assert {:ok, planet, {:transform, %Object{}, %Object.Transform{}}} =
               Planet.interact(planet, player.view_direction)

      test_closes_door(planet, {4, 1 + 1})
    end

    test "closes top door" do
      player = build(:player, view_direction: :up)
      planet = build(:planet, land: @land_player_up_close_to_open_door, current_coord: {4, 7})

      assert {:ok, planet, {:transform, %Object{}, %Object.Transform{}}} =
               Planet.interact(planet, player.view_direction)

      test_closes_door(planet, {4, 7 - 1})
    end

    test "returns error when there is nothing to interact with" do
      player = build(:player, view_direction: :down)
      planet = build(:planet, land: @land_player_left_close_to_npc, current_coord: {4, 1})
      assert {:error, :nothing} = Planet.interact(planet, player.view_direction)
    end

    defp test_closes_door(planet, target_coord) do
      assert %Object{} = tile_at(planet.land, target_coord)
    end
  end

  describe "shoot/2" do
    test "damages top enemy (bullet)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :bullet,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :up, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_up_at_enemies, current_coord: {4, 7})

      test_shoot(planet, player, weapon, 1)
    end

    test "damages bottom enemy (bullet)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :bullet,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :down, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_down_at_enemies, current_coord: {4, 1})

      test_shoot(planet, player, weapon, 1)
    end

    test "damages right enemy (bullet)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :bullet,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :right, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_right_at_enemies, current_coord: {2, 4})

      test_shoot(planet, player, weapon, 1)
    end

    test "damages left enemy (bullet)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :bullet,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :left, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_left_at_enemies, current_coord: {7, 4})

      test_shoot(planet, player, weapon, 1)
    end

    test "damages top npc (bullet)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :bullet,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :up, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_up_close_to_npc, current_coord: {4, 7})
      test_shoot(planet, player, weapon, 1, false)
    end

    test "damages bottom npc (bullet)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :bullet,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :down, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_down_close_to_npc, current_coord: {4, 1})

      test_shoot(planet, player, weapon, 1, false)
    end

    test "damages right npc (bullet)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :bullet,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :right, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_left_close_to_npc, current_coord: {4, 1})

      test_shoot(planet, player, weapon, 1, false)
    end

    test "damages left npc (bullet)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :bullet,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :left, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_right_close_to_npc, current_coord: {4, 1})

      test_shoot(planet, player, weapon, 1, false)
    end

    test "damages top enemy (burst)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :burst,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :up, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_up_at_enemies, current_coord: {4, 7})

      test_shoot(planet, player, weapon, 1)
    end

    test "damages bottom enemy (burst)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :burst,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :down, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_down_at_enemies, current_coord: {4, 1})

      test_shoot(planet, player, weapon, 1)
    end

    test "damages right enemy (burst)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :burst,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :right, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_right_at_enemies, current_coord: {2, 4})

      test_shoot(planet, player, weapon, 1)
    end

    test "damages left enemy (burst)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :burst,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :left, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_left_at_enemies, current_coord: {7, 4})

      test_shoot(planet, player, weapon, 1)
    end

    test "damages top npc (burst)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :burst,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :up, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_up_close_to_npc, current_coord: {4, 7})
      test_shoot(planet, player, weapon, 1, false)
    end

    test "damages bottom npc (burst)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :burst,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :down, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_down_close_to_npc, current_coord: {4, 1})

      test_shoot(planet, player, weapon, 1, false)
    end

    test "damages right npc (burst)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :burst,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :right, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_left_close_to_npc, current_coord: {4, 1})

      test_shoot(planet, player, weapon, 1, false)
    end

    test "damages left npc (burst)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :burst,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :left, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_right_close_to_npc, current_coord: {4, 1})

      test_shoot(planet, player, weapon, 1, false)
    end

    test "damages top enemies (shot)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :shot,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :up, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_up_at_enemies, current_coord: {4, 7})

      test_shoot(planet, player, weapon, 7)
    end

    test "damages bottom enemies (shot)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :shot,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :down, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_down_at_enemies, current_coord: {4, 1})

      test_shoot(planet, player, weapon, 7)
    end

    test "damages right enemies (shot)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :shot,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :right, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_right_at_enemies, current_coord: {2, 4})

      test_shoot(planet, player, weapon, 5)
    end

    test "damages left enemies (shot)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :shot,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :left, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_left_at_enemies, current_coord: {7, 4})

      test_shoot(planet, player, weapon, 7)
    end

    test "damages top npc (shot)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :shot,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :up, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_up_close_to_npc, current_coord: {4, 7})
      test_shoot(planet, player, weapon, 1, false)
    end

    test "damages bottom npc (shot)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :shot,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :down, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_down_close_to_npc, current_coord: {4, 1})

      test_shoot(planet, player, weapon, 1, false)
    end

    test "damages right npc (shot)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :shot,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :right, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_left_close_to_npc, current_coord: {4, 1})

      test_shoot(planet, player, weapon, 1, false)
    end

    test "damages left npc (shot)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :shot,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :left, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_right_close_to_npc, current_coord: {4, 1})

      test_shoot(planet, player, weapon, 1, false)
    end

    test "changes killed enemies on monster_body item boxes" do
      weapon =
        build(:weapon,
          damage: 500,
          shooting_distance: 10,
          shooting_type: :shot,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :left, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_left_at_enemies, current_coord: {7, 4})

      {:ok, updated_planet} = test_shoot(planet, player, weapon, 7, _check_damage = false)
      assert_monster_bodies(updated_planet, _monster_bodies_count = 7)
    end

    test "changes killed npc on human_body item boxes" do
      weapon =
        build(:weapon,
          damage: 500,
          shooting_distance: 10,
          shooting_type: :shot,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :up, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_up_close_to_npc, current_coord: {4, 7})

      {:ok, updated_planet} = test_shoot(planet, player, weapon, 1, _check_damage = false)
      assert_human_bodies(updated_planet, _human_bodies_count = 1)
    end

    test "returns miss error" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :shot,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :left, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_up_at_loot, current_coord: {4, 4})

      test_miss(planet, player, weapon)
    end

    test "misses top enemies behind wall (bullet)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :bullet,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :up, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_up_at_enemies_behind_wall, current_coord: {4, 7})

      test_miss(planet, player, weapon)
    end

    test "misses bottom enemies behind wall (bullet)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :bullet,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :down, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_down_at_enemies_behind_wall, current_coord: {4, 1})

      test_miss(planet, player, weapon)
    end

    test "misses left enemies behind wall (bullet)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :bullet,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :left, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_left_at_enemies_behind_wall, current_coord: {7, 4})

      test_miss(planet, player, weapon)
    end

    test "misses right enemies behind wall (bullet)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :bullet,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :right, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_right_at_enemies_behind_wall, current_coord: {2, 4})

      test_miss(planet, player, weapon)
    end

    test "misses top enemies behind wall (shot)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :shot,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :up, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_up_at_enemies_behind_wall, current_coord: {4, 7})

      test_miss(planet, player, weapon)
    end

    test "misses bottom enemies behind wall (shot)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :shot,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :down, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_down_at_enemies_behind_wall, current_coord: {4, 1})

      test_miss(planet, player, weapon)
    end

    test "misses left enemies behind wall (shot)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :shot,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :left, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_left_at_enemies_behind_wall, current_coord: {7, 4})

      test_miss(planet, player, weapon)
    end

    test "misses right enemies behind wall (shot)" do
      weapon =
        build(:weapon,
          damage: 5,
          shooting_distance: 5,
          shooting_type: :shot,
          rounds_loaded: 15,
          magazine_size: 15,
          accuracy: 30
        )

      player =
        build(:player, view_direction: :right, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_right_at_enemies_behind_wall, current_coord: {2, 4})

      test_miss(planet, player, weapon)
    end

    defp test_miss(planet, player, weapon) do
      PlayerManagerMock
      |> expect(:get_equipped_weapon, fn _ -> {:ok, weapon} end)
      |> expect(:update_item, fn ^player, %Weapon{} = updated_weapon ->
        assert_rounds_loaded_decreased(weapon, updated_weapon)
        player
      end)

      assert {:error, :miss, ^player, move_cost} = Planet.shoot(planet, player)
      assert move_cost == weapon.shot_cost
    end

    defp test_shoot(planet, player, weapon, expected_damaged_enemies_count, check_damage \\ true) do
      expected_damage = Player.weapon_damage(player)

      PlayerManagerMock
      |> expect(:get_equipped_weapon, fn _ -> {:ok, weapon} end)
      |> expect(:update_item, fn ^player, %Weapon{} = updated_weapon ->
        assert_rounds_loaded_decreased(weapon, updated_weapon)
        player
      end)
      |> expect(:weapon_damage, fn _ -> expected_damage end)

      assert {:ok, {updated_planet, ^player, damaged_enemies, move_cost}} = Planet.shoot(planet, player)

      assert Enum.count(damaged_enemies) == expected_damaged_enemies_count
      assert move_cost == weapon.shot_cost

      if check_damage do
        assert_damaged_enemies(updated_planet, damaged_enemies, expected_damage)
      end

      {:ok, updated_planet}
    end
  end

  describe "unload_item_box_weapon/3" do
    test "updates right item box" do
      planet = build(:planet, land: @land_player_look_right_at_loot, current_coord: {4, 4})
      player = build(:player, view_direction: :right)

      test_unload_item_box_weapon(planet, player, {4 + 1, 4})
    end

    test "updates left item box" do
      planet = build(:planet, land: @land_player_look_left_at_loot, current_coord: {4, 4})
      player = build(:player, view_direction: :left)

      test_unload_item_box_weapon(planet, player, {4 - 1, 4})
    end

    test "updates top item box" do
      planet = build(:planet, land: @land_player_look_up_at_loot, current_coord: {4, 4})
      player = build(:player, view_direction: :up)

      test_unload_item_box_weapon(planet, player, {4, 4 - 1})
    end

    test "updates bottom item box" do
      planet = build(:planet, land: @land_player_look_down_at_loot, current_coord: {4, 4})
      player = build(:player, view_direction: :down)

      test_unload_item_box_weapon(planet, player, {4, 4 + 1})
    end

    test "updates item box under player" do
      planet = build(:planet, land: @land_player_look_down_at_loot, current_coord: {4, 4})
      player = build(:player, view_direction: :down, stand_on: @ib2)

      weapon = Enum.find(@ib2.items, fn item -> Item.item_type(item) == :weapon end)
      caliber = weapon.caliber
      ammo_count = weapon.rounds_loaded

      PlayerManagerMock
      |> expect(:stand_on, fn player,
                              %ItemBox{items: [%Ammo{caliber: ^caliber, count: ^ammo_count}, %Weapon{rounds_loaded: 0}]} ->
        player
      end)

      assert {:ok, ^planet, ^player, %ItemBox{}, %Weapon{}} = Planet.unload_item_box_weapon(planet, player, weapon.uuid)
    end

    test "retunrs {:error, :noting} when there is not item box next to player view direction" do
      planet = build(:planet, land: @land_player_look_down_at_loot, current_coord: {4, 4})
      player = build(:player, view_direction: :up)
      item_uuid = 0

      assert {:error, :nothing} = Planet.unload_item_box_weapon(planet, player, item_uuid)
    end

    test "returns {:error, :no_item} when there is no item with given uuid" do
      planet = build(:planet, land: @land_player_look_down_at_loot, current_coord: {4, 4})
      player = build(:player, view_direction: :down)
      item_uuid = 10

      assert {:error, :no_item} = Planet.unload_item_box_weapon(planet, player, item_uuid)
    end

    defp test_unload_item_box_weapon(planet, player, target_coord) do
      weapon = Enum.find(@ib.items, fn item -> Item.item_type(item) == :weapon end)
      caliber = weapon.caliber
      ammo_count = weapon.rounds_loaded

      assert {:ok, updated_planet, ^player,
              %ItemBox{items: [%Ammo{caliber: ^caliber, count: ^ammo_count}, %Weapon{rounds_loaded: 0} = weapon]} =
                updated_item_box, weapon} =
               Planet.unload_item_box_weapon(planet, player, weapon.uuid)

      assert tile_at(updated_planet.land, target_coord) == updated_item_box
    end
  end

  defp assert_rounds_loaded_decreased(weapon, updated_weapon) do
    n =
      case weapon.shooting_type do
        :burst -> @burst_bullets_per_shot
        _ -> 1
      end

    assert updated_weapon.rounds_loaded == weapon.rounds_loaded - n
  end

  defp assert_damaged_enemies(planet, damaged_enemies, expected_damage) when is_list(damaged_enemies) do
    for {enemy, damage} <- damaged_enemies do
      assert damage == expected_damage

      enemy = %Enemy{} = find_enemy(planet, enemy)
      assert enemy.health == @initial_enemy_health - damage
    end
  end

  defp assert_monster_bodies(planet, expected_monster_bodies_count) do
    monster_bodies =
      planet.land.tiles
      |> Enum.filter(fn
        {_, %ItemBox{type: :monster_body}} -> true
        _ -> false
      end)

    assert Enum.count(monster_bodies) == expected_monster_bodies_count
  end

  defp assert_human_bodies(planet, expected_human_bodies_count) do
    human_bodies =
      planet.land.tiles
      |> Enum.filter(fn
        {_, %ItemBox{type: :human_body}} -> true
        _ -> false
      end)

    assert Enum.count(human_bodies) == expected_human_bodies_count
  end

  defp find_enemy(planet, enemy) do
    planet.land.tiles
    |> Enum.find_value(fn
      {_, ^enemy} -> enemy
      _ -> nil
    end)
  end

  defp tile_at(land, {x, y}) do
    Map.get(land.tiles, {x, y})
  end

  defp change_tile(land, {x, y}, new_tile) do
    List.replace_at(land, x, List.replace_at(Enum.at(land, x), y, new_tile))
  end

  defp build_player_stand_on(tile), do: build(:player, stand_on: tile)

  defp coords_distance({x1, y1}, {x2, y2}) do
    abs(x1 - x2) + abs(y1 - y2)
  end
end
