defmodule Europa.Server.EnemyTest do
  use Europa.DataCase, async: true
  use ExUnitProperties

  alias Europa.Server.Enemy
  alias Europa.Server.Event
  alias Europa.Server.Planet.Tiles

  @snow Tiles.tile(:snow).atom_value
  @snow_blood Tiles.tile(:snow).blood_version

  describe "new/1" do
    test "builds enemy struct" do
      uuid = Ecto.UUID.generate()
      expected_enemy = build(:enemy, stand_on: nil)

      attrs =
        expected_enemy
        |> Map.from_struct()
        |> Map.put(:type, to_string(expected_enemy.type))

      assert Enemy.new(attrs) |> struct!(uuid: uuid) == struct!(expected_enemy, uuid: uuid)
    end
  end

  describe "readable_stats/1" do
    test "returns stats" do
      for {move_distance, damage_factor} <- [{1, ""}, {2, "x2"}, {10, "x10"}] do
        enemy = build(:enemy, move_distance: move_distance)

        expected_stats = [
          {"Name", enemy.name},
          {"Health", enemy.health},
          {"Accuracy", enemy.accuracy},
          {"Damage", "#{enemy.damage}" <> damage_factor},
          {"Move distance", enemy.move_distance}
        ]

        assert Enemy.readable_stats(enemy) == expected_stats
      end
    end
  end

  describe "generate_enemy/0" do
    test "generates enemy" do
      assert %Enemy{} = enemy = Enemy.generate_enemy()

      assert is_binary(enemy.name)

      assert is_nil(enemy.stand_on)

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

  describe "trigger/2" do
    test "sets enemy trigger" do
      enemy = build(:enemy, target: nil)
      npc_uuid = build(:npc).uuid

      assert %Enemy{target: :player} = Enemy.trigger(enemy, :player)
      assert %Enemy{target: ^npc_uuid} = Enemy.trigger(enemy, npc_uuid)
      assert %Enemy{target: nil} = Enemy.trigger(enemy, nil)
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

      assert %Enemy{health: ^expected_health, events: [%Event{type: {:damaged, ^damage}}]} =
               Enemy.take_damage(enemy, damage)
    end

    test "no negative health", %{enemy: enemy} do
      damage = enemy.health * 2
      assert %Enemy{health: 0} = Enemy.take_damage(enemy, damage)
    end
  end

  describe "heal/2" do
    setup do
      enemy = build(:enemy, health: 100, max_health: 150)
      {:ok, enemy: enemy}
    end

    test "increases enemy health", %{enemy: enemy} do
      health = 10
      expected_health = enemy.health + health

      assert %Enemy{health: ^expected_health, events: [%Event{type: {:healed, ^health}}]} =
               Enemy.heal(enemy, health)
    end

    test "health not increases max_health", %{enemy: enemy} do
      health = enemy.max_health * 2
      enemy = Enemy.heal(enemy, health)

      assert enemy.health == enemy.max_health
    end
  end

  describe "healer?/1" do
    test "returns true if enemy is healer" do
      assert build(:enemy, healer?: true, heal_possibility: 1, heal_unit: 1) |> Enemy.healer?() == true
    end

    test "returns false if enemy is not healer" do
      assert build(:enemy, healer?: true, heal_possibility: 1, heal_unit: 0) |> Enemy.healer?() == false
      assert build(:enemy, healer?: true, heal_possibility: 0, heal_unit: 1) |> Enemy.healer?() == false
      assert build(:enemy, healer?: false, heal_possibility: 1, heal_unit: 1) |> Enemy.healer?() == false
    end
  end

  describe "add_events/2" do
    setup do
      enemy = build(:enemy, events: [])
      {:ok, enemy: enemy}
    end

    test "add events", %{enemy: enemy} do
      event = build(:event)
      assert %Enemy{events: [added_event]} = Enemy.add_events(enemy, [event])
      assert added_event.type == event.type
    end
  end

  describe "maybe_add_speech_event/1" do
    property "adds speech event" do
      enemy = build(:enemy, phrases: ["one", "two"])

      check all(_n <- StreamData.integer(1..100)) do
        num_runs = 500
        generator = list_of(constant(:ok), min_length: num_runs, max_length: num_runs)

        check all(_ <- generator) do
          results = Enum.map(1..num_runs, fn _ -> Enemy.maybe_add_speech_event(enemy) end)

          with_event_count =
            Enum.count(results, fn %Enemy{events: events} ->
              Enum.find(events, fn
                %Event{type: {:speech, text}} -> text in enemy.phrases
                _ -> false
              end)
            end)

          with_event_proportion = with_event_count / num_runs

          assert with_event_proportion >= 0.01
          assert with_event_proportion <= 0.4
        end
      end
    end
  end

  defp assert_pos_integer(value) do
    assert is_integer(value)
    assert value > 0
  end
end
