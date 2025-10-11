defmodule Teams.Repo.Migrations.CreateFilesTable do
  use Ecto.Migration

  def change do
    create table(:files, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string
      add :url, :string, null: false
      add :mimetype, :string, null: false

      add :profile_id, references(:profiles, type: :binary_id), null: false
      add :message_id, references(:messages), null: false

      add :metadata, :map, default: "{}"
      timestamps(type: :utc_datetime)
    end
  end
end
