defmodule Europa.Server.Loot.Weapon.ToolTest do
  use Europa.DataCase

  alias Europa.Server.Loot.Tool

  describe "decrease_count/2" do
    test "decreases supply count" do
      n = 7
      supply = build(:tool, count: 10)
      assert %Tool{count: 3} = Tool.decrease_count(supply, n)
    end

    test "no negative value" do
      n = 20
      supply = build(:tool, count: 10)
      assert %Tool{count: 0} = Tool.decrease_count(supply, n)
    end
  end

  describe "from_weapon/1" do
    test "build weapon parts from weapon" do
      level = 2
      parts_count = 5
      weapon = build(:weapon, level: level, parts_count: parts_count)

      assert [%Tool{type: :weapon_parts, name: name, count: count}] = Tool.from_weapon(weapon)
      assert name == "Weapon parts #{level}"
      assert count == parts_count - 1
    end
  end
end
