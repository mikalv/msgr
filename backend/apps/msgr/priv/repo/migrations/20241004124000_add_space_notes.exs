defmodule Messngr.Repo.Migrations.AddSpaceNotes do
  use Ecto.Migration

  def change do
    create table(:space_notes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :space_id, references(:spaces, type: :binary_id, on_delete: :delete_all), null: false
      add :created_by_profile_id, references(:profiles, type: :binary_id, on_delete: :nilify_all), null: false
      add :updated_by_profile_id, references(:profiles, type: :binary_id, on_delete: :nilify_all)
      add :title, :string, null: false
      add :body, :text
      add :color, :string
      add :pinned, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:space_notes, [:space_id])
    create index(:space_notes, [:pinned])
  end
end
