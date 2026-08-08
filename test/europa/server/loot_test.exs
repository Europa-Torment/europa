defmodule Europa.Server.Loot.ItemTest do
  use Europa.DataCase, async: true

  alias Europa.Server.Loot
  alias Europa.Server.Loot.Item
  alias Europa.Server.Loot.Weapon
  alias Europa.Server.Loot.Tool
  alias Europa.Server.Errors
  alias Europa.Server.PlayerManagerMock

  setup :verify_on_exit!

  describe "item_type/1" do
    test "returns item type" do
      for item <- [
            build(:weapon),
            build(:ammo),
            build(:tool),
            build(:resource),
            build(:melee_weapon),
            build(:helmet),
            build(:suit),
            build(:boots),
            build(:supply),
            build(:implant)
          ] do
        assert Item.item_type(item) |> is_atom()
      end
    end
  end

  describe "item_subtype/1" do
    test "returns item subtype" do
      for item <- [
            build(:weapon),
            build(:ammo),
            build(:tool),
            build(:resource),
            build(:melee_weapon),
            build(:helmet),
            build(:suit),
            build(:boots),
            build(:supply),
            build(:implant)
          ] do
        assert Item.item_subtype(item) |> is_atom()
      end
    end
  end

  describe "composed_name/1" do
    test "returns string with item name" do
      for item <- [
            build(:weapon),
            build(:ammo),
            build(:tool),
            build(:resource),
            build(:melee_weapon),
            build(:helmet),
            build(:suit),
            build(:boots),
            build(:supply),
            build(:implant)
          ] do
        assert Item.composed_name(item) |> is_binary()
      end
    end
  end

  describe "description/1" do
    test "returns string with item description" do
      for item <- [
            build(:weapon),
            build(:ammo),
            build(:tool),
            build(:resource),
            build(:melee_weapon),
            build(:helmet),
            build(:suit),
            build(:boots),
            build(:supply),
            build(:implant)
          ] do
        assert Item.description(item) |> is_binary()
      end
    end
  end

  describe "id/1" do
    test "returns item id" do
      for item <- [
            build(:weapon),
            build(:ammo),
            build(:tool),
            build(:resource),
            build(:melee_weapon),
            build(:helmet),
            build(:suit),
            build(:boots),
            build(:supply),
            build(:implant)
          ] do
        assert Item.id(item) |> is_atom()
      end
    end
  end

  describe "negative_attrs/1" do
    test "returns list of atoms" do
      for item <- [
            build(:weapon),
            build(:ammo),
            build(:tool),
            build(:resource),
            build(:melee_weapon),
            build(:helmet),
            build(:suit),
            build(:boots),
            build(:supply),
            build(:implant)
          ] do
        assert Item.negative_attrs(item) |> Enum.all?(&is_atom/1)
      end
    end
  end

  describe "readable_attrs/1" do
    setup do
      player = build(:player)
      {:ok, player: player}
    end

    test "returns attrs for weapon", %{player: player} do
      weapon = build(:weapon)

      PlayerManagerMock
      |> expect(:weapon_damage, fn ^player, ^weapon -> weapon.damage end)

      expected_attrs = [
        {:name, "Name", weapon.name},
        {:damage, "Damage", weapon.damage},
        {:accuracy, "Accuracy", weapon.accuracy},
        {:shooting_distance, "Shooting distance", weapon.shooting_distance},
        {:shooting_type, "Shooting type", weapon.shooting_type},
        {:shot_cost, "Shot cost", weapon.shot_cost},
        {:reload_cost, "Reload cost", weapon.reload_cost},
        {:magazine_size, "Magazine", weapon.magazine_size},
        {:rounds_loaded, "Loaded", weapon.rounds_loaded},
        {:caliber, "Caliber", weapon.caliber},
        {:weight, "Weight", weapon.weight}
      ]

      assert Item.readable_attrs(weapon, player) == expected_attrs
    end

    test "returns attrs for ammo", %{player: player} do
      ammo = build(:ammo)

      expected_attrs = [
        {:caliber, "Caliber", ammo.caliber},
        {:count, "Count", ammo.count},
        {:weight, "Weight", ammo.count * ammo.weight}
      ]

      assert Item.readable_attrs(ammo, player) == expected_attrs
    end

    test "returns attrs for tool", %{player: player} do
      tool = build(:tool)

      expected_attrs = [
        {:level, "Level", tool.properties.level},
        {:count, "Count", tool.count},
        {:weight, "Weight", tool.count * tool.weight}
      ]

      assert Item.readable_attrs(tool, player) == expected_attrs
    end

    test "returns attrs for resource", %{player: player} do
      resource = build(:resource)

      expected_attrs = [
        {:name, "Name", resource.name},
        {:count, "Count", resource.count},
        {:weight, "Weight", resource.count * resource.weight}
      ]

      assert Item.readable_attrs(resource, player) == expected_attrs
    end

    test "returns attrs for melee weapon", %{player: player} do
      melee_weapon = build(:melee_weapon)

      PlayerManagerMock
      |> expect(:melee_weapon_damage, fn ^player, ^melee_weapon -> melee_weapon.damage end)

      expected_attrs = [
        {:name, "Name", melee_weapon.name},
        {:damage, "Damage", melee_weapon.damage},
        {:hit_cost, "Hit cost", melee_weapon.hit_cost},
        {:weight, "Weight", melee_weapon.weight}
      ]

      assert Item.readable_attrs(melee_weapon, player) == expected_attrs
    end

    test "returns attrs for helmet", %{player: player} do
      helmet = build(:helmet)

      expected_attrs = [
        {:name, "Name", helmet.name},
        {:accuracy, "Accuracy", helmet.accuracy},
        {:health, "Health", helmet.max_health},
        {:warm, "Warm", helmet.max_warm},
        {:weight, "Weight", helmet.weight}
      ]

      assert Item.readable_attrs(helmet, player) == expected_attrs
    end

    test "returns attrs for suit", %{player: player} do
      suit = build(:suit)

      expected_attrs = [
        {:name, "Name", suit.name},
        {:efficiency, "Efficiency", suit.efficiency},
        {:health, "Health", suit.max_health},
        {:warm, "Warm", suit.max_warm},
        {:max_weight, "Max weight", suit.max_weight},
        {:weight, "Weight", suit.weight}
      ]

      assert Item.readable_attrs(suit, player) == expected_attrs
    end

    test "returns attrs for boots", %{player: player} do
      boots = build(:boots)

      expected_attrs = [
        {:name, "Name", boots.name},
        {:efficiency, "Efficiency", boots.efficiency},
        {:health, "Health", boots.max_health},
        {:warm, "Warm", boots.max_warm},
        {:weight, "Weight", boots.weight}
      ]

      assert Item.readable_attrs(boots, player) == expected_attrs
    end

    test "returns attrs for supply", %{player: player} do
      supply = build(:supply)

      expected_attrs = [
        {:health, "Health", supply.properties.health},
        {:hunger, "Hunger", supply.properties.hunger},
        {:radiation, "Radiation", supply.properties.radiation},
        {:thirst, "Thirst", supply.properties.thirst},
        {:warm, "Warm", supply.properties.warm},
        {:count, "Count", supply.count},
        {:consume_cost, "Consume cost", supply.consume_cost},
        {:weight, "Weight", supply.count * supply.weight}
      ]

      assert Item.readable_attrs(supply, player) == expected_attrs
    end

    test "returns attrs for implant", %{player: player} do
      implant = build(:implant)

      expected_attrs = [
        {:accuracy, "Accuracy", implant.properties.accuracy},
        {:efficiency, "Efficiency", implant.properties.efficiency},
        {:max_health, "Health", implant.properties.max_health},
        {:max_warm, "Warm", implant.properties.max_warm},
        {:max_weight, "Max weight", implant.properties.max_weight},
        {:melee_damage, "Melee weapon damage", implant.properties.melee_damage},
        {:shoot_damage, "Shoot damage", implant.properties.shoot_damage},
        {:shotgun_damage, "Shotgun damage", implant.properties.shotgun_damage},
        {:weight, "Weight", implant.weight}
      ]

      assert Item.readable_attrs(implant, player) == expected_attrs
    end
  end

  describe "consumable?/1" do
    test "returns false for weapon" do
      weapon = build(:weapon)
      assert Item.consumable?(weapon) == false
    end

    test "returns false for ammo" do
      ammo = build(:ammo)
      assert Item.consumable?(ammo) == false
    end

    test "returns false for tool" do
      tool = build(:tool)
      assert Item.consumable?(tool) == false
    end

    test "returns false for resource" do
      resource = build(:resource)
      assert Item.consumable?(resource) == false
    end

    test "returns false for melee weapon" do
      melee_weapon = build(:melee_weapon)
      assert Item.consumable?(melee_weapon) == false
    end

    test "returns false for helmet" do
      helmet = build(:helmet)
      assert Item.consumable?(helmet) == false
    end

    test "returns false for suit" do
      suit = build(:suit)
      assert Item.consumable?(suit) == false
    end

    test "returns false for boots" do
      boots = build(:boots)
      assert Item.consumable?(boots) == false
    end

    test "returns true for supply" do
      supply = build(:supply)
      assert Item.consumable?(supply) == true
    end

    test "returns false for implant" do
      implant = build(:implant)
      assert Item.consumable?(implant) == false
    end
  end

  describe "usable?/1" do
    test "returns false for weapon" do
      weapon = build(:weapon)
      assert Item.usable?(weapon) == false
    end

    test "returns false for ammo" do
      ammo = build(:ammo)
      assert Item.usable?(ammo) == false
    end

    test "returns true or false for tool" do
      tool1 = build(:tool, using_type: nil)
      tool2 = build(:tool, using_type: {:put_object, :bonfire})

      assert Item.usable?(tool1) == false
      assert Item.usable?(tool2) == true
    end

    test "returns false for resource" do
      resource = build(:resource)
      assert Item.usable?(resource) == false
    end

    test "returns false for melee weapon" do
      melee_weapon = build(:melee_weapon)
      assert Item.usable?(melee_weapon) == false
    end

    test "returns false for helmet" do
      helmet = build(:helmet)
      assert Item.usable?(helmet) == false
    end

    test "returns false for suit" do
      suit = build(:suit)
      assert Item.usable?(suit) == false
    end

    test "returns false for boots" do
      boots = build(:boots)
      assert Item.usable?(boots) == false
    end

    test "returns false for supply" do
      supply = build(:supply)
      assert Item.usable?(supply) == false
    end

    test "returns false for implant" do
      implant = build(:implant)
      assert Item.usable?(implant) == false
    end
  end

  describe "equipable?/1" do
    test "returns true for weapon" do
      weapon = build(:weapon)
      assert Item.equipable?(weapon) == true
    end

    test "returns false for ammo" do
      ammo = build(:ammo)
      assert Item.equipable?(ammo) == false
    end

    test "returns false for tool" do
      tool = build(:tool)
      assert Item.equipable?(tool) == false
    end

    test "returns false for resource" do
      resource = build(:resource)
      assert Item.equipable?(resource) == false
    end

    test "returns true for melee weapon" do
      melee_weapon = build(:melee_weapon)
      assert Item.equipable?(melee_weapon) == true
    end

    test "returns true for helmet" do
      helmet = build(:helmet)
      assert Item.equipable?(helmet) == true
    end

    test "returns true for suit" do
      suit = build(:suit)
      assert Item.equipable?(suit) == true
    end

    test "returns true for boots" do
      boots = build(:boots)
      assert Item.equipable?(boots) == true
    end

    test "returns false for supply" do
      supply = build(:supply)
      assert Item.equipable?(supply) == false
    end

    test "returns true for implant" do
      implant = build(:implant)
      assert Item.equipable?(implant) == true
    end
  end

  describe "stackable?/1" do
    test "returns false for weapon" do
      weapon = build(:weapon)
      assert Item.stackable?(weapon) == false
    end

    test "returns true for ammo" do
      ammo = build(:ammo)
      assert Item.stackable?(ammo) == true
    end

    test "returns true for tool" do
      tool = build(:tool)
      assert Item.stackable?(tool) == true
    end

    test "returns true for resource" do
      resource = build(:resource)
      assert Item.stackable?(resource) == true
    end

    test "returns false for melee weapon" do
      melee_weapon = build(:melee_weapon)
      assert Item.stackable?(melee_weapon) == false
    end

    test "returns false for helmet" do
      helmet = build(:helmet)
      assert Item.stackable?(helmet) == false
    end

    test "returns false for suit" do
      suit = build(:suit)
      assert Item.stackable?(suit) == false
    end

    test "returns false for boots" do
      boots = build(:boots)
      assert Item.stackable?(boots) == false
    end

    test "returns true for supply" do
      supply = build(:supply)
      assert Item.stackable?(supply) == true
    end

    test "returns false for implant" do
      implant = build(:implant)
      assert Item.stackable?(implant) == false
    end
  end

  describe "weight/1" do
    test "returns weapon weight" do
      weapon = build(:weapon)
      assert Item.weight(weapon) == weapon.weight
    end

    test "returns ammo weight" do
      ammo = build(:ammo, count: 100)
      assert Item.weight(ammo) == ammo.count * ammo.weight
    end

    test "returns tool weight" do
      tool = build(:tool, count: 100)
      assert Item.weight(tool) == tool.count * tool.weight
    end

    test "returns resource weight" do
      resource = build(:resource, count: 100)
      assert Item.weight(resource) == resource.count * resource.weight
    end

    test "returns melee weapon weight" do
      melee_weapon = build(:melee_weapon)
      assert Item.weight(melee_weapon) == melee_weapon.weight
    end

    test "returns helmet weight" do
      helmet = build(:helmet)
      assert Item.weight(helmet) == helmet.weight
    end

    test "returns suit weight" do
      suit = build(:suit)
      assert Item.weight(suit) == suit.weight
    end

    test "returns boots weight" do
      boots = build(:boots)
      assert Item.weight(boots) == boots.weight
    end

    test "returns supply weight" do
      supply = build(:supply, count: 20)
      assert Item.weight(supply) == supply.count * supply.weight
    end

    test "returns implant weight" do
      implant = build(:implant)
      assert Item.weight(implant) == implant.weight
    end
  end

  describe "equip/1" do
    test "changes equipped to true" do
      items = [
        build(:weapon, equipped: false),
        build(:melee_weapon, equipped: false),
        build(:helmet, equipped: false),
        build(:suit, equipped: false),
        build(:boots, equipped: false),
        build(:implant)
      ]

      for item <- items do
        assert {:ok, updated_item} = Item.equip(item)

        unless Item.item_type(item) == :implant do
          assert updated_item.equipped == true
        end
      end
    end

    test "returns NotApplicableError" do
      items = [
        build(:ammo),
        build(:supply),
        build(:tool),
        build(:resource)
      ]

      for item <- items do
        assert Item.equip(item) == {:error, %Errors.NotApplicableError{}}
      end
    end
  end

  describe "unequip/1" do
    test "changes equipped to true" do
      items = [
        build(:weapon, equipped: true),
        build(:melee_weapon, equipped: true),
        build(:helmet, equipped: true),
        build(:suit, equipped: true),
        build(:boots, equipped: true),
        build(:implant)
      ]

      for item <- items do
        assert {:ok, updated_item} = Item.unequip(item)

        unless Item.item_type(item) == :implant do
          assert updated_item.equipped == false
        end
      end
    end

    test "returns NotApplicableError" do
      items = [
        build(:ammo),
        build(:supply),
        build(:tool),
        build(:resource)
      ]

      for item <- items do
        assert Item.unequip(item) == {:error, %Errors.NotApplicableError{}}
      end
    end
  end
