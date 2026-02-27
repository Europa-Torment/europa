defmodule Europa.Server.Loot.Weapon.SupplyTest do
  use Europa.DataCase

  alias Europa.Server.Loot.Supply

  describe "decrease_count/2" do
    test "decreases supply count" do
      n = 7
      supply = build(:supply, count: 10)
      assert %Supply{count: 3} = Supply.decrease_count(supply, n)
    end

    test "no negative value" do
      n = 20
      supply = build(:supply, count: 10)
      assert %Supply{count: 0} = Supply.decrease_count(supply, n)
    end
  end
end
