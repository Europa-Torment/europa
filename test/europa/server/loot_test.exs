defmodule Europa.Server.Loot.ItemTest do
  use Europa.DataCase, async: true

  alias Europa.Server.Loot
  alias Europa.Server.Loot.Item
  alias Europa.Server.Loot.Weapon
  alias Europa.Server.Loot.Tool
  alias Europa.Server.Errors

  describe "composed_name/1" do
    test "returns string with item name" do
      for item <- [
            build(:weapon),
            build(:ammo),
            build(:tool),
            build(:melee_weapon),
            build(:helmet),
            build(:suit),
            build(:boots),
            build(:supply)
          ] do
        assert Item.composed_name(item) |> is_binary()
      end
    end
  end

  describe "negative_attrs/1" do
    test "returns list of atoms" do
      for item <- [
            build(:weapon),
            build(:ammo),
            build(:tool),
            build(:melee_weapon),
            build(:helmet),
            build(:suit),
            build(:boots),
            build(:supply)
          ] do
        assert Item.negative_attrs(item) |> Enum.all?(&is_atom/1)
      end
    end
  end

  describe "readable_attrs/1" do
    test "returns attrs for weapon" do
      weapon = build(:weapon)

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

      assert Item.readable_attrs(weapon) == expected_attrs
    end

    test "returns attrs for ammo" do
      ammo = build(:ammo)

      expected_attrs = [
        {:caliber, "Caliber", ammo.caliber},
        {:count, "Count", ammo.count},
        {:weight, "Weight", ammo.count * ammo.weight}
      ]

      assert Item.readable_attrs(ammo) == expected_attrs
    end

    test "returns attrs for tool" do
      tool = build(:tool)

      expected_attrs = [
        {:level, "Level", tool.properties.level},
        {:count, "Count", tool.count},
        {:weight, "Weight", tool.count * tool.weight}
      ]

      assert Item.readable_attrs(tool) == expected_attrs
    end

    test "returns attrs for melee weapon" do
      melee_weapon = build(:melee_weapon)

      expected_attrs = [
        {:name, "Name", melee_weapon.name},
        {:damage, "Damage", melee_weapon.damage},
        {:hit_cost, "Hit cost", melee_weapon.hit_cost},
        {:weight, "Weight", melee_weapon.weight}
      ]

      assert Item.readable_attrs(melee_weapon) == expected_attrs
    end

    test "returns attrs for helmet" do
      helmet = build(:helmet)

      expected_attrs = [
        {:name, "Name", helmet.name},
        {:accuracy, "Accuracy", helmet.accuracy},
        {:health, "Health", helmet.max_health},
        {:warm, "Warm", helmet.max_warm},
        {:weight, "Weight", helmet.weight}
      ]

      assert Item.readable_attrs(helmet) == expected_attrs
    end

    test "returns attrs for suit" do
      suit = build(:suit)

      expected_attrs = [
        {:name, "Name", suit.name},
        {:efficiency, "Efficiency", suit.efficiency},
        {:health, "Health", suit.max_health},
        {:warm, "Warm", suit.max_warm},
        {:max_weight, "Max weight", suit.max_weight},
        {:weight, "Weight", suit.weight}
      ]

      assert Item.readable_attrs(suit) == expected_attrs
    end

    test "returns attrs for boots" do
      boots = build(:boots)

      expected_attrs = [
        {:name, "Name", boots.name},
        {:efficiency, "Efficiency", boots.efficiency},
        {:health, "Health", boots.max_health},
        {:warm, "Warm", boots.max_warm},
        {:weight, "Weight", boots.weight}
      ]

      assert Item.readable_attrs(boots) == expected_attrs
    end

    test "returns attrs for supply" do
      supply =
        build(:supply,
          properties: build(:supply_properties, health: 11, thirst: 12, hunger: 13, radiation: 14, warm: 15)
        )

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

      assert Item.readable_attrs(supply) == expected_attrs
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
      ammo = build(:supply)
      assert Item.equipable?(ammo) == false
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
  end

  describe "disassemblable?/1" do
    test "returns true for weapon" do
      weapon = build(:weapon)
      assert Item.disassemblable?(weapon) == true
    end

    test "returns false for ammo" do
      ammo = build(:ammo)
      assert Item.disassemblable?(ammo) == false
    end

    test "returns false for tool" do
      tool = build(:tool)
      assert Item.disassemblable?(tool) == false
    end

    test "returns false for melee weapon" do
      melee_weapon = build(:melee_weapon)
      assert Item.disassemblable?(melee_weapon) == false
    end

    test "returns false for helmet" do
      helmet = build(:helmet)
      assert Item.disassemblable?(helmet) == false
    end

    test "returns false for suit" do
      suit = build(:suit)
      assert Item.disassemblable?(suit) == false
    end

    test "returns false for boots" do
      boots = build(:boots)
      assert Item.disassemblable?(boots) == false
    end

    test "returns false for supply" do
      supply = build(:supply)
      assert Item.disassemblable?(supply) == false
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
  end

  describe "equip/1" do
    test "changes equiped to true" do
      weapon = build(:weapon, equiped: false)
      assert {:ok, %Weapon{equiped: true}} = Item.equip(weapon)
    end

    test "returns not_applicable error" do
      ammo = build(:ammo)
      assert Item.equip(ammo) == {:error, %Errors.NotApplicableError{}}
    end
  end

  describe "disassemble/1" do
    test "returns list of tools for weapon" do
      weapon = build(:weapon)
      assert {:ok, [%Tool{}]} = Item.disassemble(weapon)
    end

    test "returns not_applicable error" do
      ammo = build(:ammo)
      assert Item.disassemble(ammo) == {:error, %Errors.NotApplicableError{}}
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
  use ExUnit.Case

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
  alias Europa.Server.Loot.Blueprint

  describe "generate_item/1" do
    test "generates item of given type" do
      assert %Weapon{} = Loot.generate_item(:weapon)
      assert %Ammo{} = Loot.generate_item(:ammo)
    end
  end

  describe "generate_item_box/0" do
    test "generates random item box" do
      assert %Loot.ItemBox{items: items} = Loot.generate_item_box()
      assert is_list(items)

      assert Enum.all?(items, fn item -> item?(item) end)
    end
  end

  describe "blueprints/0" do
    test "returns list of blueprints" do
      blueprints = Loot.blueprints()

      assert Enum.all?(blueprints, fn %Blueprint{item: item, tools: tools} ->
               item?(item) && Enum.all?(tools, &tool?/1)
             end)
    end
  end

  defp item?(%Helmet{}), do: true
  defp item?(%Suit{}), do: true
  defp item?(%Boots{}), do: true
  defp item?(%Weapon{}), do: true
  defp item?(%MeleeWeapon{}), do: true
  defp item?(%Ammo{}), do: true
  defp item?(%Tool{}), do: true
  defp item?(%Supply{}), do: true
  defp item?(_), do: false

  defp tool?(%Tool{}), do: true
  defp tool?(_), do: false
end
