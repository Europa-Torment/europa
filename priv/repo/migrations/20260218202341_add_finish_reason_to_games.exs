defmodule Europa.Repo.Migrations.AddFinishReasonToGames do
  use Ecto.Migration

  def up do
    alter table(:games) do
      add :finish_reason, :string
    end
  end

  def down do
    alter table(:games) do
      remove :finish_reason
    end
  end
end
