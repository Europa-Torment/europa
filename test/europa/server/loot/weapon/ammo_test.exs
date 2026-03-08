defmodule Europa.Server.Loot.Weapon.AmmoTest do
  use Europa.DataCase

  alias Europa.Server.Loot.Weapon.Ammo

  describe "decrease_count/2" do
    test "decreases ammo count" do
      n = 7
      ammo = build(:ammo, count: 10)
      assert %Ammo{count: 3} = Ammo.decrease_count(ammo, n)
    end

    test "no negative value" do
      n = 20
      ammo = build(:ammo, count: 10)
      assert %Ammo{count: 0} = Ammo.decrease_count(ammo, n)
    end
  end

  describe "weight/1" do
    test "returns ammo weight by caliber" do
      assert Ammo.weight("9mm") |> is_number()
    end
  end
end
