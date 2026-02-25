defmodule Europa.Server.Loot.ItemTest do
  use Europa.DataCase, async: true

  alias Europa.Server.Loot
  alias Europa.Server.Loot.Item
  alias Europa.Server.Loot.Weapon
  alias Europa.Server.Errors

  describe "composed_name/1" do
    test "returns string with item name" do
      for item <- [build(:weapon), build(:ammo), build(:helmet), build(:suit), build(:boots)] do
        assert Item.composed_name(item) |> is_binary()
      end
    end
  end

  describe "readable_attrs/1" do
    test "returns attrs for weapon" do
      weapon = build(:weapon)

      expected_attrs = [
        {"Name", weapon.name},
        {"Damage", weapon.damage},
        {"Accuracy", weapon.accuracy},
        {"Shooting distance", weapon.shooting_distance},
        {"Shooting type", weapon.shooting_type},
        {"Shot cost", weapon.shot_cost},
        {"Reload cost", weapon.reload_cost},
        {"Magazine", weapon.magazine_size},
        {"Loaded", weapon.rounds_loaded},
        {"Caliber", weapon.caliber}
      ]

      assert Item.readable_attrs(weapon) == expected_attrs
    end

    test "returns attrs for ammo" do
      ammo = build(:ammo)

      expected_attrs = [
        {"Caliber", ammo.caliber},
        {"Count", ammo.count}
      ]

      assert Item.readable_attrs(ammo) == expected_attrs
    end

    test "returns attrs for helmet" do
      helmet = build(:helmet)

      expected_attrs = [
        {"Name", helmet.name},
        {"Accuracy", helmet.accuracy},
        {"Health", helmet.max_health}
      ]

      assert Item.readable_attrs(helmet) == expected_attrs
    end

    test "returns attrs for suit" do
      suit = build(:suit)

      expected_attrs = [
        {"Name", suit.name},
        {"Efficiency", suit.efficiency},
        {"Health", suit.max_health}
      ]

      assert Item.readable_attrs(suit) == expected_attrs
    end

    test "returns attrs for boots" do
      boots = build(:boots)

      expected_attrs = [
        {"Name", boots.name},
        {"Efficiency", boots.efficiency},
        {"Health", boots.max_health}
      ]

      assert Item.readable_attrs(boots) == expected_attrs
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
      caliber = "9mm"

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
  alias Europa.Server.Loot.Helmet
  alias Europa.Server.Loot.Suit
  alias Europa.Server.Loot.Boots

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

  defp item?(%Helmet{}), do: true
  defp item?(%Suit{}), do: true
  defp item?(%Boots{}), do: true
  defp item?(%Weapon{}), do: true
  defp item?(%Ammo{}), do: true
  defp item?(_), do: false
end
