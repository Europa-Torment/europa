defmodule Europa.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games) do
      add :uuid, :string, null: false
      add :state, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:games, [:user_id])
  end
end
