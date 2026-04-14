defmodule Europa.Repo.Migrations.AddDaysToGames do
  use Ecto.Migration

  def up do
    alter table(:games) do
      add :days, :integer, default: 0
    end
  end

  def down do
    alter table(:games) do
      remove :days
    end
  end
end