end

defmodule Europa.Server.Loot.ItemBoxTest do
  use Europa.DataCase

  alias Europa.Server.Loot
  alias Europa.Server.Loot.ItemBox
  alias Europa.Server.Loot.Weapon
  alias Europa.Server.Loot.Weapon.Ammo
  alias Europa.Server.Errors

  describe "from_map/1" do
    test "parses item box from map" do
      attrs = %{
        type: "monster_body",
        readable_name: "Monster corpse",
        max_items: 4,
        item_types: %{weapon: "all", ammo: ["pistol"], melee_weapon: "all", helmet: "all", suit: "all", boots: "all"},
        movable: true,
        image_name: "monster_corpse",
        placing: "furniture",
        random_weight: 1.0
      }

      assert %ItemBox{} = item_box = ItemBox.from_map(attrs)
      assert item_box.type == :monster_body
      assert item_box.readable_name == "Monster corpse"
      assert item_box.max_items == 4

      assert item_box.item_types == %{
               weapon: :all,
               ammo: [:pistol],
               melee_weapon: :all,
               helmet: :all,
               suit: :all,
               boots: :all
             }

      assert item_box.image_name == "monster_corpse"
      assert item_box.placing == :furniture
    end

    test "parses item box from map (all item types allowed)" do
      attrs = %{
        type: "monster_body",
        readable_name: "Monster corpse",
        max_items: 4,
        item_types: "all",
        movable: true,
        image_name: "monster_corpse",
        placing: "outdoor",
        random_weight: 1.0
      }

      assert %ItemBox{item_types: :all} = ItemBox.from_map(attrs)
    end
  end

  describe "readable_name/1" do
    test "returns string with item box name" do
      for type <- Loot.allowed_item_box_types() do
        item_box = build(:loot_item_box, type: type)
        assert ItemBox.readable_name(item_box) |> is_binary()
      end
    end
  end

  describe "add_item/2" do
    setup do
      weapon = build(:weapon)
      ammo = build(:ammo)
      item_box = build(:loot_item_box, items: [weapon])

      {:ok, item_box: item_box, weapon: weapon, ammo: ammo}
    end

    test "adds item", %{item_box: item_box, weapon: weapon, ammo: ammo} do
      assert %ItemBox{items: [^ammo, ^weapon]} = ItemBox.add_item(item_box, ammo)
    end
  end

  describe "take_item/2" do
    setup do
      item_box = build(:loot_item_box, items: build_list(5, :weapon))
      {:ok, item_box: item_box}
    end

    test "takes item with given uuid and removes it from item box", %{item_box: item_box} do
      item = Enum.random(item_box.items)
      assert {:ok, ^item, updated_item_box} = ItemBox.take_item(item_box, item.uuid)

      refute Enum.any?(updated_item_box.items, &(&1 == item))
    end

    test "returns error when there is no item with given uuid", %{item_box: item_box} do
      assert {:error, :no_item} = ItemBox.take_item(item_box, "fake")
    end
  end

  describe "unload_weapon/2" do
    test "unloads weapon" do
      ammo_count = 52
      caliber = ".40 S&W"

      weapon = build(:weapon, rounds_loaded: ammo_count, caliber: caliber)
      item_box = build(:loot_item_box, items: [weapon])

      assert {:ok, %ItemBox{items: [%Ammo{caliber: ^caliber, count: ^ammo_count}, %Weapon{rounds_loaded: 0} = weapon]},
              weapon} =
               ItemBox.unload_weapon(item_box, weapon.uuid)
    end

    test "returns not applicable error" do
      ammo = build(:ammo)
      item_box = build(:loot_item_box, items: [ammo])

      assert ItemBox.unload_weapon(item_box, ammo.uuid) == {:error, %Errors.NotApplicableError{}}
    end

    test "returns no_item error" do
      uuid = Ecto.UUID.generate()
      item_box = build(:loot_item_box)

      assert ItemBox.unload_weapon(item_box, uuid) == {:error, :no_item}
    end

    test "returns empty_magazine error" do
      weapon = build(:weapon, rounds_loaded: 0)
      item_box = build(:loot_item_box, items: [weapon])

      assert ItemBox.unload_weapon(item_box, weapon.uuid) == {:error, :empty_magazine}
    end
  end
