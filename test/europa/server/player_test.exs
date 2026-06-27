defmodule Europa.Server.PlayerTest do
  alias Europa.Server.Errors.NotApplicableError
  use Europa.DataCase, async: true
  use ExUnitProperties

  alias Europa.Server.Player
  alias Europa.Server.Planet
  alias Europa.Server.Characters.Character
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Loot
  alias Europa.Server.Loot.Weapon.Ammo
  alias Europa.Server.Loot.Tool
  alias Europa.Server.Errors

  import Europa.Tools.Conf

  @snow Tiles.tile(:snow).atom_value
  @snow_blood Tiles.tile(:snow).blood_version

  @max_radiation fetch_config!([:game_params, :player, :max_radiation])
  @max_thirst fetch_config!([:game_params, :player, :max_thirst])

  describe "new/0" do
    setup do
      character = build(:character)
      {:ok, character: character}
    end

    test "builds player", %{character: character} do
      assert %Player{} = Player.new(character)
    end

    property "sets random max_weight", %{character: character} do
      check all(_ <- StreamData.integer(1..100)) do
        max_weight = Player.new(character).max_weight |> round()
        assert max_weight in max_weight_range()
      end
    end

    property "sets random view_direction", %{character: character} do
      check all(_ <- StreamData.integer(1..100)) do
        assert Player.new(character).view_direction in Planet.allowed_directions()
      end
    end
  end

  describe "readable_stats/1" do
    test "returns stats (no quiped items)" do
      player = build(:player, weapon_uuid: nil)

      expected_stats = [
        {"Name", player.character.name},
        {"Age", player.character.current_age},
        {"Gender", Character.readable_gender(player.character)},
        {"Health", "#{player.health}/#{player.max_health}"},
        {"Weapon", "No"},
        {"Melee weapon", "No"},
        {"Helmet", "No"},
        {"Suit", "No"},
        {"Boots", "No"}
      ]

      assert Player.readable_stats(player) == expected_stats
    end

    test "returns stats (with full equipment)" do
      weapon = build(:weapon)
      melee_weapon = build(:melee_weapon)
      helmet = build(:helmet)
      suit = build(:suit)
      boots = build(:boots)

      player =
        build(:player,
          weapon_uuid: weapon.uuid,
          melee_weapon_uuid: melee_weapon.uuid,
          helmet_uuid: helmet.uuid,
          suit_uuid: suit.uuid,
          boots_uuid: boots.uuid,
          inventory: [weapon, melee_weapon, helmet, suit, boots]
        )

      expected_stats = [
        {"Name", player.character.name},
        {"Age", player.character.current_age},
        {"Gender", Character.readable_gender(player.character)},
        {"Health", "#{player.health}/#{player.max_health}"},
        {"Weapon", weapon.name},
        {"Melee weapon", melee_weapon.name},
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

  describe "warm_up/2" do
    setup do
      player = build(:player, warm: 10, max_warm: 50)
      {:ok, player: player}
    end

    test "increases warm", %{player: player} do
      warm_units = 20
      expected_warm = player.warm + warm_units
      assert %Player{warm: ^expected_warm} = Player.warm_up(player, warm_units)
    end

    test "doensn't exceed max_warm", %{player: player} do
      expected_warm = player.max_warm
      assert %Player{warm: ^expected_warm} = Player.warm_up(player, player.max_warm + 100)
    end
  end

  describe "increase_thirst/2" do
    setup do
      player = build(:player, thirst: 0)
      {:ok, player: player}
    end

    test "increases thirst", %{player: player} do
      thirst_units = 20
      expected_thirst = player.thirst + thirst_units
      assert %Player{thirst: ^expected_thirst} = Player.increase_thirst(player, thirst_units)
    end

    test "doensn't exceed max thirst", %{player: player} do
      assert %Player{thirst: @max_thirst} = Player.increase_thirst(player, @max_thirst + 100)
    end
  end

  describe "add_item/2" do
    setup do
      player = build(:player, inventory: [build(:weapon)])
      item = build(:weapon)

      {:ok, player: player, item: item}
    end

    test "adds item to inventory", %{player: player, item: item} do
      assert {:ok, %Player{inventory: inventory}} = Player.add_item(player, item)
      assert inventory == [item | player.inventory]
    end

    test "stacks same stackable items" do
      for item_type <- [:ammo, :supply, :tool] do
        player = build(:player, inventory: [])
        item = build(item_type)
        item2 = struct!(item, count: 100)

        expected_count = item.count + item2.count

        assert {:ok, updated_player} = Player.add_item(player, item)

        assert {:ok, %Player{inventory: [updated_item]}} = Player.add_item(updated_player, item2)
        assert updated_item.count == expected_count
      end
    end

    test "not stacks supplies with different properties" do
      player = build(:player, inventory: [])
      supply1 = build(:supply, name: "supply", properties: build(:supply_properties, health: 10, warm: 1))
      supply2 = build(:supply, name: "supply", properties: build(:supply_properties, health: 10, warm: 2))

      assert {:ok, updated_player} = Player.add_item(player, supply1)
      assert {:ok, %Player{inventory: [^supply2, ^supply1]}} = Player.add_item(updated_player, supply2)
    end

    test "not stacks tools with different properties" do
      player = build(:player, inventory: [])
      tool1 = build(:tool, properties: build(:tool_properties, level: 1))
      tool2 = build(:tool, properties: build(:tool_properties, level: 2))

      assert {:ok, updated_player} = Player.add_item(player, tool1)
      assert {:ok, %Player{inventory: [^tool2, ^tool1]}} = Player.add_item(updated_player, tool2)
    end
  end

  describe "get_item/2" do
    test "returns given item" do
      weapon = build(:weapon)
      player = build(:player, inventory: [weapon])

      assert {:ok, ^weapon} = Player.get_item(player, weapon.uuid)
    end

    test "returns not_found error" do
      player = build(:player, inventory: [])
      item_uuid = Ecto.UUID.generate()

      assert Player.get_item(player, item_uuid) == {:error, :not_found}
    end
  end

  describe "drop_item/3" do
    setup do
      weapon = build(:weapon)
      ammo = build(:ammo, count: 20)
      player = build(:player, inventory: [weapon, ammo])

      {:ok, player: player, weapon: weapon, ammo: ammo}
    end

    test "drops given item", %{player: player, ammo: ammo, weapon: weapon} do
      player = Player.stand_on(player, @snow)

      assert {:ok,
              %Player{inventory: [^ammo], stand_on: %Loot.ItemBox{type: :bunch, stand_on: @snow, items: [^weapon]}},
              ^weapon} = Player.drop_item(player, weapon.uuid)
    end

    test "drops stackable item (all)", %{player: player, ammo: ammo, weapon: weapon} do
      player = Player.stand_on(player, @snow)

      assert {:ok,
              %Player{inventory: [^weapon], stand_on: %Loot.ItemBox{type: :bunch, stand_on: @snow, items: [^ammo]}},
              ^ammo} = Player.drop_item(player, ammo.uuid, ammo.count)
    end

    test "drops stackable item (partly)", %{player: player, ammo: ammo, weapon: weapon} do
      player = Player.stand_on(player, @snow)
      drop_count = ammo.count - 5
      new_ammo_count = ammo.count - drop_count

      assert {:ok,
              %Player{
                inventory: [^weapon, %Ammo{count: ^new_ammo_count}],
                stand_on: %Loot.ItemBox{
                  type: :bunch,
                  stand_on: @snow,
                  items: [%Ammo{count: ^drop_count} = dropped_ammo]
                }
              }, dropped_ammo} = Player.drop_item(player, ammo.uuid, drop_count)
    end

    test "drops given item (player already stand on item box)", %{player: player, ammo: ammo, weapon: weapon} do
      item_box = build(:loot_item_box, items: [])
      player = Player.stand_on(player, item_box)

      assert {:ok, %Player{inventory: [^ammo], stand_on: %Loot.ItemBox{items: [^weapon]}}, ^weapon} =
               Player.drop_item(player, weapon.uuid)
    end

    test "retunrs error when item not found", %{player: player} do
      uuid = Ecto.UUID.generate()
      assert Player.drop_item(player, uuid) == {:error, :not_found}
    end
  end

  describe "disassemble_item/2" do
    setup do
      weapon = build(:weapon)
      ammo = build(:ammo, count: 20)
      player = build(:player, inventory: [weapon, ammo])

      {:ok, player: player, weapon: weapon, ammo: ammo}
    end

    test "deletes given item and adds result of disassembly", %{player: player, weapon: weapon, ammo: ammo} do
      assert {:ok, %Player{inventory: [%Tool{}, ^ammo]}, ^weapon} = Player.disassemble_item(player, weapon.uuid)
    end
  end

  describe "equip_item/2" do
    setup do
      weapon = build(:weapon)
      ammo = build(:ammo)
      helmet = build(:helmet)
      suit = build(:suit)
      boots = build(:boots)

      player = build(:player, weapon_uuid: nil, inventory: [weapon, ammo, helmet, suit, boots])

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
      melee_weapon = build(:weapon, equiped: true)
      ammo = build(:ammo)
      helmet = build(:helmet, equiped: true)
      suit = build(:suit, equiped: true)
      boots = build(:boots, equiped: true)

      player = build(:player, weapon_uuid: nil, inventory: [weapon, melee_weapon, ammo, helmet, suit, boots])

      {:ok,
       player: player, weapon: weapon, melee_weapon: melee_weapon, ammo: ammo, helmet: helmet, suit: suit, boots: boots}
    end

    test "unequips items", %{
      player: player,
      weapon: weapon,
      melee_weapon: melee_weapon,
      helmet: helmet,
      suit: suit,
      boots: boots
    } do
      for item <- [weapon, melee_weapon, helmet, suit, boots] do
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

    test "decreases health" do
      suit = build(:suit, max_health: 10)
      player = build(:player, max_health: 100, health: 100, suit_uuid: suit.uuid, inventory: [suit])

      expected_max_health = player.max_health - suit.max_health

      assert {:ok, %Player{max_health: ^expected_max_health, health: ^expected_max_health}} =
               Player.unequip_item(player, suit.uuid)
    end

    test "decreases warm" do
      suit = build(:suit, max_warm: 10)
      player = build(:player, max_warm: 100, warm: 100, suit_uuid: suit.uuid, inventory: [suit])

      expected_max_warm = player.max_warm - suit.max_warm

      assert {:ok, %Player{max_warm: ^expected_max_warm, warm: ^expected_max_warm}} =
               Player.unequip_item(player, suit.uuid)
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
      player = build(:player, weapon_uuid: nil, inventory: [weapon, ammo])

      {:ok, player: player, weapon: weapon, ammo: ammo}
    end

    test "updates given item", %{player: player, ammo: ammo, weapon: weapon} do
      updated_ammo = struct!(ammo, count: 1000)
      assert %Player{inventory: [^weapon, ^updated_ammo]} = Player.update_item(player, updated_ammo)
    end
  end

  describe "delete_item/2" do
    setup do
      weapon = build(:weapon)
      ammo = build(:ammo)
      player = build(:player, weapon_uuid: nil, inventory: [weapon, ammo])

      {:ok, player: player, weapon: weapon, ammo: ammo}
    end

    test "deletes given item", %{player: player, ammo: ammo, weapon: weapon} do
      assert %Player{inventory: [^weapon]} = Player.delete_item(player, ammo)
    end
  end

  describe "tools_amount/2" do
    setup do
      tool1 = build(:tool, type: :weapon_parts, properties: build(:tool_properties, level: 1))
      tool2 = build(:tool, type: :weapon_parts, properties: build(:tool_properties, level: 2))
      player = build(:player, inventory: [tool1])

      {:ok, player: player, tool1: tool1, tool2: tool2}
    end

    test "returns amount of given tool", %{player: player, tool1: tool} do
      assert Player.tools_amount(player, tool) == tool.count
    end

    test "returns 0 when no given tool in inventory", %{player: player, tool2: tool} do
      assert Player.tools_amount(player, tool) == 0
    end
  end

  describe "enough_tools?/2" do
    setup do
      tool1 = build(:tool, type: :weapon_parts, properties: build(:tool_properties, level: 1))
      tool2 = build(:tool, type: :weapon_parts, properties: build(:tool_properties, level: 2))
      tool3 = build(:tool, type: :weapon_parts, properties: build(:tool_properties, level: 2))
      player = build(:player, inventory: [tool1, tool2])

      {:ok, player: player, tool1: tool1, tool2: tool2, tool3: tool3}
    end

    test "returns true if player has enough amount of given tools", %{player: player, tool1: tool1, tool2: tool2} do
      assert Player.enough_tools?(player, [tool1, tool2]) == true
    end

    test "returns false if player hasn't enough amount of given tools", %{
      player: player,
      tool1: tool1,
      tool2: tool2,
      tool3: tool3
    } do
      assert Player.enough_tools?(player, [tool1, tool2, tool3]) == false
    end
  end

  describe "craft_item/2" do
    setup do
      tool1 = build(:tool, name: "tool 1", count: 1, type: :weapon_parts, properties: build(:tool_properties, level: 1))
      tool2 = build(:tool, name: "tool 2", count: 2, type: :weapon_parts, properties: build(:tool_properties, level: 2))
      weapon = build(:weapon)

      {:ok, tool1: tool1, tool2: tool2, weapon: weapon}
    end

    test "adds item and decreases required tools count", %{weapon: weapon, tool1: tool1, tool2: tool2} do
      player = build(:player, inventory: [tool1, tool2])
      blueprint = build(:blueprint, item: weapon, tools: [struct!(tool1, count: 1), struct!(tool2, count: 1)])

      assert {:ok, %Player{inventory: [^weapon, tool]}} = Player.craft_item(player, blueprint)
      assert tool.name == tool2.name
      assert tool.count == 1
    end

    test "returns NotApplicableError when player hasn't enough tools", %{weapon: weapon, tool1: tool1, tool2: tool2} do
      player = build(:player, inventory: [tool1])
      blueprint = build(:blueprint, item: weapon, tools: [struct!(tool1, count: 1), struct!(tool2, count: 1)])

      assert Player.craft_item(player, blueprint) == {:error, %NotApplicableError{}}
    end
  end

  describe "use_tools/2" do
    setup do
      tool1 = build(:tool, name: "tool 1", count: 1, type: :weapon_parts, properties: build(:tool_properties, level: 1))
      tool2 = build(:tool, name: "tool 2", count: 2, type: :weapon_parts, properties: build(:tool_properties, level: 2))

      {:ok, tool1: tool1, tool2: tool2}
    end

    test "decreases tools count", %{tool1: tool1, tool2: tool2} do
      player = build(:player, inventory: [tool1, tool2])

      tools = [
        struct!(tool1, count: 1),
        struct!(tool2, count: 1)
      ]

      assert {:ok, %Player{inventory: [tool]}} = Player.use_tools(player, tools)
      assert tool.name == tool2.name
      assert tool.count == 1
    end

    test "returns NotApplicableError when player hasn't enough tools", %{tool1: tool1, tool2: tool2} do
      player = build(:player, inventory: [tool1])
      assert Player.use_tools(player, [tool1, tool2]) == {:error, %NotApplicableError{}}
    end
  end

  describe "get_equiped_weapon/1" do
    setup do
      weapon = build(:weapon)
      player = build(:player, weapon_uuid: weapon.uuid, inventory: [weapon])

      {:ok, player: player, weapon: weapon}
    end

    test "returns equiped weapon", %{player: player, weapon: weapon} do
      assert Player.get_equiped_weapon(player) == {:ok, weapon}
    end

    test "returns error when no equiped weapon", %{player: player} do
      player = struct!(player, weapon_uuid: nil)
      assert Player.get_equiped_weapon(player) == {:error, :no_weapon}
    end
  end

  describe "get_equiped_helmet/1" do
    setup do
      helmet = build(:helmet)
      player = build(:player, helmet_uuid: helmet.uuid, inventory: [helmet])

      {:ok, player: player, helmet: helmet}
    end

    test "returns equiped helmet", %{player: player, helmet: helmet} do
      assert Player.get_equiped_helmet(player) == {:ok, helmet}
    end

    test "returns error when no equiped helmet", %{player: player} do
      player = struct!(player, helmet_uuid: nil)
      assert Player.get_equiped_helmet(player) == {:error, :no_helmet}
    end
  end

  describe "inventory_weight/1" do
    test "returns 0 when inventory is empty" do
      player = build(:player, inventory: [])
      assert Player.inventory_weight(player) == 0
    end

    test "reuturns inventory items weight" do
      weapon = build(:weapon)
      ammo = build(:ammo, count: 10)
      helmet = build(:helmet)
      suit = build(:suit)
      boots = build(:boots)
      supply = build(:supply, count: 20)
      player = build(:player, inventory: [weapon, ammo, helmet, suit, boots, supply])

      assert Player.inventory_weight(player) ==
               weapon.weight + ammo.weight * ammo.count + helmet.weight + suit.weight + boots.weight +
                 supply.weight * supply.count
    end
  end

  describe "find_weapon_ammo/2" do
    setup do
      weapon = build(:weapon)
      ammo = build(:ammo, caliber: weapon.caliber)

      player = build(:player, weapon_uuid: weapon.uuid, inventory: [weapon, ammo])

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

  describe "increase_radiation/2" do
    setup do
      player = build(:player, radiation: 0)
      {:ok, player: player}
    end

    test "increases player radiation", %{player: player} do
      radiation = 20
      expected_radiation = player.radiation + radiation

      assert %Player{radiation: ^expected_radiation} = Player.increase_radiation(player, radiation)
    end

    test "not increases max radiation", %{player: player} do
      radiation = 100_000
      assert %Player{radiation: @max_radiation} = Player.increase_radiation(player, radiation)
    end

    test "no negative radiation", %{player: player} do
      radiation = -100_000
      assert %Player{radiation: 0} = Player.increase_radiation(player, radiation)
    end
  end

  describe "reload_weapon/1" do
    setup do
      weapon = build(:weapon, rounds_loaded: 10, magazine_size: 20)
      ammo = build(:ammo, caliber: weapon.caliber, count: 100)

      player = build(:player, weapon_uuid: weapon.uuid, inventory: [weapon, ammo])

      {:ok, player: player, weapon: weapon, ammo: ammo}
    end

    test "reloads weapon (enough ammo for full magazine)", %{player: player, weapon: weapon, ammo: ammo} do
      expected_weapon = struct!(weapon, rounds_loaded: weapon.magazine_size)

      expected_ammo = struct!(ammo, count: ammo.count - (weapon.magazine_size - weapon.rounds_loaded))

      assert {:ok, %Player{inventory: [^expected_weapon, ^expected_ammo]}, ^expected_weapon} =
               Player.reload_weapon(player)
    end

    test "reloads weapon (not enough ammo for full magazine)", %{player: player, weapon: weapon, ammo: ammo} do
      ammo = struct!(ammo, count: 1)

      player = struct!(player, inventory: [weapon, ammo])
      expected_weapon = struct!(weapon, rounds_loaded: weapon.rounds_loaded + 1)

      assert {:ok, %Player{inventory: [^expected_weapon]}, ^expected_weapon} =
               Player.reload_weapon(player)
    end

    test "returns no_weapon error", %{player: player} do
      player = struct!(player, weapon_uuid: nil)
      assert Player.reload_weapon(player) == {:error, :no_weapon}
    end

    test "returns no_ammo error", %{player: player, ammo: ammo} do
      player = Player.delete_item(player, ammo)
      assert Player.reload_weapon(player) == {:error, :no_ammo}
    end

    test "returns full_magazine error", %{player: player, weapon: weapon} do
      weapon = struct!(weapon, rounds_loaded: weapon.magazine_size)
      player = Player.update_item(player, weapon)

      assert Player.reload_weapon(player) == {:error, :full_magazine}
    end
  end

  describe "reload_weapon/2" do
    setup do
      weapon = build(:weapon, rounds_loaded: 10, magazine_size: 20)
      ammo = build(:ammo, caliber: weapon.caliber, count: 100)

      player = build(:player, weapon_uuid: nil, inventory: [weapon, ammo])

      {:ok, player: player, weapon: weapon, ammo: ammo}
    end

    test "reloads weapon (enough ammo for full magazine)", %{player: player, weapon: weapon, ammo: ammo} do
      expected_weapon = struct!(weapon, rounds_loaded: weapon.magazine_size)

      expected_ammo = struct!(ammo, count: ammo.count - (weapon.magazine_size - weapon.rounds_loaded))

      assert {:ok, %Player{inventory: [^expected_weapon, ^expected_ammo]}, ^expected_weapon} =
               Player.reload_weapon(player, weapon.uuid)
    end

    test "reloads weapon (not enough ammo for full magazine)", %{player: player, weapon: weapon, ammo: ammo} do
      ammo = struct!(ammo, count: 1)

      player = struct!(player, inventory: [weapon, ammo])
      expected_weapon = struct!(weapon, rounds_loaded: weapon.rounds_loaded + 1)

      assert {:ok, %Player{inventory: [^expected_weapon]}, ^expected_weapon} =
               Player.reload_weapon(player, weapon.uuid)
    end

    test "returns not_found error", %{player: player} do
      weapon_uuid = Ecto.UUID.generate()
      assert Player.reload_weapon(player, weapon_uuid) == {:error, :not_found}
    end

    test "returns no_ammo error", %{player: player, weapon: weapon, ammo: ammo} do
      player = Player.delete_item(player, ammo)
      assert Player.reload_weapon(player, weapon.uuid) == {:error, :no_ammo}
    end

    test "returns full_magazine error", %{player: player, weapon: weapon} do
      weapon = struct!(weapon, rounds_loaded: weapon.magazine_size)
      player = Player.update_item(player, weapon)

      assert Player.reload_weapon(player, weapon.uuid) == {:error, :full_magazine}
    end
  end

  describe "unload_weapon/2" do
    test "returns updated player and weapon" do
      caliber = ".40 S&W"
      rounds_loaded = 15

      weapon = build(:weapon, caliber: caliber, rounds_loaded: rounds_loaded, magazine_size: rounds_loaded * 2)
      ammo = build(:ammo, caliber: caliber, count: 5)
      player = build(:player, inventory: [weapon, ammo])

      assert {:ok, %Player{inventory: [updated_weapon, updated_ammo]}, updated_weapon} =
               Player.unload_weapon(player, weapon.uuid)

      assert updated_weapon.rounds_loaded == 0
      assert updated_ammo.count == ammo.count + rounds_loaded
    end

    test "returns error when weapon not loaded" do
      weapon = build(:weapon, rounds_loaded: 0)
      player = build(:player, inventory: [weapon])

      assert Player.unload_weapon(player, weapon.uuid) == {:error, :empty_magazine}
    end

    test "returns error when weapon not found" do
      weapon_uuid = Ecto.UUID.generate()
      player = build(:player, inventory: [])

      assert Player.unload_weapon(player, weapon_uuid) == {:error, :not_found}
    end
  end

  describe "consume_supply/2" do
    test "heals player" do
      supply = build(:supply, count: 3, properties: build(:supply_properties, health: 15))
      player = build(:player, health: 10, inventory: [supply])

      assert {:ok, %Player{health: updated_health, inventory: [updated_supply]}, updated_supply} =
               Player.consume_supply(player, supply.uuid)

      assert updated_health == player.health + supply.properties.health
      assert updated_supply.count == supply.count - 1
    end

    test "health not exeed max_health" do
      supply = build(:supply, count: 3, properties: build(:supply_properties, health: 1000))
      player = build(:player, health: 10, max_health: 100, inventory: [supply])

      assert {:ok, %Player{health: updated_health}, %Loot.Supply{}} = Player.consume_supply(player, supply.uuid)
      assert updated_health == player.max_health
    end

    test "quenches thirst" do
      supply = build(:supply, count: 3, properties: build(:supply_properties, thirst: -10))
      player = build(:player, thirst: 20, inventory: [supply])

      assert {:ok, %Player{thirst: updated_thirst, inventory: [updated_supply]}, updated_supply} =
               Player.consume_supply(player, supply.uuid)

      assert updated_thirst == player.thirst + supply.properties.thirst
      assert updated_supply.count == supply.count - 1
    end

    test "satisfies hunger" do
      supply = build(:supply, count: 3, properties: build(:supply_properties, hunger: -10))
      player = build(:player, hunger: 20, inventory: [supply])

      assert {:ok, %Player{hunger: updated_hunger, inventory: [updated_supply]}, updated_supply} =
               Player.consume_supply(player, supply.uuid)

      assert updated_hunger == player.hunger + supply.properties.hunger
      assert updated_supply.count == supply.count - 1
    end

    test "supply removes from inventory" do
      supply = build(:supply, count: 1, properties: build(:supply_properties, health: 15))
      player = build(:player, health: 10, inventory: [supply])

      assert {:ok, %Player{inventory: []}, %Loot.Supply{}} = Player.consume_supply(player, supply.uuid)
    end

    test "decreases player radiation" do
      supply = build(:supply, count: 3, properties: build(:supply_properties, radiation: -10))
      player = build(:player, radiation: 100, inventory: [supply])

      assert {:ok, %Player{radiation: updated_radiation, inventory: [updated_supply]}, updated_supply} =
               Player.consume_supply(player, supply.uuid)

      assert updated_radiation == player.radiation + supply.properties.radiation
      assert updated_supply.count == supply.count - 1
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

  describe "tick/2" do
    property "damages frozen player" do
      player = build(:player, health: 100, max_warm: 100, warm: 0)

      check all(_n <- StreamData.integer(1..100)) do
        num_runs = 500
        generator = list_of(constant(:ok), min_length: num_runs, max_length: num_runs)

        check all(_ <- generator) do
          results = Enum.map(1..num_runs, fn _ -> Player.tick(player, 1) end)

          damages_count =
            Enum.count(results, fn {:ok, updated_player, actions} ->
              updated_player.health < player.health &&
                Enum.find(actions, fn action -> action.action_type == :frostbite end)
            end)

          damages_proportion = damages_count / num_runs

          assert damages_proportion >= 0.01
          assert damages_proportion <= 0.4
        end
      end
    end

    property "decreases player warm" do
      player = build(:player, health: 100, max_warm: 100, warm: 100)

      check all(_n <- StreamData.integer(1..100)) do
        num_runs = 500
        generator = list_of(constant(:ok), min_length: num_runs, max_length: num_runs)

        check all(_ <- generator) do
          results = Enum.map(1..num_runs, fn _ -> Player.tick(player, 1) end)

          get_cold_count =
            Enum.count(results, fn {:ok, updated_player, actions} ->
              updated_player.warm < player.warm && Enum.find(actions, fn action -> action.action_type == :get_cold end)
            end)

          get_cold_proportion = get_cold_count / num_runs

          assert get_cold_proportion >= 0.01
          assert get_cold_proportion <= 1.0
        end
      end
    end

    property "damages thirsty player" do
      player = build(:player, health: 100, max_warm: 100, warm: 100, hunger: 0, thirst: 100)

      check all(_n <- StreamData.integer(1..100)) do
        num_runs = 500
        generator = list_of(constant(:ok), min_length: num_runs, max_length: num_runs)

        check all(_ <- generator) do
          results = Enum.map(1..num_runs, fn _ -> Player.tick(player, 1) end)

          damages_count =
            Enum.count(results, fn {:ok, updated_player, actions} ->
              updated_player.health < player.health &&
                Enum.find(actions, fn action -> action.action_type == :dehydration end)
            end)

          damages_proportion = damages_count / num_runs

          assert damages_proportion >= 0.01
          assert damages_proportion <= 0.6
        end
      end
    end

    property "increases player thirst" do
      player = build(:player, health: 100, thirst: 10)

      check all(_n <- StreamData.integer(1..100)) do
        num_runs = 500
        generator = list_of(constant(:ok), min_length: num_runs, max_length: num_runs)

        check all(_ <- generator) do
          results = Enum.map(1..num_runs, fn _ -> Player.tick(player, 1) end)

          get_thirsty_count =
            Enum.count(results, fn {:ok, updated_player, _actions} ->
              updated_player.thirst > player.thirst
            end)

          get_thirsty_proportion = get_thirsty_count / num_runs

          assert get_thirsty_proportion >= 0.01
          assert get_thirsty_proportion <= 1.0
        end
      end
    end

    property "damages hungry player" do
      player = build(:player, health: 100, max_warm: 100, warm: 100, thirst: 0, hunger: 100)

      check all(_n <- StreamData.integer(1..100)) do
        num_runs = 500
        generator = list_of(constant(:ok), min_length: num_runs, max_length: num_runs)

        check all(_ <- generator) do
          results = Enum.map(1..num_runs, fn _ -> Player.tick(player, 1) end)

          damages_count =
            Enum.count(results, fn {:ok, updated_player, actions} ->
              updated_player.health < player.health &&
                Enum.find(actions, fn action -> action.action_type == :hunger end)
            end)

          damages_proportion = damages_count / num_runs

          assert damages_proportion >= 0.01
          assert damages_proportion <= 0.6
        end
      end
    end

    property "increases player hunger" do
      player = build(:player, health: 100, hunger: 10)

      check all(_n <- StreamData.integer(1..100)) do
        num_runs = 500
        generator = list_of(constant(:ok), min_length: num_runs, max_length: num_runs)

        check all(_ <- generator) do
          results = Enum.map(1..num_runs, fn _ -> Player.tick(player, 1) end)

          get_hungry_count =
            Enum.count(results, fn {:ok, updated_player, _actions} ->
              updated_player.hunger > player.hunger
            end)

          get_hungry_proportion = get_hungry_count / num_runs

          assert get_hungry_proportion >= 0.01
          assert get_hungry_proportion <= 1.0
        end
      end
    end

    test "adds radiation when player not wear helmet" do
      player = build(:player, helmet_uuid: nil, radiation: 0)
      expected_action = build(:action, subject: :player, action_type: :radiation_contamination)

      assert {:ok, %Player{radiation: 1}, actions} = Player.tick(player, 1)
      assert expected_action in actions
    end

    test "adds radiation when player not wear suit" do
      player = build(:player, suit_uuid: nil, radiation: 0)
      expected_action = build(:action, subject: :player, action_type: :radiation_contamination)

      assert {:ok, %Player{radiation: 3}, actions} = Player.tick(player, 1)
      assert expected_action in actions
    end

    test "adds radiation when player not wear boots" do
      player = build(:player, boots_uuid: nil, radiation: 0)
      expected_action = build(:action, subject: :player, action_type: :radiation_contamination)

      assert {:ok, %Player{radiation: 1}, actions} = Player.tick(player, 1)
      assert expected_action in actions
    end

    property "damages player with radiation" do
      player =
        build(:player, health: 100, max_warm: 100, warm: 100, thirst: 0, hunger: 0, radiation: div(@max_radiation, 2))

      check all(_n <- StreamData.integer(1..100)) do
        num_runs = 500
        generator = list_of(constant(:ok), min_length: num_runs, max_length: num_runs)

        check all(_ <- generator) do
          results = Enum.map(1..num_runs, fn _ -> Player.tick(player, 1) end)

          damages_count =
            Enum.count(results, fn {:ok, updated_player, actions} ->
              updated_player.health < player.health &&
                Enum.find(actions, fn action -> action.action_type == :radiation_damage end)
            end)

          damages_proportion = damages_count / num_runs

          assert damages_proportion >= 0.01
          assert damages_proportion <= 0.8
        end
      end
    end

    property "decreases player radiation" do
      player = build(:player, radiation: 10)

      check all(_n <- StreamData.integer(1..100)) do
        num_runs = 500
        generator = list_of(constant(:ok), min_length: num_runs, max_length: num_runs)

        check all(_ <- generator) do
          results = Enum.map(1..num_runs, fn _ -> Player.tick(player, 1) end)

          decreased_radiation_count =
            Enum.count(results, fn {:ok, updated_player, _actions} ->
              updated_player.radiation < player.radiation
            end)

          decreased_radiation_proportion = decreased_radiation_count / num_runs

          assert decreased_radiation_proportion >= 0.0001
          assert decreased_radiation_proportion <= 1.0
        end
      end
    end
  end

  defp max_weight_range do
    from = fetch_config!([:game_params, :player, :max_weight, :from])
    to = fetch_config!([:game_params, :player, :max_weight, :to])

    from..to
  end

  defp assert_changed_player_item_uuid(player, updated_item, expected_value) do
    case updated_item do
      %Loot.Weapon{} -> assert player.weapon_uuid == expected_value
      %Loot.MeleeWeapon{} -> assert player.melee_weapon_uuid == expected_value
      %Loot.Helmet{} -> assert player.helmet_uuid == expected_value
      %Loot.Suit{} -> assert player.suit_uuid == expected_value
      %Loot.Boots{} -> assert player.boots_uuid == expected_value
    end
  end
end
