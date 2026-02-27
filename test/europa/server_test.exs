defmodule Europa.ServerTest do
  use Europa.DataCase

  alias Europa.Games
  alias Europa.Server
  alias Europa.Server.Player
  alias Europa.Server.Planet
  alias Europa.Server.Chat
  alias Europa.Server.PlanetManagerMock
  alias Europa.Server.PlayerManagerMock
  alias Europa.Server.Errors
  alias Europa.Support.PlanetLandConverter

  import Europa.Tools.Conf

  @snow Planet.snow()
  @water Planet.water()
  @snow_blood Planet.snow_blood()

  @player_stand_on_tile @snow

  @direction :up

  @crop_period_ms fetch_config!([Server, :crop_land_period_ms])
  @crop_size fetch_config!([Planet, :crop_land_size])

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    PlanetManagerMock
    |> stub(:new, fn -> build(:planet) end)
    |> stub(:player_initial_stand_on_tile, fn _ -> @snow end)

    PlayerManagerMock
    |> stub(:new, fn -> build(:player, stand_on: @player_stand_on_tile, inventory_size: 20) end)
    |> stub(:stand_on, fn player, @snow -> player end)

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
      |> expect(:get_visible_land, fn _planet -> land end)

      assert Server.get_visible_planet(server) == land
    end
  end

  describe "move/2" do
    test "returns success response (moved)", %{server: server, planet: planet} do
      moves_count = 10
      action = build(:planet_action)

      PlanetManagerMock
      |> expect(:move, fn _planet, @direction, @player_stand_on_tile -> {:moved, planet, moves_count, @snow} end)
      |> expect(:readable_tile_name, fn _tile -> "snow" end)
      |> expect(:tick, fn %Planet{}, ^moves_count -> {:ok, planet, [action]} end)
      |> expect(:blood_tile, fn @player_stand_on_tile -> @snow_blood end)

      PlayerManagerMock
      |> expect(:change_view_direction, fn %Player{} = player, @direction ->
        struct(player, view_direction: @direction)
      end)
      |> expect(:stand_on, fn %Player{} = player, @snow ->
        struct(player, stand_on: @snow)
      end)
      |> expect(:take_damage, fn %Player{} = player, damage ->
        assert damage == action.subject.damage
        player
      end)

      assert :moved = Server.move(server, @direction)
      assert_chat_message(server, :regular, "You walked at snow, it took #{moves_count} step(s)")
      assert_chat_message(server, :danger, "#{action.subject.name} is attacking you!")
    end

    test "returns success response (stay)", %{server: server} do
      PlanetManagerMock
      |> expect(:move, fn _planet, @direction, @player_stand_on_tile -> {:stay, @water} end)
      |> expect(:readable_tile_name, fn _tile -> "water" end)

      PlayerManagerMock
      |> expect(:change_view_direction, fn %Player{} = player, @direction ->
        struct(player, view_direction: @direction)
      end)

      assert :stay = Server.move(server, @direction)
      assert_chat_message(server, :warning, "You can't walk through water")
    end

    test "finishes game when player dies", %{server: server, planet: planet} do
      %Server{game_uuid: game_uuid} = :sys.get_state(server)
      insert(:game, uuid: game_uuid, state: :active)

      moves_count = 10
      action = build(:planet_action, action_type: :attack, subject: build(:enemy, damage: 500))

      PlanetManagerMock
      |> expect(:move, fn _planet, @direction, @player_stand_on_tile -> {:moved, planet, moves_count, @snow} end)
      |> expect(:readable_tile_name, fn _tile -> "snow" end)
      |> expect(:tick, fn %Planet{}, ^moves_count -> {:ok, planet, [action]} end)
      |> expect(:blood_tile, fn @player_stand_on_tile -> @snow_blood end)

      PlayerManagerMock
      |> expect(:change_view_direction, fn %Player{} = player, @direction ->
        struct(player, view_direction: @direction)
      end)
      |> expect(:stand_on, fn %Player{} = player, @snow ->
        struct(player, stand_on: @snow)
      end)
      |> expect(:take_damage, fn %Player{} = player, damage ->
        assert damage == action.subject.damage
        struct(player, health: 0)
      end)

      assert :moved = Server.move(server, @direction)
      :timer.sleep(200)
      assert {:ok, %Games.Game{state: :finished, finish_reason: :died}} = Games.get_by_uuid(game_uuid)

      assert_received :game_over
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

    test "returns error when player inventory is full", %{server: server} do
      item_uuid = Ecto.UUID.generate()

      PlanetManagerMock
      |> expect(:take_loot, fn _planet, _player, ^item_uuid ->
        {:error, :full_inventory}
      end)

      assert {:error, :nothing} = Server.take_loot(server, item_uuid)
      assert_chat_message(server, :warning, "Can't take item because of full inventory")
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
      |> expect(:tick, fn %Planet{} = planet, ^moves_count -> {:ok, planet, []} end)

      assert Server.shoot(server) == :ok
      :timer.sleep(100)
    end

    test "handles miss response", %{server: server} do
      moves_count = 1

      PlanetManagerMock
      |> expect(:shoot, fn %Planet{}, %Player{} = player ->
        {:error, :miss, player, moves_count}
      end)
      |> expect(:tick, fn %Planet{} = planet, ^moves_count -> {:ok, planet, []} end)

      assert Server.shoot(server) == :ok
      :timer.sleep(100)
    end

    test "handles no_weapon response", %{server: server} do
      PlanetManagerMock
      |> expect(:shoot, fn %Planet{}, %Player{} ->
        {:error, :no_weapon}
      end)

      assert Server.shoot(server) == :ok
    end

    test "handles empty_magazine response", %{server: server} do
      PlanetManagerMock
      |> expect(:shoot, fn %Planet{}, %Player{} ->
        {:error, :empty_magazine}
      end)

      assert Server.shoot(server) == :ok
    end
  end

  describe "reload/1" do
    test "handles success response", %{server: server} do
      weapon = build(:weapon)
      moves_count = weapon.reload_cost

      PlayerManagerMock
      |> expect(:reload_weapon, fn %Player{} = player ->
        {:ok, player, weapon}
      end)

      PlanetManagerMock
      |> expect(:tick, fn %Planet{} = planet, ^moves_count -> {:ok, planet, []} end)

      assert Server.reload(server) == :ok
      :timer.sleep(100)
    end

    test "handles no_weapon response", %{server: server} do
      PlayerManagerMock
      |> expect(:reload_weapon, fn %Player{} ->
        {:error, :no_weapon}
      end)

      assert Server.reload(server) == :ok
    end

    test "handles no_ammo response", %{server: server} do
      PlayerManagerMock
      |> expect(:reload_weapon, fn %Player{} ->
        {:error, :no_ammo}
      end)

      assert Server.reload(server) == :ok
    end

    test "handles full_magazine response", %{server: server} do
      PlayerManagerMock
      |> expect(:reload_weapon, fn %Player{} ->
        {:error, :full_magazine}
      end)

      assert Server.reload(server) == :ok
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
      |> expect(:tick, fn %Planet{} = planet, ^moves_count -> {:ok, planet, []} end)

      assert {:ok, %Player{}} = Server.unload_weapon(server, weapon.uuid)
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
      |> expect(:tick, fn %Planet{} = planet, ^moves_count -> {:ok, planet, []} end)
      |> expect(:unload_item_box_weapon, fn %Planet{} = planet, %Player{} = player, weapon_uuid ->
        assert weapon_uuid == weapon.uuid
        {:ok, planet, player, item_box, weapon}
      end)

      assert {:ok, ^item_box, %Player{}} = Server.unload_item_box_weapon(server, weapon.uuid)
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
      |> expect(:tick, fn %Planet{} = planet, ^moves_count -> {:ok, planet, []} end)

      assert {:ok, %Player{}} = Server.consume_supply(server, supply_uuid)
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

  test "calls planet land crop after timeout", %{server: server} do
    planet = Server.get_planet(server)

    PlanetManagerMock
    |> expect(:land_size, fn ^planet -> @crop_size end)
    |> expect(:crop_land, fn ^planet ->
      {:ok, planet}
    end)

    :timer.sleep(@crop_period_ms + 100)
  end

  defp assert_chat_message(server, category, text) do
    message = Chat.Message.new(text, category)
    assert message in Server.get_chat(server).messages
  end
end
