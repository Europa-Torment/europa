defmodule Europa.Server.Loot.WeaponTest do
  use Europa.DataCase

  alias Europa.Server.Loot.Weapon

  import Europa.Tools.Conf

  @burst_bullets_per_shot fetch_config!([:weapons, :burst_bullets_per_shot])

  describe "decrease_rounds_loaded/2" do
    test "decreases weapon loaded" do
      n = 7
      weapon = build(:weapon, rounds_loaded: 10)
      assert %Weapon{rounds_loaded: 3} = Weapon.decrease_rounds_loaded(weapon, n)
    end

    test "no negative value" do
      n = 20
      weapon = build(:weapon, rounds_loaded: 10)
      assert %Weapon{rounds_loaded: 0} = Weapon.decrease_rounds_loaded(weapon, n)
    end
  end

  describe "add_rounds/2" do
    test "increases rounds_loaded" do
      n = 15
      weapon = build(:weapon, rounds_loaded: 10)
      assert %Weapon{rounds_loaded: 25} = Weapon.add_rounds(weapon, n)
    end
  end

  describe "rounds_per_shot/1" do
    test "returns rounds count for weapon with burst shooting type (full magazine)" do
      weapon = build(:weapon, shooting_type: :burst, magazine_size: 100, rounds_loaded: 100)
      assert Weapon.rounds_per_shot(weapon) == @burst_bullets_per_shot
    end

    test "returns rounds count for weapon with burst shooting type (almost empty magazine)" do
      weapon = build(:weapon, shooting_type: :burst, magazine_size: 100, rounds_loaded: 1)
      assert Weapon.rounds_per_shot(weapon) == weapon.rounds_loaded
    end

    test "returns 1 for weapon with bullet shooting type" do
      weapon = build(:weapon, shooting_type: :bullet, magazine_size: 100, rounds_loaded: 100)
      assert Weapon.rounds_per_shot(weapon) == 1
    end

    test "returns 1 for weapon with shot shooting type" do
      weapon = build(:weapon, shooting_type: :shot, magazine_size: 100, rounds_loaded: 100)
      assert Weapon.rounds_per_shot(weapon) == 1
    end
  end

  describe "check_reload_needed/1" do
    test "returns ok when reload needed" do
      weapon = build(:weapon, shooting_type: :bullet, magazine_size: 100, rounds_loaded: 99)
      assert Weapon.check_reload_needed(weapon) == :ok
    end

    test "returns full_magazine error when reload not needed" do
      weapon = build(:weapon, shooting_type: :bullet, magazine_size: 100, rounds_loaded: 100)
      assert Weapon.check_reload_needed(weapon) == {:error, :full_magazine}
    end
  end

  describe "rounds_to_full_magazine/1" do
    test "returns rounds count" do
      weapon = build(:weapon, shooting_type: :bullet, magazine_size: 100, rounds_loaded: 95)
      assert Weapon.rounds_to_full_magazine(weapon) == {:ok, 5}
    end

    test "returns full_magazine error when reload not needed" do
      weapon = build(:weapon, shooting_type: :bullet, magazine_size: 100, rounds_loaded: 100)
      assert Weapon.rounds_to_full_magazine(weapon) == {:error, :full_magazine}
    end
  end

  describe "unload/1" do
    test "returns unloaded weapon and ammo" do
      ammo_count = 25
      caliber = ".40 S&W"

      weapon = build(:weapon, rounds_loaded: ammo_count, magazine_size: 30, caliber: caliber)

      assert {:ok, {%Weapon{rounds_loaded: 0}, %Weapon.Ammo{count: ^ammo_count, caliber: ^caliber}}} =
               Weapon.unload(weapon)
    end

    test "returns error when weapon not loaded" do
      weapon = build(:weapon, rounds_loaded: 0)
      assert Weapon.unload(weapon) == {:error, :empty_magazine}
    end
  end
end
