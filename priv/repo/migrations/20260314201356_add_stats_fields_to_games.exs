defmodule Europa.Repo.Migrations.AddMovesCountAndGreatRedSpotsToGames do
  use Ecto.Migration

  def up do
    alter table(:games) do
      add :moves_count, :integer, default: 0
      add :great_red_spots, :integer, default: 0
      add :killed_enemies, :integer, default: 0
    end
  end

  def down do
    alter table(:games) do
      remove :moves_count
      remove :great_red_spots
      remove :killed_enemies
    end
  end
end
