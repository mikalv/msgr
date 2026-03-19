defmodule Teams.Repo.TenantMigrations.CreateMediaUploads do
  use Ecto.Migration

  def change do
    create table(:media_uploads, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :profile_id, references(:profiles, type: :binary_id, on_delete: :nilify_all)
      add :object_key, :string, null: false
      add :content_type, :string
      add :filename, :string
      add :size, :bigint
      add :checksum, :string

      timestamps(type: :utc_datetime)
    end

    create index(:media_uploads, [:profile_id])
  end
end
