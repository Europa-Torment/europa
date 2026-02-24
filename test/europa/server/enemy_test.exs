defmodule Europa.Server.EnemyTest do
  use Europa.DataCase, async: true

  alias Europa.Server.Enemy
  alias Europa.Server.Planet

  @snow Planet.snow()
  @snow_blood Planet.snow_blood()

  @initial_stand_on_tile @snow

  describe "new/1" do
    test "builds enemy struct" do
      expected_enemy = build(:enemy)

      attrs =
        expected_enemy
        |> Map.from_struct()
        |> Map.put(:type, to_string(expected_enemy.type))

      assert Enemy.new(attrs) == expected_enemy
    end
  end

  describe "readable_stats/1" do
    test "returns stats" do
      enemy = build(:enemy)

      expected_stats = [
        {"Name", enemy.name},
        {"Health", enemy.health},
        {"Accuracy", enemy.accuracy},
        {"Damage", enemy.damage},
        {"Move distance", enemy.move_distance}
      ]

      assert Enemy.readable_stats(enemy) == expected_stats
    end
  end

  describe "generate_enemy/0" do
    test "generates enemy" do
      assert %Enemy{} = enemy = Enemy.generate_enemy()

      assert is_binary(enemy.name)

      assert enemy.stand_on == @initial_stand_on_tile

      assert_pos_integer(enemy.health)
      assert_pos_integer(enemy.damage)
      assert_pos_integer(enemy.move_distance)
      assert_pos_integer(enemy.accuracy)
    end
  end

  describe "stand_on/2" do
    setup do
      enemy = build(:enemy, stand_on: @snow)
      {:ok, enemy: enemy}
    end

    test "changes stand_on", %{enemy: enemy} do
      assert %Enemy{stand_on: @snow_blood} = Enemy.stand_on(enemy, @snow_blood)
    end
  end

  describe "take_damage/2" do
    setup do
      enemy = build(:enemy, health: 100)
      {:ok, enemy: enemy}
    end

    test "decreases enemy health", %{enemy: enemy} do
      damage = 10
      expected_health = enemy.health - damage
      assert %Enemy{health: ^expected_health} = Enemy.take_damage(enemy, damage)
    end

    test "no negative health", %{enemy: enemy} do
      damage = enemy.health * 2
      assert %Enemy{health: 0} = Enemy.take_damage(enemy, damage)
    end
  end

  defp assert_pos_integer(value) do
    assert is_integer(value)
    assert value > 0
  end
end
