defmodule Teams.Repo.Migrations.CreateMarkCursorTable do
  use Ecto.Migration

  def change do
    create table(:mark_cursors, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :profile_id, references(:conversations, type: :binary_id), null: false
      add :device_id, :string, unique: true
      # TODO: I think we can use UUID v6 here?
      add :cursor, :string, null: false

      add :metadata, :map, default: "{}"
      timestamps(type: :utc_datetime)
    end

    create unique_index(:mark_cursors, [:profile_id, :device_id])
  end
end
