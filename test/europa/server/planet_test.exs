defmodule Europa.Server.PlanetTest do
  use Europa.DataCase, async: true
  use ExUnitProperties

  alias Europa.Server.Planet
  alias Europa.Server.Player
  alias Europa.Server.Enemy
  alias Europa.Server.Loot.ItemBox
  alias Europa.Support.PlanetLandConverter

  import Europa.Tools.Conf

  @max_accuracy fetch_config!([:weapons, :max_accuracy])
  @burst_bullets_per_shot fetch_config!([:weapons, :burst_bullets_per_shot])

  @initial_enemy_health 100

  @s Planet.snow()
  @sb Planet.snow_blood()

  @i Planet.ice()
  @icb Planet.ice_blood()

  @p Planet.path()
  @pb Planet.path_blood()

  @w Planet.water()

  @pl Planet.player()
  @ib build(:loot_item_box, items: [build(:weapon)])

  @en build(:enemy, name: "E1", move_distance: 2, health: @initial_enemy_health)
  @en2 build(:enemy, name: "E2", move_distance: 2, health: @initial_enemy_health)
  @en3 build(:enemy, name: "E3", move_distance: 2, health: @initial_enemy_health)
  @en4 build(:enemy, name: "E4", move_distance: 2, health: @initial_enemy_health)
  @en5 build(:enemy, name: "E5", move_distance: 2, health: @initial_enemy_health)
  @en6 build(:enemy, name: "E6", move_distance: 2, health: @initial_enemy_health)
  @en7 build(:enemy, name: "E7", move_distance: 2, health: @initial_enemy_health)

  @year_from fetch_config!([Planet, :year, :from])
  @year_to fetch_config!([Planet, :year, :to])

  @move_costs %{
    @s => fetch_config!([Planet, :move_costs, :snow]),
    @p => fetch_config!([Planet, :move_costs, :path]),
    @i => fetch_config!([Planet, :move_costs, :ice])
  }

  @tiles [
    @s,
    @w,
    @i,
    @p,
    @ib
  ]

  @land_player_look_up_at_loot [
                                 [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                 [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                 [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                 [@s, @s, @s, @s, @ib, @s, @s, @s, @s, @s],
                                 [@s, @s, @s, @s, @pl, @i, @s, @s, @s, @s],
                                 [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                 [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                 [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                 [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                 [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s]
                               ]
                               |> PlanetLandConverter.from_matrix()

  @land_player_look_down_at_loot [
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @pl, @i, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @ib, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s]
                                 ]
                                 |> PlanetLandConverter.from_matrix()

  @land_player_look_right_at_loot [
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @pl, @ib, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s]
                                  ]
                                  |> PlanetLandConverter.from_matrix()

  @land_player_look_left_at_loot [
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @ib, @pl, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s]
                                 ]
                                 |> PlanetLandConverter.from_matrix()

  @land_player_near_left_border [
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                  [@s, @s, @pl, @s, @s, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s]
                                ]
                                |> PlanetLandConverter.from_matrix()

  @land_player_near_right_border [
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @pl, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s]
                                 ]
                                 |> PlanetLandConverter.from_matrix()

  @land_player_near_top_border [
                                 [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                 [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                 [@s, @s, @s, @s, @pl, @s, @s, @s, @s, @s],
                                 [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                 [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                 [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                 [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                 [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                 [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                 [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s]
                               ]
                               |> PlanetLandConverter.from_matrix()

  @land_player_near_down_border [
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @pl, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s]
                                ]
                                |> PlanetLandConverter.from_matrix()

  @land_player_look_up_at_enemy [
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @en, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @pl, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                  [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s]
                                ]
                                |> PlanetLandConverter.from_matrix()

  @land_player_up_close_to_enemy [
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @en, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @pl, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                   [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s]
                                 ]
                                 |> PlanetLandConverter.from_matrix()

  @land_player_look_down_at_enemy [
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @pl, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @en, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s]
                                  ]
                                  |> PlanetLandConverter.from_matrix()

  @land_player_down_close_to_enemy [
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @pl, @s, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @en, @s, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s]
                                   ]
                                   |> PlanetLandConverter.from_matrix()

  @land_player_look_right_at_enemy [
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @pl, @s, @s, @en, @s, @s],
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s]
                                   ]
                                   |> PlanetLandConverter.from_matrix()

  @land_player_left_close_to_enemy [
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @pl, @en, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                     [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s]
                                   ]
                                   |> PlanetLandConverter.from_matrix()

  @land_player_look_left_at_enemy [
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @en, @s, @s, @pl, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s]
                                  ]
                                  |> PlanetLandConverter.from_matrix()

  @land_player_right_close_to_enemy [
                                      [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                      [@s, @s, @s, @en, @pl, @s, @s, @s, @s, @s],
                                      [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                      [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                      [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                      [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                      [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                      [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                      [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                      [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s]
                                    ]
                                    |> PlanetLandConverter.from_matrix()

  @land_player_look_up_at_enemies [
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @en, @en2, @en3, @en4, @en5, @en6, @en7, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @pl, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                    [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s]
                                  ]
                                  |> PlanetLandConverter.from_matrix()

  @land_player_look_down_at_enemies [
                                      [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                      [@s, @s, @s, @s, @pl, @s, @s, @s, @s, @s],
                                      [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                      [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                      [@s, @en, @en2, @en3, @en4, @en5, @en6, @en7, @s, @s],
                                      [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                      [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                      [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                      [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                      [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s]
                                    ]
                                    |> PlanetLandConverter.from_matrix()

  @land_player_look_right_at_enemies [
                                       [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                       [@s, @s, @s, @s, @en, @s, @s, @s, @s, @s],
                                       [@s, @s, @s, @s, @en2, @s, @s, @s, @s, @s],
                                       [@s, @s, @s, @s, @en3, @s, @s, @s, @s, @s],
                                       [@s, @s, @pl, @s, @en4, @s, @s, @s, @s, @s],
                                       [@s, @s, @s, @s, @en5, @s, @s, @s, @s, @s],
                                       [@s, @s, @s, @s, @en6, @s, @s, @s, @s, @s],
                                       [@s, @s, @s, @s, @en7, @s, @s, @s, @s, @s],
                                       [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                       [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s]
                                     ]
                                     |> PlanetLandConverter.from_matrix()

  @land_player_look_left_at_enemies [
                                      [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                      [@s, @s, @s, @s, @en, @s, @s, @s, @s, @s],
                                      [@s, @s, @s, @s, @en2, @s, @s, @s, @s, @s],
                                      [@s, @s, @s, @s, @en3, @s, @s, @s, @s, @s],
                                      [@s, @s, @s, @s, @en4, @s, @s, @pl, @s, @s],
                                      [@s, @s, @s, @s, @en5, @s, @s, @s, @s, @s],
                                      [@s, @s, @s, @s, @en6, @s, @s, @s, @s, @s],
                                      [@s, @s, @s, @s, @en7, @s, @s, @s, @s, @s],
                                      [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s],
                                      [@s, @s, @s, @s, @s, @s, @s, @s, @s, @s]
                                    ]
                                    |> PlanetLandConverter.from_matrix()

  setup do
    planet = Planet.new()
    {:ok, planet: planet}
  end

  describe "new/0" do
    property "creates planet" do
      check all(_n <- StreamData.integer(1..10)) do
        assert %Planet{land: land, current_coord: {x, y}, year: year} = Planet.new()
        assert %Planet.Land{tiles: %{}} = land
        assert is_integer(x)
        assert is_integer(y)

        assert year in @year_from..@year_to
      end
    end
  end

  describe "readable_tile_name/1" do
    test "returns string name for tile" do
      for tile <- @tiles do
        assert Planet.readable_tile_name(tile) |> is_binary()
      end
    end
  end

  describe "get_visible_land/1" do
    setup do
      planet = build(:planet, land: @land_player_look_up_at_loot, current_coord: {4, 4})
      {:ok, planet: planet}
    end

    test "returns visible part of land (depends on view_distance config)", %{planet: planet} do
      expected_visible_land =
        [
          [@s, @s, @s, @s, @s],
          [@s, @s, @ib, @s, @s],
          [@s, @s, @pl, @i, @s],
          [@s, @s, @s, @s, @s],
          [@s, @s, @s, @s, @s]
        ]

      assert Planet.get_visible_land(planet) == expected_visible_land
    end
  end

  describe "move/2" do
    test "moves player right" do
      planet =
        %Planet{current_coord: {x, y}} = build(:planet, land: @land_player_look_up_at_loot, current_coord: {4, 4})

      assert {:moved, %Planet{current_coord: {x2, ^y}} = updated_planet, move_cost, _} = Planet.move(planet, :right, @i)
      assert x2 == x + 1
      assert move_cost == Map.fetch!(@move_costs, @i)

      expected_visible_land =
        [
          [@s, @s, @s, @s, @s],
          [@s, @ib, @s, @s, @s],
          [@s, @i, @pl, @s, @s],
          [@s, @s, @s, @s, @s],
          [@s, @s, @s, @s, @s]
        ]

      assert Planet.get_visible_land(updated_planet) == expected_visible_land
    end

    test "moves player left" do
      planet =
        %Planet{current_coord: {x, y}} = build(:planet, land: @land_player_look_up_at_loot, current_coord: {4, 4})

      assert {:moved, %Planet{current_coord: {x2, ^y}} = updated_planet, move_cost, _} = Planet.move(planet, :left, @s)
      assert x2 == x - 1
      assert move_cost == Map.fetch!(@move_costs, @s)

      expected_visible_land =
        [
          [@s, @s, @s, @s, @s],
          [@s, @s, @s, @ib, @s],
          [@s, @s, @pl, @p, @i],
          [@s, @s, @s, @s, @s],
          [@s, @s, @s, @s, @s]
        ]

      assert Planet.get_visible_land(updated_planet) == expected_visible_land
    end

    test "moves player up" do
      planet =
        %Planet{current_coord: {x, y}} = build(:planet, land: @land_player_look_right_at_loot, current_coord: {4, 4})

      assert {:moved, %Planet{current_coord: {^x, y2}} = updated_planet, move_cost, _} = Planet.move(planet, :up, @s)
      assert y2 == y - 1
      assert move_cost == Map.fetch!(@move_costs, @s)

      expected_visible_land =
        [
          [@s, @s, @s, @s, @s],
          [@s, @s, @s, @s, @s],
          [@s, @s, @pl, @s, @s],
          [@s, @s, @p, @ib, @s],
          [@s, @s, @s, @s, @s]
        ]

      assert Planet.get_visible_land(updated_planet) == expected_visible_land
    end

    test "not moves in not movable tile" do
      planet = build(:planet, land: @land_player_look_right_at_loot, current_coord: {4, 4})
      assert {:stay, @ib} = Planet.move(planet, :right, @s)
    end

    test "generates left column" do
      planet =
        %Planet{current_coord: {x, y}, land: land} =
        build(:planet, land: @land_player_near_left_border, current_coord: {2, 4})

      assert {:moved, %Planet{current_coord: {x2, ^y}, land: updated_land}, _, _} = Planet.move(planet, :left, @s)

      assert x - x2 == 1
      assert updated_land.min_x == land.min_x - 1
    end

    test "generates right column" do
      planet =
        %Planet{current_coord: {x, y}, land: land} =
        build(:planet, land: @land_player_near_right_border, current_coord: {7, 4})

      assert {:moved, %Planet{current_coord: {x2, ^y}, land: updated_land}, _, _} = Planet.move(planet, :right, @s)
      assert x2 == x + 1

      assert updated_land.max_x - land.max_x == 1
    end

    test "generates top row" do
      planet =
        %Planet{current_coord: {x, y}, land: land} =
        build(:planet, land: @land_player_near_top_border, current_coord: {4, 2})

      assert {:moved, %Planet{current_coord: {^x, y2}, land: updated_land}, _, _} = Planet.move(planet, :up, @s)
      assert y2 == y - 1

      assert updated_land.min_y == land.min_y - 1
    end

    test "generates bottom row" do
      planet =
        %Planet{current_coord: {x, y}, land: land} =
        build(:planet, land: @land_player_near_down_border, current_coord: {4, 7})

      assert {:moved, %Planet{current_coord: {^x, y2}, land: updated_land}, _, _} = Planet.move(planet, :down, @s)
      assert y2 == y + 1

      assert updated_land.max_y == land.max_y + 1
    end
  end

  describe "tick/2" do
    test "enemy moves down to player" do
      planet = build(:planet, land: @land_player_look_up_at_enemy, current_coord: {4, 7})

      assert {:ok, %Planet{land: updated_land}, [%Planet.Action{subject: @en, action_type: :chasing}]} =
               Planet.tick(planet, 1)

      assert updated_land == @land_player_up_close_to_enemy
    end

    test "enemy moves up to player" do
      planet = build(:planet, land: @land_player_look_down_at_enemy, current_coord: {4, 1})

      assert {:ok, %Planet{land: updated_land}, [%Planet.Action{subject: @en, action_type: :chasing}]} =
               Planet.tick(planet, 1)

      assert updated_land == @land_player_down_close_to_enemy
    end

    test "enemy moves left to player" do
      planet = build(:planet, land: @land_player_look_right_at_enemy, current_coord: {4, 1})

      assert {:ok, %Planet{land: updated_land}, [%Planet.Action{subject: @en, action_type: :chasing}]} =
               Planet.tick(planet, 1)

      assert updated_land == @land_player_left_close_to_enemy
    end

    test "enemy moves right to player" do
      planet = build(:planet, land: @land_player_look_left_at_enemy, current_coord: {4, 1})

      assert {:ok, %Planet{land: updated_land}, [%Planet.Action{subject: @en, action_type: :chasing}]} =
               Planet.tick(planet, 1)

      assert updated_land == @land_player_right_close_to_enemy
    end

    @tag perfomance: true
    test "tick is fast enough" do
      acceptable_time_ms = 150

      cols = 1_000
      rows = 1_000

      moves_count = 3

      player_coord = {px, py} = {div(cols, 2), div(cols, 2)}

      # generate land with enemies around player
      land =
        for _ <- 1..cols do
          for _ <- 1..rows do
            @s
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

    test "retunrs {:error, :noting} when there is not item box next to player view direction" do
      planet = build(:planet, land: @land_player_look_right_at_loot, current_coord: {4, 4})
      assert {:error, :nothing} = Planet.loot(planet, build(:player, view_direction: :left))
    end
  end

  describe "take_loot/3" do
    test "opens right item box" do
      planet = build(:planet, land: @land_player_look_right_at_loot, current_coord: {4, 4})
      player = build(:player, view_direction: :right)

      item = Enum.random(@ib.items)

      assert {:ok, updated_planet, %Player{inventory: [^item]}, %ItemBox{items: []}} =
               Planet.take_loot(planet, player, item.uuid)

      assert %ItemBox{items: []} = tile_at(updated_planet.land, {4 + 1, 4})
    end

    test "opens left item box" do
      planet = build(:planet, land: @land_player_look_left_at_loot, current_coord: {4, 4})
      player = build(:player, view_direction: :left)

      item = Enum.random(@ib.items)

      assert {:ok, updated_planet, %Player{inventory: [^item]}, %ItemBox{items: []}} =
               Planet.take_loot(planet, player, item.uuid)

      assert %ItemBox{items: []} = tile_at(updated_planet.land, {4 - 1, 4})
    end

    test "opens top item box" do
      planet = build(:planet, land: @land_player_look_up_at_loot, current_coord: {4, 4})
      player = build(:player, view_direction: :up)

      item = Enum.random(@ib.items)

      assert {:ok, updated_planet, %Player{inventory: [^item]}, %ItemBox{items: []}} =
               Planet.take_loot(planet, player, item.uuid)

      assert %ItemBox{items: []} = tile_at(updated_planet.land, {4, 4 - 1})
    end

    test "opens bottom item box" do
      planet = build(:planet, land: @land_player_look_down_at_loot, current_coord: {4, 4})
      player = build(:player, view_direction: :down)

      item = Enum.random(@ib.items)

      assert {:ok, updated_planet, %Player{inventory: [^item]}, %ItemBox{items: []}} =
               Planet.take_loot(planet, player, item.uuid)

      assert %ItemBox{items: []} = tile_at(updated_planet.land, {4, 4 + 1})
    end

    test "retunrs {:error, :noting} when there is not item box next to player view direction" do
      planet = build(:planet, land: @land_player_look_down_at_loot, current_coord: {4, 4})
      player = build(:player, view_direction: :up)
      item_index = 0

      assert {:error, :nothing} = Planet.take_loot(planet, player, item_index)
    end

    test "returns {:error, :no_item} when there is no item with given index" do
      planet = build(:planet, land: @land_player_look_down_at_loot, current_coord: {4, 4})
      player = build(:player, view_direction: :down)
      item_index = 10

      assert {:error, :no_item} = Planet.take_loot(planet, player, item_index)
    end

    test "returns {:error, :full_inventory} when player inventory is full" do
      planet = build(:planet, land: @land_player_look_down_at_loot, current_coord: {4, 4})
      player = build(:player, view_direction: :down, inventory_size: 2, inventory: build_list(2, :weapon))

      item = Enum.random(@ib.items)

      assert {:error, :full_inventory} = Planet.take_loot(planet, player, item.uuid)
    end
  end

  describe "crop_land/1" do
    test "crops planet land to size of visible land" do
      planet = build(:planet, land: @land_player_look_up_at_loot, current_coord: {4, 4})
      %Planet.Land{tiles: expected_tiles} = Planet.get_visible_land(planet) |> PlanetLandConverter.from_matrix()

      assert {:ok, %Planet{land: %Planet.Land{tiles: tiles}, current_coord: {4, 4}}} = Planet.crop_land(planet)
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

  describe "blood_tile/1" do
    test "returns bloody version of given tile" do
      tiles = [
        {@s, @sb},
        {@i, @icb},
        {@p, @pb}
      ]

      for {tile, blood_tile} <- tiles do
        assert Planet.blood_tile(tile) == blood_tile
      end
    end

    test "returns unchanged tile if no blood version of it" do
      assert Planet.blood_tile(@w) == @w
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

      expected_damage = weapon.damage

      player =
        build(:player, view_direction: :up, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_up_at_enemies, current_coord: {4, 7})

      assert {:ok, {updated_planet, updated_player, damaged_enemies, move_cost}} = Planet.shoot(planet, player)

      assert Enum.count(damaged_enemies) == 1
      assert move_cost == weapon.shot_cost

      assert_rounds_loaded_decreased(updated_player, weapon)
      assert_damaged_enemies(updated_planet, damaged_enemies, expected_damage)
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

      expected_damage = weapon.damage

      player =
        build(:player, view_direction: :down, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_down_at_enemies, current_coord: {4, 1})

      assert {:ok, {updated_planet, updated_player, damaged_enemies, move_cost}} = Planet.shoot(planet, player)

      assert Enum.count(damaged_enemies) == 1
      assert move_cost == weapon.shot_cost

      assert_rounds_loaded_decreased(updated_player, weapon)
      assert_damaged_enemies(updated_planet, damaged_enemies, expected_damage)
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

      expected_damage = weapon.damage

      player =
        build(:player, view_direction: :right, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_right_at_enemies, current_coord: {2, 4})

      assert {:ok, {updated_planet, updated_player, damaged_enemies, move_cost}} = Planet.shoot(planet, player)

      assert Enum.count(damaged_enemies) == 1
      assert move_cost == weapon.shot_cost

      assert_rounds_loaded_decreased(updated_player, weapon)
      assert_damaged_enemies(updated_planet, damaged_enemies, expected_damage)
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

      expected_damage = weapon.damage

      player =
        build(:player, view_direction: :left, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_left_at_enemies, current_coord: {7, 4})

      assert {:ok, {updated_planet, updated_player, damaged_enemies, move_cost}} = Planet.shoot(planet, player)

      assert Enum.count(damaged_enemies) == 1
      assert move_cost == weapon.shot_cost

      assert_rounds_loaded_decreased(updated_player, weapon)
      assert_damaged_enemies(updated_planet, damaged_enemies, expected_damage)
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

      expected_damage = weapon.damage * @burst_bullets_per_shot

      player =
        build(:player, view_direction: :up, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_up_at_enemies, current_coord: {4, 7})

      assert {:ok, {updated_planet, updated_player, damaged_enemies, move_cost}} = Planet.shoot(planet, player)

      assert Enum.count(damaged_enemies) == 1
      assert move_cost == weapon.shot_cost

      assert_rounds_loaded_decreased(updated_player, weapon)
      assert_damaged_enemies(updated_planet, damaged_enemies, expected_damage)
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

      expected_damage = weapon.damage * @burst_bullets_per_shot

      player =
        build(:player, view_direction: :down, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_down_at_enemies, current_coord: {4, 1})

      assert {:ok, {updated_planet, updated_player, damaged_enemies, move_cost}} = Planet.shoot(planet, player)

      assert Enum.count(damaged_enemies) == 1
      assert move_cost == weapon.shot_cost

      assert_rounds_loaded_decreased(updated_player, weapon)
      assert_damaged_enemies(updated_planet, damaged_enemies, expected_damage)
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

      expected_damage = weapon.damage * @burst_bullets_per_shot

      player =
        build(:player, view_direction: :right, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_right_at_enemies, current_coord: {2, 4})

      assert {:ok, {updated_planet, updated_player, damaged_enemies, move_cost}} = Planet.shoot(planet, player)

      assert Enum.count(damaged_enemies) == 1
      assert move_cost == weapon.shot_cost

      assert_rounds_loaded_decreased(updated_player, weapon)
      assert_damaged_enemies(updated_planet, damaged_enemies, expected_damage)
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

      expected_damage = weapon.damage * @burst_bullets_per_shot

      player =
        build(:player, view_direction: :left, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_left_at_enemies, current_coord: {7, 4})

      assert {:ok, {updated_planet, updated_player, damaged_enemies, move_cost}} = Planet.shoot(planet, player)

      assert Enum.count(damaged_enemies) == 1
      assert move_cost == weapon.shot_cost

      assert_rounds_loaded_decreased(updated_player, weapon)
      assert_damaged_enemies(updated_planet, damaged_enemies, expected_damage)
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

      expected_damage = weapon.damage

      player =
        build(:player, view_direction: :up, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_up_at_enemies, current_coord: {4, 7})

      assert {:ok, {updated_planet, updated_player, damaged_enemies, move_cost}} = Planet.shoot(planet, player)

      assert Enum.count(damaged_enemies) == 5
      assert move_cost == weapon.shot_cost

      assert_rounds_loaded_decreased(updated_player, weapon)
      assert_damaged_enemies(updated_planet, damaged_enemies, expected_damage)
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

      expected_damage = weapon.damage

      player =
        build(:player, view_direction: :down, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_down_at_enemies, current_coord: {4, 1})

      assert {:ok, {updated_planet, updated_player, damaged_enemies, move_cost}} = Planet.shoot(planet, player)

      assert Enum.count(damaged_enemies) == 5
      assert move_cost == weapon.shot_cost

      assert_rounds_loaded_decreased(updated_player, weapon)
      assert_damaged_enemies(updated_planet, damaged_enemies, expected_damage)
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

      expected_damage = weapon.damage

      player =
        build(:player, view_direction: :right, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_right_at_enemies, current_coord: {2, 4})

      assert {:ok, {updated_planet, updated_player, damaged_enemies, move_cost}} = Planet.shoot(planet, player)

      assert Enum.count(damaged_enemies) == 5
      assert move_cost == weapon.shot_cost

      assert_rounds_loaded_decreased(updated_player, weapon)
      assert_damaged_enemies(updated_planet, damaged_enemies, expected_damage)
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

      expected_damage = weapon.damage

      player =
        build(:player, view_direction: :left, accuracy: @max_accuracy, weapon_uuid: weapon.uuid, inventory: [weapon])

      planet = build(:planet, land: @land_player_look_left_at_enemies, current_coord: {7, 4})

      assert {:ok, {updated_planet, updated_player, damaged_enemies, move_cost}} = Planet.shoot(planet, player)

      assert Enum.count(damaged_enemies) == 5
      assert move_cost == weapon.shot_cost

      assert_rounds_loaded_decreased(updated_player, weapon)
      assert_damaged_enemies(updated_planet, damaged_enemies, expected_damage)
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

      assert {:ok, {updated_planet, updated_player, damaged_enemies, move_cost}} = Planet.shoot(planet, player)

      assert Enum.count(damaged_enemies) == 5
      assert move_cost == weapon.shot_cost

      assert_rounds_loaded_decreased(updated_player, weapon)
      assert_monster_bodies(updated_planet, _monster_bodies_count = 5)
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

      assert {:error, :miss, updated_player, move_cost} = Planet.shoot(planet, player)
      assert move_cost == weapon.shot_cost

      assert_rounds_loaded_decreased(updated_player, weapon)
    end
  end

  defp assert_rounds_loaded_decreased(player, weapon) do
    assert %Player{inventory: [updated_weapon]} = player

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
end
