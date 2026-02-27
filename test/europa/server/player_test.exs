defmodule Europa.Server.PlayerTest do
  use Europa.DataCase, async: true
  use ExUnitProperties

  alias Europa.Server.Player
  alias Europa.Server.Planet
  alias Europa.Server.Loot
  alias Europa.Server.Errors

  import Europa.Tools.Conf

  @snow Planet.snow()
  @snow_blood Planet.snow_blood()

  describe "new/0" do
    test "builds player" do
      assert %Player{} = Player.new()
    end

    property "sets random inventory_size" do
      check all(_ <- StreamData.integer(1..100)) do
        assert Player.new().inventory_size in inventory_size_range()
      end
    end

    property "sets random view_direction" do
      check all(_ <- StreamData.integer(1..100)) do
        assert Player.new().view_direction in Planet.allowed_directions()
      end
    end
  end

  describe "readable_stats/1" do
    test "returns stats (no quiped items)" do
      player = build(:player, weapon_uuid: nil)

      expected_stats = [
        {"Health", "#{player.health}/#{player.max_health}"},
        {"Inventory", "#{Enum.count(player.inventory)}/#{player.inventory_size}"},
        {"Accuracy", player.accuracy},
        {"Efficiency", player.efficiency},
        {"Weapon", "No"},
        {"Helmet", "No"},
        {"Suit", "No"},
        {"Boots", "No"}
      ]

      assert Player.readable_stats(player) == expected_stats
    end

    test "returns stats (with full equipment)" do
      weapon = build(:weapon)
      helmet = build(:helmet)
      suit = build(:suit)
      boots = build(:boots)

      player =
        build(:player,
          weapon_uuid: weapon.uuid,
          helmet_uuid: helmet.uuid,
          suit_uuid: suit.uuid,
          boots_uuid: boots.uuid,
          inventory: [weapon, helmet, suit, boots]
        )

      expected_stats = [
        {"Health", "#{player.health}/#{player.max_health}"},
        {"Inventory", "#{Enum.count(player.inventory)}/#{player.inventory_size}"},
        {"Accuracy", player.accuracy},
        {"Efficiency", player.efficiency},
        {"Weapon", weapon.name},
        {"Helmet", helmet.name},
        {"Suit", suit.name},
        {"Boots", boots.name}
      ]

      assert Player.readable_stats(player) == expected_stats
    end
  end

  describe "change_view_direction/2" do
    setup do
      player = build(:player, view_direction: :up)
      {:ok, player: player}
    end

    test "changes view_direction", %{player: player} do
      for direction <- Planet.allowed_directions() do
        assert %Player{view_direction: ^direction} = Player.change_view_direction(player, direction)
      end
    end

    test "does nothing when direction not allowed", %{player: player} do
      assert Player.change_view_direction(player, :fake) == player
    end
  end

  describe "stand_on/2" do
    setup do
      player = build(:player, stand_on: @snow)
      {:ok, player: player}
    end

    test "changes stand_on", %{player: player} do
      assert %Player{stand_on: @snow_blood} = Player.stand_on(player, @snow_blood)
    end
  end

  describe "add_item/2" do
    setup do
      player = build(:player, inventory_size: 2, inventory: [build(:weapon)])
      item = build(:weapon)

      {:ok, player: player, item: item}
    end

    test "adds item to inventory", %{player: player, item: item} do
      assert {:ok, %Player{inventory: inventory}} = Player.add_item(player, item)
      assert inventory == [item | player.inventory]
    end

    test "stacks same stackable items" do
      for item_type <- [:ammo, :supply] do
        player = build(:player, inventory: [])
        item = build(item_type)
        item2 = struct(item, count: 100)

        expected_count = item.count + item2.count

        assert {:ok, updated_player} = Player.add_item(player, item)

        assert {:ok, %Player{inventory: [updated_item]}} = Player.add_item(updated_player, item2)
        assert updated_item.count == expected_count
      end
    end

    test "returns error when inventory is full", %{player: player, item: item} do
      assert {:ok, player} = Player.add_item(player, item)
      assert {:error, :full_inventory} = Player.add_item(player, item)
    end
  end

  describe "equip_item/2" do
    setup do
      weapon = build(:weapon)
      ammo = build(:ammo)
      helmet = build(:helmet)
      suit = build(:suit)
      boots = build(:boots)

      player = build(:player, inventory_size: 5, weapon_uuid: nil, inventory: [weapon, ammo, helmet, suit, boots])

      {:ok, player: player, weapon: weapon, ammo: ammo, helmet: helmet, suit: suit, boots: boots}
    end

    test "equips items", %{player: player, weapon: weapon, helmet: helmet, suit: suit, boots: boots} do
      for item <- [weapon, helmet, suit, boots] do
        assert {:ok, updated_player} = Player.equip_item(player, item.uuid)
        updated_item = Enum.find(updated_player.inventory, fn i -> i.uuid == item.uuid end)

        assert updated_item.equiped == true
        assert_changed_player_item_uuid(updated_player, updated_item, _expected_value = updated_item.uuid)
      end
    end

    test "updates player stats" do
      weapon = build(:weapon, accuracy: 40)
      weapon2 = build(:weapon, accuracy: 20)
      player = build(:player, accuracy: 65, weapon_uuid: weapon.uuid, inventory: [weapon, weapon2])

      expected_accuracy = player.accuracy - weapon.accuracy + weapon2.accuracy

      assert {:ok, %Player{accuracy: ^expected_accuracy}} = Player.equip_item(player, weapon2.uuid)
    end

    test "returns error when no given item in inventory", %{player: player} do
      item_uuid = Ecto.UUID.generate()
      assert Player.equip_item(player, item_uuid) == {:error, :not_found}
    end

    test "returns error when item not quipable", %{player: player, ammo: ammo} do
      assert Player.equip_item(player, ammo.uuid) == {:error, %Errors.NotApplicableError{}}
    end
  end

  describe "unequip_item/2" do
    setup do
      weapon = build(:weapon, equiped: true)
      ammo = build(:ammo)
      helmet = build(:helmet, equiped: true)
      suit = build(:suit, equiped: true)
      boots = build(:boots, equiped: true)

      player = build(:player, inventory_size: 5, weapon_uuid: nil, inventory: [weapon, ammo, helmet, suit, boots])

      {:ok, player: player, weapon: weapon, ammo: ammo, helmet: helmet, suit: suit, boots: boots}
    end

    test "unequips items", %{player: player, weapon: weapon, helmet: helmet, suit: suit, boots: boots} do
      for item <- [weapon, helmet, suit, boots] do
        assert {:ok, updated_player} = Player.unequip_item(player, item.uuid)
        updated_item = Enum.find(updated_player.inventory, fn i -> i.uuid == item.uuid end)

        assert updated_item.equiped == false
        assert_changed_player_item_uuid(updated_player, updated_item, _expected_value = nil)
      end
    end

    test "updates player stats" do
      weapon = build(:weapon, accuracy: 40)
      player = build(:player, accuracy: 65, weapon_uuid: weapon.uuid, inventory: [weapon])

      expected_accuracy = player.accuracy - weapon.accuracy
      assert {:ok, %Player{accuracy: ^expected_accuracy}} = Player.unequip_item(player, weapon.uuid)
    end

    test "returns error when no given item in inventory", %{player: player} do
      item_uuid = Ecto.UUID.generate()
      assert Player.unequip_item(player, item_uuid) == {:error, :not_found}
    end

    test "returns error when item not quipable", %{player: player, ammo: ammo} do
      assert Player.unequip_item(player, ammo.uuid) == {:error, %Errors.NotApplicableError{}}
    end
  end

  describe "update_item/2" do
    setup do
      weapon = build(:weapon)
      ammo = build(:ammo)
      player = build(:player, inventory_size: 2, weapon_uuid: nil, inventory: [weapon, ammo])

      {:ok, player: player, weapon: weapon, ammo: ammo}
    end

    test "updates given item", %{player: player, ammo: ammo, weapon: weapon} do
      updated_ammo = struct(ammo, count: 1000)
      assert %Player{inventory: [^weapon, ^updated_ammo]} = Player.update_item(player, updated_ammo)
    end
  end

  describe "delete_item/2" do
    setup do
      weapon = build(:weapon)
      ammo = build(:ammo)
      player = build(:player, inventory_size: 2, weapon_uuid: nil, inventory: [weapon, ammo])

      {:ok, player: player, weapon: weapon, ammo: ammo}
    end

    test "deletes given item", %{player: player, ammo: ammo, weapon: weapon} do
      assert %Player{inventory: [^weapon]} = Player.delete_item(player, ammo)
    end
  end

  describe "get_equiped_weapon/1" do
    setup do
      weapon = build(:weapon)
      player = build(:player, inventory_size: 2, weapon_uuid: weapon.uuid, inventory: [weapon])

      {:ok, player: player, weapon: weapon}
    end

    test "returns equiped weapon", %{player: player, weapon: weapon} do
      assert Player.get_equiped_weapon(player) == {:ok, weapon}
    end

    test "returns error when no equiped weapon", %{player: player} do
      player = struct(player, weapon_uuid: nil)
      assert Player.get_equiped_weapon(player) == {:error, :no_weapon}
    end
  end

  describe "get_equiped_helmet/1" do
    setup do
      helmet = build(:helmet)
      player = build(:player, inventory_size: 2, helmet_uuid: helmet.uuid, inventory: [helmet])

      {:ok, player: player, helmet: helmet}
    end

    test "returns equiped helmet", %{player: player, helmet: helmet} do
      assert Player.get_equiped_helmet(player) == {:ok, helmet}
    end

    test "returns error when no equiped helmet", %{player: player} do
      player = struct(player, helmet_uuid: nil)
      assert Player.get_equiped_helmet(player) == {:error, :no_helmet}
    end
  end

  describe "find_weapon_ammo/2" do
    setup do
      weapon = build(:weapon)
      ammo = build(:ammo, caliber: weapon.caliber)

      player = build(:player, inventory_size: 2, weapon_uuid: weapon.uuid, inventory: [weapon, ammo])

      {:ok, player: player, weapon: weapon, ammo: ammo}
    end

    test "returns ammo", %{player: player, weapon: weapon, ammo: ammo} do
      assert Player.find_weapon_ammo(player, weapon) == {:ok, ammo}
    end

    test "returns no_ammo error", %{player: player, weapon: weapon, ammo: ammo} do
      player = Player.delete_item(player, ammo)
      assert Player.find_weapon_ammo(player, weapon) == {:error, :no_ammo}
    end
  end

  describe "take_damage/2" do
    setup do
      player = build(:player, health: 100, max_health: 200)
      {:ok, player: player}
    end

    test "decreases player health", %{player: player} do
      damage = 50
      expected_health = player.health - damage

      assert %Player{health: ^expected_health} = Player.take_damage(player, damage)
    end

    test "no negative health", %{player: player} do
      damage = player.health * 2
      assert %Player{health: 0} = Player.take_damage(player, damage)
    end
  end

  describe "reload_weapon/1" do
    setup do
      weapon = build(:weapon, rounds_loaded: 10, magazine_size: 20)
      ammo = build(:ammo, caliber: weapon.caliber, count: 100)

      player = build(:player, inventory_size: 2, weapon_uuid: weapon.uuid, inventory: [weapon, ammo])

      {:ok, player: player, weapon: weapon, ammo: ammo}
    end

    test "reloads weapon (enough ammo for full magazine)", %{player: player, weapon: weapon, ammo: ammo} do
      expected_weapon = struct(weapon, rounds_loaded: weapon.magazine_size)

      expected_ammo = struct(ammo, count: ammo.count - (weapon.magazine_size - weapon.rounds_loaded))

      assert {:ok, %Player{inventory: [^expected_weapon, ^expected_ammo]}, ^expected_weapon} =
               Player.reload_weapon(player)
    end

    test "reloads weapon (not enough ammo for full magazine)", %{player: player, weapon: weapon, ammo: ammo} do
      ammo = struct(ammo, count: 1)

      player = struct(player, inventory: [weapon, ammo])
      expected_weapon = struct(weapon, rounds_loaded: weapon.rounds_loaded + 1)

      assert {:ok, %Player{inventory: [^expected_weapon]}, ^expected_weapon} =
               Player.reload_weapon(player)
    end

    test "returns no_weapon error", %{player: player} do
      player = struct(player, weapon_uuid: nil)
      assert Player.reload_weapon(player) == {:error, :no_weapon}
    end

    test "returns no_ammo error", %{player: player, ammo: ammo} do
      player = Player.delete_item(player, ammo)
      assert Player.reload_weapon(player) == {:error, :no_ammo}
    end

    test "returns full_magazine error", %{player: player, weapon: weapon} do
      weapon = struct(weapon, rounds_loaded: weapon.magazine_size)
      player = Player.update_item(player, weapon)

      assert Player.reload_weapon(player) == {:error, :full_magazine}
    end
  end

  describe "unload_weapon/2" do
    test "returns updated player and weapon" do
      caliber = "9mm"
      rounds_loaded = 15

      weapon = build(:weapon, caliber: caliber, rounds_loaded: rounds_loaded, magazine_size: rounds_loaded * 2)
      ammo = build(:ammo, caliber: caliber, count: 5)
      player = build(:player, inventory_size: 2, inventory: [weapon, ammo])

      assert {:ok, %Player{inventory: [updated_weapon, updated_ammo]}, updated_weapon} =
               Player.unload_weapon(player, weapon.uuid)

      assert updated_weapon.rounds_loaded == 0
      assert updated_ammo.count == ammo.count + rounds_loaded
    end

    test "returns error when weapon not loaded" do
      weapon = build(:weapon, rounds_loaded: 0)
      player = build(:player, inventory_size: 2, inventory: [weapon])

      assert Player.unload_weapon(player, weapon.uuid) == {:error, :empty_magazine}
    end

    test "returns error when inventory is full" do
      weapon = build(:weapon, rounds_loaded: 10)
      player = build(:player, inventory_size: 1, inventory: [weapon])

      assert Player.unload_weapon(player, weapon.uuid) == {:error, :full_inventory}
    end

    test "returns error when weapon not found" do
      weapon_uuid = Ecto.UUID.generate()
      player = build(:player, inventory_size: 1, inventory: [])

      assert Player.unload_weapon(player, weapon_uuid) == {:error, :not_found}
    end
  end

  describe "consume_supply/2" do
    test "medicine supply heals player" do
      supply = build(:supply, count: 3, type: :medicine, properties: build(:supply_properties, health: 15))
      player = build(:player, health: 10, inventory: [supply])

      assert {:ok, %Player{health: updated_health, inventory: [updated_supply]}, updated_supply} =
               Player.consume_supply(player, supply.uuid)

      assert updated_health == player.health + supply.properties.health
      assert updated_supply.count == supply.count - 1
    end

    test "health not exeed max_health" do
      supply = build(:supply, count: 3, type: :medicine, properties: build(:supply_properties, health: 1000))
      player = build(:player, health: 10, max_health: 100, inventory: [supply])

      assert {:ok, %Player{health: updated_health}, %Loot.Supply{}} = Player.consume_supply(player, supply.uuid)
      assert updated_health == player.max_health
    end

    test "supply removes from inventory" do
      supply = build(:supply, count: 1, type: :medicine, properties: build(:supply_properties, health: 15))
      player = build(:player, health: 10, inventory: [supply])

      assert {:ok, %Player{inventory: []}, %Loot.Supply{}} = Player.consume_supply(player, supply.uuid)
    end
  end

  describe "get_inventory/2" do
    setup do
      ammo = build(:ammo)
      weapon = build(:weapon)
      supply = build(:supply)
      player = build(:player, inventory: [ammo, weapon, supply])

      {:ok, player: player, ammo: ammo, weapon: weapon, supply: supply}
    end

    test "returns all inventory", %{player: player} do
      assert Player.get_inventory(player, :all) == player.inventory
    end

    test "returns items of given type", %{player: player, ammo: ammo, weapon: weapon, supply: supply} do
      assert Player.get_inventory(player, :weapon) == [weapon]
      assert Player.get_inventory(player, :ammo) == [ammo]
      assert Player.get_inventory(player, :supply) == [supply]
    end
  end

  defp inventory_size_range do
    from = fetch_config!([:random_params, :player, :inventory_size, :from])
    to = fetch_config!([:random_params, :player, :inventory_size, :to])

    from..to
  end

  defp assert_changed_player_item_uuid(player, updated_item, expected_value) do
    case updated_item do
      %Loot.Weapon{} -> assert player.weapon_uuid == expected_value
      %Loot.Helmet{} -> assert player.helmet_uuid == expected_value
      %Loot.Suit{} -> assert player.suit_uuid == expected_value
      %Loot.Boots{} -> assert player.boots_uuid == expected_value
    end
  end
end
