defmodule Teams.Repo.Migrations.CreateReactionsTable do
  use Ecto.Migration

  def change do
    create table(:reactions) do
      add :profile_id, references(:profiles, type: :binary_id), null: false
      add :message_id, references(:messages), null: false
      add :reaction_id, :string

      timestamps(type: :utc_datetime)
    end
  end
end
