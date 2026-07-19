defmodule Europa.Server.NpcTest do
  use Europa.DataCase, async: true
  use ExUnitProperties

  alias Europa.Server.Npc
  alias Europa.Server.Planet
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Event

  @snow Tiles.tile(:snow).atom_value
  @snow_blood Tiles.tile(:snow).blood_version

  describe "new/2" do
    test "creates NPC" do
      character = build(:character)
      assert %Npc{character: ^character, stand_on: @snow} = Npc.new(character, @snow)
    end
  end

  describe "readable_stats/1" do
    test "returns stats" do
      npc = build(:npc, character: build(:character, gender: :female))

      expected_stats =
        [
          {"Name", npc.character.name},
          {"Age", npc.character.current_age},
          {"Gender", "Female"},
          {"Health", npc.health},
          {"Aggressive", "No"}
        ]

      assert Npc.readable_stats(npc) == expected_stats
    end
  end

  describe "take_damage/2" do
    setup do
      npc = build(:npc, health: 100)
      {:ok, npc: npc}
    end

    test "decreases npc health", %{npc: npc} do
      damage = 10
      expected_health = npc.health - damage

      assert %Npc{health: ^expected_health, events: [%Event{type: {:damaged, ^damage}}]} =
               Npc.take_damage(npc, damage)
    end

    test "no negative health", %{npc: npc} do
      damage = npc.health * 2
      assert %Npc{health: 0} = Npc.take_damage(npc, damage)
    end
  end

  describe "add_events/2" do
    setup do
      npc = build(:npc, events: [])
      {:ok, npc: npc}
    end

    test "add events", %{npc: npc} do
      event = build(:event)
      assert %Npc{events: [added_event]} = Npc.add_events(npc, [event])
      assert added_event.type == event.type
    end
  end

  describe "maybe_add_speech_event/1" do
    property "adds speech event" do
      npc = build(:npc, character: build(:character, short_phrases: ["one", "two"]))

      check all(_n <- StreamData.integer(1..100)) do
        num_runs = 500
        generator = list_of(constant(:ok), min_length: num_runs, max_length: num_runs)

        check all(_ <- generator) do
          results = Enum.map(1..num_runs, fn _ -> Npc.maybe_add_speech_event(npc) end)

          with_event_count =
            Enum.count(results, fn %Npc{events: events} ->
              Enum.find(events, fn
                %Event{type: {:speech, text}} -> text in npc.character.short_phrases
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

  describe "trigger/2" do
    test "sets npc trigger" do
      npc = build(:npc, target: nil)
      enemy_uuid = build(:enemy).uuid

      assert %Npc{target: :player} = Npc.trigger(npc, :player)
      assert %Npc{target: ^enemy_uuid} = Npc.trigger(npc, enemy_uuid)
      assert %Npc{target: nil} = Npc.trigger(npc, nil)
    end
  end

  describe "change_view_direction/2" do
    setup do
      npc = build(:npc, view_direction: :up)
      {:ok, npc: npc}
    end

    test "changes view_direction", %{npc: npc} do
      for direction <- Planet.allowed_directions() do
        assert %Npc{view_direction: ^direction} = Npc.change_view_direction(npc, direction)
      end
    end

    test "does nothing when direction not allowed", %{npc: npc} do
      assert Npc.change_view_direction(npc, :fake) == npc
    end
  end

  describe "stand_on/2" do
    setup do
      npc = build(:npc, stand_on: @snow)
      {:ok, npc: npc}
    end

    test "changes stand_on", %{npc: npc} do
      assert %Npc{stand_on: @snow_blood} = Npc.stand_on(npc, @snow_blood)
    end
  end
end