end

defmodule Europa.Server.LootTest do
  use Europa.DataCase, async: true

  alias Europa.Server.Loot
  alias Europa.Server.Loot.Item
  alias Europa.Server.Loot.Weapon
  alias Europa.Server.Loot.Weapon.Ammo
  alias Europa.Server.Loot.MeleeWeapon
  alias Europa.Server.Loot.Helmet
  alias Europa.Server.Loot.Suit
  alias Europa.Server.Loot.Boots
  alias Europa.Server.Loot.Supply
  alias Europa.Server.Loot.Tool
  alias Europa.Server.Loot.Resource
  alias Europa.Server.Loot.Implant
  alias Europa.Server.Loot.Blueprints
  alias Europa.Server.Loot.Blueprints.Blueprint
  alias Europa.Server.Errors

  describe "generate_item/1" do
    test "generates item of given type" do
      assert %Weapon{} = Loot.generate_item(:weapon)
      assert %Ammo{} = Loot.generate_item(:ammo)
    end
  end

  describe "generate_item/2" do
    test "generates item of given type and subtype" do
      subtype = :plant
      assert %Supply{subtype: ^subtype} = Loot.generate_item(:supply, [subtype])
    end
  end

  describe "generate_item_by_id/1" do
    test "generates item of given type and id" do
      id = :guard_pistol
      assert %Weapon{id: ^id} = Loot.generate_item_by_id(:weapon, id)
    end
  end

  describe "generate_item_box/0" do
    test "generates random item box" do
      assert %Loot.ItemBox{items: items} = Loot.generate_item_box()
      assert is_list(items)

      assert Enum.all?(items, fn item -> item?(item) end)
    end
  end

  describe "generate_item_box_from_enemy/1" do
    test "generates monster_body item box" do
      max_items = 20
      enemy = build(:enemy, max_items: max_items)

      assert %Loot.ItemBox{items: items} = Loot.generate_item_box_from_enemy(enemy)
      assert is_list(items)
      assert Enum.count(items) in 0..max_items

      assert Enum.all?(items, fn item -> item?(item) end)
    end
  end

  describe "generate_item_box_from_npc/1" do
    test "generates human_body item box" do
      weapon = build(:weapon)
      npc = build(:npc, weapon: weapon)

      assert %Loot.ItemBox{items: items} = Loot.generate_item_box_from_npc(npc)
      assert is_list(items)

      assert Enum.all?(items, fn item -> item?(item) end)
      assert weapon in items
    end
  end

  describe "movable_item_box_types/0" do
    test "returns list of item_box types" do
      assert Loot.movable_item_box_types() |> Enum.any?(&is_atom/1)
    end
  end

  describe "item_box_image" do
    test "returns item_box image" do
      Loot.allowed_item_box_types()
      |> Enum.each(fn ib ->
        assert Loot.item_box_image(ib) |> is_binary()
      end)
    end
  end

  describe "item_disassemblable?/1" do
    test "returns true or false" do
      ammo = build(:ammo)
      %Blueprint{item: item} = Blueprints.blueprints() |> List.first()

      assert Loot.item_disassemblable?(item) == true
      assert Loot.item_disassemblable?(ammo) == false
    end
  end

  describe "disassemble_item/2" do
    test "returns list of tools for item" do
      %Blueprint{item: item, resources: expected_resources} = Blueprints.blueprints() |> List.first()
      expected_resources_id = Enum.map(expected_resources, & &1.id)
      assert {:ok, resources} = Loot.disassemble_item(item)

      assert Enum.count(resources) == Enum.count(expected_resources)
      assert Enum.all?(resources, fn %Resource{} = resource -> resource.id in expected_resources_id end)
    end

    test "returns list of tools for item (count > 1)" do
      %Blueprint{item: item, resources: expected_resources} = Blueprints.blueprints() |> List.first()
      item = struct!(item, count: 10)
      count = 5

      assert {:ok, resources} = Loot.disassemble_item(item, count)

      assert Enum.all?(resources, fn resource ->
               resource.count == Enum.find(expected_resources, &(&1.id == resource.id)).count * count
             end)
    end

    test "returns NotApplicable error (item not disassembable)" do
      ammo = build(:ammo)
      assert Loot.disassemble_item(ammo) == {:error, %Errors.NotApplicableError{}}
    end

    test "returns NotApplicable error (item not stackable and count > 1)" do
      %Blueprint{item: item} = Blueprints.blueprints() |> Enum.find(&(not Loot.Item.stackable?(&1.item)))
      assert Loot.disassemble_item(item, 2) == {:error, %Errors.NotApplicableError{}}
    end

    test "returns NotApplicable error (item stackable but count > item.count)" do
      %Blueprint{item: item} = Blueprints.blueprints() |> Enum.find(&Loot.Item.stackable?(&1.item))
      assert Loot.disassemble_item(item, 2000) == {:error, %Errors.NotApplicableError{}}
    end

    test "returns NotApplicable error (count < 1)" do
      %Blueprint{item: item} = Blueprints.blueprints() |> Enum.find(&Loot.Item.stackable?(&1.item))
      assert Loot.disassemble_item(item, 0) == {:error, %Errors.NotApplicableError{}}
    end
  end

  describe "decrease_item_count/2" do
    test "decreases item count" do
      n = 7
      supply = build(:supply, count: 10)
      assert %Supply{count: 3} = Loot.decrease_item_count(supply, n)
    end

    test "no negative value" do
      n = 20
      supply = build(:supply, count: 10)
      assert %Supply{count: 0} = Loot.decrease_item_count(supply, n)
    end
  end

  defp item?(%Helmet{}), do: true
  defp item?(%Suit{}), do: true
  defp item?(%Boots{}), do: true
  defp item?(%Weapon{}), do: true
  defp item?(%MeleeWeapon{}), do: true
  defp item?(%Ammo{}), do: true
  defp item?(%Tool{}), do: true
  defp item?(%Resource{}), do: true
  defp item?(%Supply{}), do: true
  defp item?(%Implant{}), do: true
  defp item?(_), do: false
end
