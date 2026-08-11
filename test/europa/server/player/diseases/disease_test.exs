defmodule Europa.Server.Player.Diseases.DiseaseTest do
  use Europa.DataCase, async: true

  alias Europa.Server.Player.Diseases
  alias Europa.Server.Player.Diseases.Disease

  describe "from_map/1" do
    test "builds disease struct" do
      raw_disease = %{
        id: "alcoholism",
        name: "Alcoholism",
        progression_possibility: 20,
        moves_to_recovery: 1000,
        moves_to_recovery_penalty: 5,
        debuffs: %{
          efficiency: -5,
          extra_moves_count: 1,
          max_warm: -10
        }
      }

      assert %Disease{
               id: :alcoholism,
               name: "Alcoholism",
               progression_possibility: 20,
               moves_to_recovery: 1000,
               moves_to_recovery_penalty: 5,
               debuffs: %Disease.Debuffs{
                 efficiency: -5,
                 extra_moves_count: 1,
                 max_warm: -10
               }
             } = Disease.from_map(raw_disease)
    end
  end

  describe "readable_name/1" do
    test "returns string" do
      disease = Diseases.diseases() |> List.first()
      assert Disease.readable_name(disease) |> is_binary()
    end
  end

  describe "readable_befuffs/1" do
    test "returns readable debuffs" do
      disease = build(:disease)

      expected_readable_debuffs = [
        {:accuracy, "Accuracy", disease.debuffs.accuracy},
        {:damage, "Periodically damage", disease.debuffs.damage},
        {:efficiency, "Efficiency", disease.debuffs.efficiency},
        {:extra_moves_count, "Additional moves count", disease.debuffs.extra_moves_count},
        {:max_health, "Max health", disease.debuffs.max_health},
        {:max_warm, "Max warm", disease.debuffs.max_warm}
      ]

      assert Disease.readable_debuffs(disease) == expected_readable_debuffs
    end
  end

  describe "player_stats_changes/1" do
    test "returns player stats changes" do
      disease = build(:disease)

      assert Disease.player_stats_changes(disease) == %{
               accuracy: disease.debuffs.accuracy,
               efficiency: disease.debuffs.efficiency,
               max_health: disease.debuffs.max_health,
               max_warm: disease.debuffs.max_warm
             }
    end
  end

  describe "progress_recovery/1" do
    test "decreases moves_to_recovery" do
      disease = build(:disease, moves_to_recovery: 10)
      %Disease{moves_to_recovery: 9} = Disease.progress_recovery(disease)
    end
  end

  describe "increase_moves_to_recovery/1" do
    test "increases moves_to_recovery" do
      disease = build(:disease, moves_to_recovery: 10, moves_to_recovery_penalty: 5)
      %Disease{moves_to_recovery: 15} = Disease.increase_moves_to_recovery(disease)
    end
  end

  describe "change_statisfaction/2" do
    test "changes satisfaction" do
      disease = build(:disease, satisfaction: 90)
      assert %Disease{satisfaction: 100} = Disease.change_satisfaction(disease, 10)
      assert %Disease{satisfaction: 80} = Disease.change_satisfaction(disease, -10)
      assert %Disease{satisfaction: 0} = Disease.change_satisfaction(disease, -100)
      assert %Disease{satisfaction: 100} = Disease.change_satisfaction(disease, 10000)
    end
  end
end
