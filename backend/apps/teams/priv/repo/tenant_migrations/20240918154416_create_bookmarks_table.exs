defmodule Teams.Repo.Migrations.CreateBookmarksTable do
  use Ecto.Migration

  def change do
    create table(:bookmarks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :profile_id, references(:profiles, type: :binary_id), null: true
      add :room_id, references(:rooms, type: :binary_id), null: true
      add :message_id, references(:messages), null: false
      add :title, :string
      add :url, :string

      add :metadata, :map, default: "{}"
      timestamps(type: :utc_datetime)
    end
  end
end
