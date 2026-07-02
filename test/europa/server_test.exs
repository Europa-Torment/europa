defmodule Europa.ServerTest do
  use Europa.DataCase

  alias Europa.Games
  alias Europa.Server
  alias Europa.Server.Player
  alias Europa.Server.Planet
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Chat
  alias Europa.Server.PlanetManagerMock
  alias Europa.Server.PlayerManagerMock
  alias Europa.Server.Errors
  alias Europa.Support.PlanetLandConverter

  import Europa.Tools.Conf

  @snow Tiles.tile(:snow).atom_value
  @water Tiles.tile(:water).atom_value

  @player_stand_on_tile @snow

  @direction :up
  @direction2 :down

  @crop_size fetch_config!([Planet, :crop_land_size])
  @craft_moves_count fetch_config!([:game_params, :craft_moves_count])

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    PlanetManagerMock
    |> stub(:new, fn _year -> build(:planet) end)
    |> stub(:player_initial_stand_on_tile, fn _ -> @snow end)
    |> stub(:land_size, fn _ -> 1 end)

    PlayerManagerMock
    |> stub(:new, fn character ->
      build(:player, character: character, stand_on: @player_stand_on_tile, max_weight: 20.0)
    end)
    |> stub(:stand_on, fn player, @snow -> Player.change_view_direction(player, @direction) end)
    |> stub(:add_item, fn player, _ -> {:ok, player} end)
    |> stub(:equip_item, fn player, _ -> {:ok, player} end)

    {:ok, server} = Server.start_link(Ecto.UUID.generate())
    planet = build(:planet)
    item_box = build(:loot_item_box)

    {:ok, server: server, planet: planet, item_box: item_box}
  end

  describe "get_player/1" do
    test "returns player", %{server: server} do
      assert %Player{} = Server.get_player(server)
    end
  end

  describe "get_planet/1" do
    test "returns planet", %{server: server} do
      assert %Planet{} = Server.get_planet(server)
    end
  end

  describe "get_chat/1" do
    test "returns chat", %{server: server} do
      assert %Chat{} = Server.get_chat(server)
    end
  end

  describe "get_inventory/2" do
    test "returns players inventory", %{server: server} do
      type = :weapon
      inventory = build(:player).inventory

      PlayerManagerMock
      |> expect(:get_inventory, fn %Player{}, ^type ->
        inventory
      end)

      assert Server.get_inventory(server, type) == inventory
    end
  end

  describe "get_visible_planet/1" do
    test "returns visible planet", %{server: server, planet: planet} do
      land = PlanetLandConverter.to_matrix(planet.land)

      PlanetManagerMock
      |> expect(:get_visible_land, fn _planet, _current_time ->
        land
      end)

      assert Server.get_visible_planet(server) == land
    end
  end

  describe "get_current_time/1" do
    test "returns current time", %{server: server} do
      assert {year, days, time} = Server.get_current_time(server)
      assert is_integer(year)
      assert is_integer(days)
      assert [_, _] = String.split(time, ":")
    end
  end

  describe "interact/1" do
    test "returns interaction (talk)", %{server: server} do
      interaction = {:talk, build(:npc)}

      PlanetManagerMock
      |> expect(:interact, fn %Planet{} = planet, %Player{}, _opts ->
        {:ok, planet, interaction}
      end)

      assert Server.interact(server) == {:ok, interaction}
    end

    test "returns interaction (drink radioactive water)", %{server: server} do
      interaction = {:drink, :radioactive_water}

      PlanetManagerMock
      |> expect(:interact, fn %Planet{} = planet, %Player{}, _opts ->
        {:ok, planet, interaction}
      end)

      PlayerManagerMock
      |> expect(:increase_thirst, fn %Player{} = player, -10 -> player end)
      |> expect(:increase_radiation, fn %Player{} = player, 10 -> player end)

      assert Server.interact(server) == {:ok, interaction}
    end

    test "returns interaction (transform)", %{server: server} do
      interaction = {:transform, build(:object)}

      PlanetManagerMock
      |> expect(:interact, fn %Planet{} = planet, %Player{}, _opts ->
        {:ok, planet, interaction}
      end)

      assert Server.interact(server) == {:ok, interaction}
    end

    test "returns confirmation (danger_action)", %{server: server} do
      interaction = {:confirmation, :danger_action}

      PlanetManagerMock
      |> expect(:interact, fn %Planet{} = planet, %Player{}, _opts ->
        {:ok, planet, interaction}
      end)

      assert Server.interact(server) == {:ok, interaction}
    end

    test "returns confirmation (required_tools)", %{server: server} do
      interaction = {:confirmation, {:required_tools, build_list(2, :tool)}}

      PlanetManagerMock
      |> expect(:interact, fn %Planet{} = planet, %Player{}, _opts ->
        {:ok, planet, interaction}
      end)

      assert Server.interact(server) == {:ok, interaction}
    end

    test "returns nothing error", %{server: server} do
      error = {:error, :nothing}

      PlanetManagerMock
      |> expect(:interact, fn %Planet{}, %Player{}, _opts ->
        error
      end)

      assert Server.interact(server) == error
    end
  end

  describe "move/2" do
    test "returns success response (moved)", %{server: server, planet: planet} do
      moves_count = 10
      action = build(:action)
      action2 = build(:action, subject: :player, action_type: :get_cold)

      PlanetManagerMock
      |> expect(:move, fn _planet, @direction, %Player{} -> {:moved, planet, moves_count, @snow} end)
      |> expect(:readable_tile_name, fn _tile -> "snow" end)
      |> expect(:tick, fn %Planet{}, tick_moves_count ->
        assert_moves_count(moves_count, tick_moves_count)
        {:ok, planet, [action]}
      end)

      PlayerManagerMock
      |> expect(:weight_ratio, 2, fn %Player{} -> 0 end)
      |> stub(:stand_on, fn %Player{} = player, tile ->
        struct!(player, stand_on: tile)
      end)
      |> expect(:take_damage, fn %Player{} = player, damage ->
        assert damage == action.subject.damage
        player
      end)
      |> expect(:tick, fn %Player{} = player, tick_moves_count ->
        assert_moves_count(moves_count, tick_moves_count)
        {:ok, player, [action2]}
      end)

      assert {:moved, :normal} = Server.move(server, @direction)
      assert_chat_message(server, :regular, "You walked at snow, it took")
      assert_chat_message(server, :danger, "#{action.subject.name} is attacking you!")
    end

    test "returns success response (moved, change direction)", %{server: server, planet: planet} do
      moves_count = 1

      PlanetManagerMock
      |> expect(:readable_tile_name, fn _tile -> "snow" end)
      |> expect(:tick, fn %Planet{}, tick_moves_count ->
        assert_moves_count(moves_count, tick_moves_count)
        {:ok, planet, []}
      end)

      PlayerManagerMock
      |> expect(:change_view_direction, fn %Player{} = player, @direction2 ->
        struct!(player, view_direction: @direction2)
      end)
      |> expect(:tick, fn %Player{} = player, tick_moves_count ->
        assert_moves_count(moves_count, tick_moves_count)
        {:ok, player, []}
      end)

      assert {:moved, :normal} = Server.move(server, @direction2)
      assert_chat_message(server, :regular, "You walked at snow, it took")
    end

    test "returns success response (attack)", %{server: server, planet: planet} do
      moves_count = 2

      enemy = build(:enemy)
      damage = 5
      damaged_enemies = [{enemy, damage}]

      PlanetManagerMock
      |> expect(:move, fn _planet, @direction, %Player{} -> {:attack, planet, damaged_enemies, moves_count} end)
      |> expect(:tick, fn %Planet{}, tick_moves_count ->
        assert_moves_count(moves_count, tick_moves_count)
        {:ok, planet, []}
      end)

      PlayerManagerMock
      |> expect(:weight_ratio, 2, fn %Player{} -> 0 end)
      |> expect(:tick, fn %Player{} = player, tick_moves_count ->
        assert_moves_count(moves_count, tick_moves_count)
        {:ok, player, []}
      end)

      assert {:attack, :hitted} = Server.move(server, @direction)
      assert_chat_message(server, :regular, "You hit #{enemy.name} and dealt #{damage} damage to it!")
    end

    test "returns success response (attack with no damaged enemies)", %{server: server, planet: planet} do
      moves_count = 2

      PlanetManagerMock
      |> expect(:move, fn _planet, @direction, %Player{} -> {:attack, planet, [], moves_count} end)
      |> expect(:tick, fn %Planet{}, tick_moves_count ->
        assert_moves_count(moves_count, tick_moves_count)
        {:ok, planet, []}
      end)

      PlayerManagerMock
      |> expect(:weight_ratio, 2, fn %Player{} -> 0 end)
      |> expect(:tick, fn %Player{} = player, tick_moves_count ->
        assert_moves_count(moves_count, tick_moves_count)
        {:ok, player, []}
      end)

      assert {:attack, :miss} = Server.move(server, @direction)
      assert_chat_message(server, :warning, "You didn't hit anyone")
    end

    test "increases moves_count when player overloaded", %{server: server, planet: planet} do
      test_overloaded_move(server, planet, _weight_ratio = 1.1, _additional_moves = 1)
      test_overloaded_move(server, planet, _weight_ratio = 1.2, _additional_moves = 2)
      test_overloaded_move(server, planet, _weight_ratio = 1.3, _additional_moves = 3)
      test_overloaded_move(server, planet, _weight_ratio = 1.35, _additional_moves = 4)
    end

    test "returns success response (stay)", %{server: server} do
      PlanetManagerMock
      |> expect(:move, fn _planet, @direction, %Player{} -> {:stay, @water} end)
      |> expect(:readable_tile_name, fn _tile -> "water" end)

      PlayerManagerMock
      |> expect(:weight_ratio, fn %Player{} -> 0 end)

      assert :stay = Server.move(server, @direction)
      assert_chat_message(server, :warning, "You can't walk through water")
    end

    test "doesn't walk when player overloaded", %{server: server} do
      PlayerManagerMock
      |> expect(:weight_ratio, fn %Player{} -> 2.0 end)

      assert :stay = Server.move(server, @direction)
      assert_chat_message(server, :warning, "You can't walk because you're overloaded")
    end

    test "finishes game when player dies", %{server: server, planet: planet} do
      %Server{game_uuid: game_uuid} = :sys.get_state(server)
      insert(:game, uuid: game_uuid, state: :active)

      moves_count = 10
      action = build(:action, action_type: :attack, subject: build(:enemy, damage: 500))
      action2 = build(:action, action_type: :get_cold, subject: :player)

      PlanetManagerMock
      |> expect(:move, fn _planet, @direction, %Player{} -> {:moved, planet, moves_count, @snow} end)
      |> expect(:readable_tile_name, fn _tile -> "snow" end)
      |> expect(:tick, fn %Planet{}, tick_moves_count ->
        assert_moves_count(moves_count, tick_moves_count)
        {:ok, planet, [action]}
      end)

      PlayerManagerMock
      |> expect(:weight_ratio, 2, fn %Player{} -> 0 end)
      |> stub(:stand_on, fn %Player{} = player, tile ->
        struct!(player, stand_on: tile)
      end)
      |> expect(:take_damage, fn %Player{} = player, damage ->
        assert damage == action.subject.damage
        struct!(player, health: 0)
      end)
      |> expect(:tick, fn %Player{} = player, tick_moves_count ->
        assert_moves_count(moves_count, tick_moves_count)
        {:ok, player, [action2]}
      end)

      assert {:moved, :normal} = Server.move(server, @direction)
      :timer.sleep(600)
      assert {:ok, %Games.Game{state: :finished, finish_reason: :died}} = Games.get_by_uuid(game_uuid)

      assert_received :game_over
    end

    test "crops land", %{server: server, planet: planet} do
      moves_count = 10

      PlanetManagerMock
      |> expect(:move, fn _planet, @direction, %Player{} -> {:moved, planet, moves_count, @snow} end)
      |> expect(:readable_tile_name, fn _tile -> "snow" end)
      |> expect(:tick, fn %Planet{}, _tick_moves_count ->
        {:ok, planet, []}
      end)
      |> expect(:land_size, fn _ -> @crop_size end)
      |> expect(:crop_land, fn %Planet{} = planet -> {:ok, planet} end)

      PlayerManagerMock
      |> expect(:weight_ratio, 2, fn %Player{} -> 0 end)
      |> expect(:tick, fn %Player{} = player, _tick_moves_count ->
        {:ok, player, []}
      end)

      assert {:moved, :normal} = Server.move(server, @direction)
      :timer.sleep(100)
    end

    defp test_overloaded_move(server, planet, weight_ratio, expected_additional_moves) do
      moves_count = 10

      PlanetManagerMock
      |> expect(:move, fn _planet, @direction, %Player{} -> {:moved, planet, moves_count, @snow} end)
      |> expect(:readable_tile_name, fn _tile -> "snow" end)
      |> expect(:tick, fn %Planet{}, tick_moves_count ->
        assert_moves_count(moves_count + expected_additional_moves, tick_moves_count)
        {:ok, planet, []}
      end)

      PlayerManagerMock
      |> expect(:weight_ratio, 2, fn %Player{} -> weight_ratio end)
      |> expect(:stand_on, fn %Player{} = player, @snow ->
        struct!(player, stand_on: @snow)
      end)
      |> expect(:tick, fn %Player{} = player, tick_moves_count ->
        assert_moves_count(moves_count + expected_additional_moves, tick_moves_count)
        {:ok, player, []}
      end)

      assert {:moved, :overloaded} = Server.move(server, @direction)
      :timer.sleep(200)
    end
  end

  describe "loot/1" do
    test "returns success response", %{server: server, item_box: item_box} do
      PlanetManagerMock
      |> expect(:loot, fn _planet, _direction -> {:open_item_box, item_box} end)

      assert {:open_item_box, ^item_box} = Server.loot(server)
    end

    test "returns error when there is nothing to loot", %{server: server} do
      PlanetManagerMock
      |> expect(:loot, fn _planet, _direction -> {:error, :nothing} end)

      assert {:error, :nothing} = Server.loot(server)
      assert_chat_message(server, :warning, "There is nothing to loot")
    end
  end

  describe "take_loot/2" do
    test "returns success response", %{server: server, item_box: item_box} do
      item_uuid = Ecto.UUID.generate()

      PlanetManagerMock
      |> expect(:take_loot, fn %Planet{} = planet, %Player{} = player, ^item_uuid ->
        {:ok, planet, player, item_box}
      end)

      assert {:ok, ^item_box} = Server.take_loot(server, item_uuid)
    end

    test "returns error when there is nothing to loot", %{server: server} do
      item_uuid = Ecto.UUID.generate()

      PlanetManagerMock
      |> expect(:take_loot, fn _planet, _player, ^item_uuid ->
        {:error, :nothing}
      end)

      assert {:error, :nothing} = Server.take_loot(server, item_uuid)
    end
  end

  describe "shoot/1" do
    test "handles success response", %{server: server} do
      damaged_enemies = [{build(:enemy), _damage = 10}]
      moves_count = 1

      PlanetManagerMock
      |> expect(:shoot, fn %Planet{} = planet, %Player{} = player ->
        {:ok, {planet, player, damaged_enemies, moves_count}}
      end)
      |> expect(:tick, fn %Planet{} = planet, tick_moves_count ->
        assert_moves_count(moves_count, tick_moves_count)
        {:ok, planet, []}
      end)

      PlayerManagerMock
      |> expect(:tick, fn %Player{} = player, tick_moves_count ->
        assert_moves_count(moves_count, tick_moves_count)
        {:ok, player, []}
      end)

      assert Server.shoot(server) == {:ok, :shot}
      :timer.sleep(100)
    end

    test "handles miss response", %{server: server} do
      moves_count = 1

      PlanetManagerMock
      |> expect(:shoot, fn %Planet{}, %Player{} = player ->
        {:error, :miss, player, moves_count}
      end)
      |> expect(:tick, fn %Planet{} = planet, tick_moves_count ->
        assert_moves_count(moves_count, tick_moves_count)
        {:ok, planet, []}
      end)

      PlayerManagerMock
      |> expect(:tick, fn %Player{} = player, tick_moves_count ->
        assert_moves_count(moves_count, tick_moves_count)
        {:ok, player, []}
      end)

      assert Server.shoot(server) == {:ok, :miss}
      :timer.sleep(100)
    end

    test "handles no_weapon response", %{server: server} do
      PlanetManagerMock
      |> expect(:shoot, fn %Planet{}, %Player{} ->
        {:error, :no_weapon}
      end)

      assert Server.shoot(server) == {:error, :no_weapon}
    end

    test "handles empty_magazine response", %{server: server} do
      PlanetManagerMock
      |> expect(:shoot, fn %Planet{}, %Player{} ->
        {:error, :empty_magazine}
      end)

      assert Server.shoot(server) == {:error, :empty_magazine}
    end
  end

  describe "reload/2" do
    test "handles success response", %{server: server} do
      weapon = build(:weapon)
      weapon_uuid = weapon.uuid
      moves_count = weapon.reload_cost

      PlayerManagerMock
      |> expect(:reload_weapon, fn %Player{} = player, ^weapon_uuid ->
        {:ok, player, weapon}
      end)

      PlanetManagerMock
      |> expect(:tick, fn %Planet{} = planet, tick_moves_count ->
        assert_moves_count(moves_count, tick_moves_count)
        {:ok, planet, []}
      end)

      PlayerManagerMock
      |> expect(:tick, fn %Player{} = player, tick_moves_count ->
        assert_moves_count(moves_count, tick_moves_count)
        {:ok, player, []}
      end)

      assert Server.reload(server, weapon_uuid) == :ok
      :timer.sleep(100)
    end

    test "handles no_weapon response", %{server: server} do
      error = {:error, :no_weapon}

      PlayerManagerMock
      |> expect(:reload_weapon, fn %Player{} ->
        error
      end)

      assert Server.reload(server) == error
    end

    test "handles no_ammo response", %{server: server} do
      error = {:error, :no_ammo}

      PlayerManagerMock
      |> expect(:reload_weapon, fn %Player{} ->
        error
      end)

      assert Server.reload(server) == error
    end

    test "handles full_magazine response", %{server: server} do
      error = {:error, :full_magazine}

      PlayerManagerMock
      |> expect(:reload_weapon, fn %Player{} ->
        error
      end)

      assert Server.reload(server) == error
    end
  end

  describe "unload_weapon/1" do
    test "handles success response", %{server: server} do
      weapon = build(:weapon)
      moves_count = weapon.reload_cost

      PlayerManagerMock
      |> expect(:unload_weapon, fn %Player{} = player, weapon_uuid ->
        assert weapon_uuid == weapon.uuid
        {:ok, player, weapon}
      end)

      PlanetManagerMock
      |> expect(:tick, fn %Planet{} = planet, tick_moves_count ->
        assert_moves_count(moves_count, tick_moves_count)
        {:ok, planet, []}
      end)

      PlayerManagerMock
      |> expect(:tick, fn %Player{} = player, tick_moves_count ->
        assert_moves_count(moves_count, tick_moves_count)
        {:ok, player, []}
      end)

      assert Server.unload_weapon(server, weapon.uuid) == :ok
      :timer.sleep(100)
    end

    test "handles not_found response", %{server: server} do
      weapon = build(:weapon)
      error = {:error, :not_found}

      PlayerManagerMock
      |> expect(:unload_weapon, fn _, _ ->
        error
      end)

      assert Server.unload_weapon(server, weapon.uuid) == error
    end

    test "handles empty_magazine response", %{server: server} do
      weapon = build(:weapon)
      error = {:error, :empty_magazine}

      PlayerManagerMock
      |> expect(:unload_weapon, fn _, _ ->
        error
      end)

      assert Server.unload_weapon(server, weapon.uuid) == error
    end
  end

  describe "unload_item_box_weapon/2" do
    test "handles success response", %{server: server} do
      weapon = build(:weapon)
      item_box = build(:loot_item_box, items: [weapon])
      moves_count = weapon.reload_cost

      PlanetManagerMock
      |> expect(:tick, fn %Planet{} = planet, tick_moves_count ->
        assert_moves_count(moves_count, tick_moves_count)
        {:ok, planet, []}
      end)
      |> expect(:unload_item_box_weapon, fn %Planet{} = planet, %Player{} = player, weapon_uuid ->
        assert weapon_uuid == weapon.uuid
        {:ok, planet, player, item_box, weapon}
      end)

      PlayerManagerMock
      |> expect(:tick, fn %Player{} = player, tick_moves_count ->
        assert_moves_count(moves_count, tick_moves_count)
        {:ok, player, []}
      end)

      assert {:ok, ^item_box} = Server.unload_item_box_weapon(server, weapon.uuid)
      :timer.sleep(100)
    end

    test "handles nothing response", %{server: server} do
      weapon = build(:weapon)
      error = {:error, :nothing}

      PlanetManagerMock
      |> expect(:unload_item_box_weapon, fn _, _, _ ->
        error
      end)

      assert Server.unload_item_box_weapon(server, weapon.uuid) == error
    end

    test "handles not applicable response", %{server: server} do
      weapon = build(:weapon)
      error = {:error, %Errors.NotApplicableError{}}

      PlanetManagerMock
      |> expect(:unload_item_box_weapon, fn _, _, _ ->
        error
      end)

      assert Server.unload_item_box_weapon(server, weapon.uuid) == error
    end

    test "handles empty_magazine response", %{server: server} do
      weapon = build(:weapon)
      error = {:error, :empty_magazine}

      PlanetManagerMock
      |> expect(:unload_item_box_weapon, fn _, _, _ ->
        error
      end)

      assert Server.unload_item_box_weapon(server, weapon.uuid) == error
    end
  end

  describe "equip_item/2" do
    test "handles success response", %{server: server} do
      item_uuid = Ecto.UUID.generate()

      PlayerManagerMock
      |> expect(:equip_item, fn %Player{} = player, ^item_uuid ->
        {:ok, player}
      end)

      assert {:ok, %Player{}} = Server.equip_item(server, item_uuid)
    end

    test "handles not_found response", %{server: server} do
      item_uuid = Ecto.UUID.generate()
      error = {:error, :not_found}

      PlayerManagerMock
      |> expect(:equip_item, fn %Player{}, ^item_uuid ->
        error
      end)

      assert Server.equip_item(server, item_uuid) == error
    end
  end

  describe "toggle_aim_mode" do
    test "handles success response", %{server: server} do
      moves_count = 1

      PlayerManagerMock
      |> expect(:toggle_aim_mode, fn %Player{} = player ->
        {:ok, player}
      end)
      |> expect(:tick, fn %Player{} = player, tick_moves_count ->
        assert_moves_count(moves_count, tick_moves_count)
        {:ok, player, []}
      end)

      PlanetManagerMock
      |> expect(:tick, fn %Planet{} = planet, tick_moves_count ->
        assert_moves_count(moves_count, tick_moves_count)
        {:ok, planet, []}
      end)

      assert :ok = Server.toggle_aim_mode(server)
      :timer.sleep(100)
    end

    test "handles no_weapon response", %{server: server} do
      error = {:error, :no_weapon}

      PlayerManagerMock
      |> expect(:toggle_aim_mode, fn %Player{} ->
        error
      end)

      assert Server.toggle_aim_mode(server) == error
    end
  end

  describe "unequip_item/2" do
    test "handles success response", %{server: server} do
      item_uuid = Ecto.UUID.generate()

      PlayerManagerMock
      |> expect(:unequip_item, fn %Player{} = player, ^item_uuid ->
        {:ok, player}
      end)

      assert {:ok, %Player{}} = Server.unequip_item(server, item_uuid)
    end

    test "handles not_found response", %{server: server} do
      item_uuid = Ecto.UUID.generate()
      error = {:error, :not_found}

      PlayerManagerMock
      |> expect(:unequip_item, fn %Player{}, ^item_uuid ->
        error
      end)

      assert Server.unequip_item(server, item_uuid) == error
    end
  end

  describe "get_item/2" do
    test "handles success response", %{server: server} do
      weapon = build(:weapon)
      item_uuid = weapon.uuid

      PlayerManagerMock
      |> expect(:get_item, fn %Player{}, ^item_uuid ->
        {:ok, weapon}
      end)

      assert Server.get_item(server, item_uuid) == {:ok, weapon}
    end

    test "handles not_found error", %{server: server} do
      item_uuid = Ecto.UUID.generate()
      error = {:error, :not_found}

      PlayerManagerMock
      |> expect(:get_item, fn %Player{}, ^item_uuid ->
        error
      end)

      assert Server.get_item(server, item_uuid) == error
    end
  end

  describe "drop_item/3" do
    test "handles success response", %{server: server} do
      count = 1
      item_uuid = Ecto.UUID.generate()

      PlayerManagerMock
      |> expect(:drop_item, fn %Player{} = player, ^item_uuid, ^count ->
        {:ok, player, build(:ammo)}
      end)

      assert {:ok, %Player{}} = Server.drop_item(server, item_uuid, count)
    end

    test "handles not_found response", %{server: server} do
      count = 1
      item_uuid = Ecto.UUID.generate()
      error = {:error, :not_found}

      PlayerManagerMock
      |> expect(:drop_item, fn %Player{}, ^item_uuid, ^count ->
        error
      end)

      assert Server.drop_item(server, item_uuid, count) == error
    end
  end

  describe "consume_supply/2" do
    test "handles success response", %{server: server} do
      supply = build(:supply)
      supply_uuid = supply.uuid
      moves_count = supply.consume_cost

      PlayerManagerMock
      |> expect(:consume_supply, fn %Player{} = player, ^supply_uuid ->
        {:ok, player, supply}
      end)

      PlanetManagerMock
      |> expect(:tick, fn %Planet{} = planet, tick_moves_count ->
        assert_moves_count(moves_count, tick_moves_count)
        {:ok, planet, []}
      end)

      PlayerManagerMock
      |> expect(:tick, fn %Player{} = player, tick_moves_count ->
        assert_moves_count(moves_count, tick_moves_count)
        {:ok, player, []}
      end)

      assert {:ok, ^supply} = Server.consume_supply(server, supply_uuid)
      :timer.sleep(100)
    end

    test "handles not_found response", %{server: server} do
      supply = build(:supply)
      error = {:error, :not_found}

      PlayerManagerMock
      |> expect(:consume_supply, fn _player, _supply_uuid ->
        error
      end)

      assert Server.consume_supply(server, supply.uuid) == error
    end

    test "handles NotApplicable response", %{server: server} do
      supply = build(:supply)
      error = {:error, %Errors.NotApplicableError{}}

      PlayerManagerMock
      |> expect(:consume_supply, fn _player, _supply_uuid ->
        error
      end)

      assert Server.consume_supply(server, supply.uuid) == error
    end
  end

  describe "disassemble_item/2" do
    test "handles success response", %{server: server} do
      weapon = build(:weapon)
      weapon_uuid = weapon.uuid

      PlayerManagerMock
      |> expect(:disassemble_item, fn %Player{} = player, ^weapon_uuid ->
        {:ok, player, weapon}
      end)

      PlanetManagerMock
      |> expect(:tick, fn %Planet{} = planet, tick_moves_count ->
        assert_moves_count(@craft_moves_count, tick_moves_count)
        {:ok, planet, []}
      end)

      PlayerManagerMock
      |> expect(:tick, fn %Player{} = player, tick_moves_count ->
        assert_moves_count(@craft_moves_count, tick_moves_count)
        {:ok, player, []}
      end)

      assert Server.disassemble_item(server, weapon_uuid) == :ok
      :timer.sleep(100)
    end

    test "handles not_found response", %{server: server} do
      weapon = build(:weapon)
      error = {:error, :not_found}

      PlayerManagerMock
      |> expect(:disassemble_item, fn _player, _weapon_uuid ->
        error
      end)

      assert Server.disassemble_item(server, weapon.uuid) == error
    end

    test "handles NotApplicable response", %{server: server} do
      weapon = build(:weapon)
      error = {:error, %Errors.NotApplicableError{}}

      PlayerManagerMock
      |> expect(:disassemble_item, fn _player, _weapon_uuid ->
        error
      end)

      assert Server.disassemble_item(server, weapon.uuid) == error
    end
  end

  describe "craft_item/2" do
    test "handles success response", %{server: server} do
      blueprint = build(:blueprint)

      PlayerManagerMock
      |> expect(:craft_item, fn %Player{} = player, ^blueprint ->
        {:ok, player}
      end)

      PlanetManagerMock
      |> expect(:tick, fn %Planet{} = planet, tick_moves_count ->
        assert_moves_count(@craft_moves_count, tick_moves_count)
        {:ok, planet, []}
      end)

      PlayerManagerMock
      |> expect(:tick, fn %Player{} = player, tick_moves_count ->
        assert_moves_count(@craft_moves_count, tick_moves_count)
        {:ok, player, []}
      end)

      assert Server.craft_item(server, blueprint) == :ok
      :timer.sleep(100)
    end

    test "handles NotApplicable response", %{server: server} do
      blueprint = build(:blueprint)
      error = {:error, %Errors.NotApplicableError{}}

      PlayerManagerMock
      |> expect(:craft_item, fn _player, _blueprint ->
        error
      end)

      assert Server.craft_item(server, blueprint) == error
    end
  end

  defp assert_chat_message(server, category, text) do
    messages = Server.get_chat(server).messages

    assert Enum.find(messages, fn message -> String.starts_with?(message.text, text) && message.category == category end)
  end

  defp assert_moves_count(action_moves_count, tick_moves_count) do
    assert tick_moves_count in (action_moves_count - 1)..action_moves_count
  end
end
