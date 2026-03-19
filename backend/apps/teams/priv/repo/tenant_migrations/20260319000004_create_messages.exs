defmodule Teams.Repo.TenantMigrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :channel_id, references(:channels, type: :binary_id, on_delete: :delete_all), null: false
      add :sender_profile_id, references(:profiles, type: :binary_id, on_delete: :nilify_all)
      add :thread_parent_id, references(:messages, type: :binary_id, on_delete: :nilify_all)
      add :content, :map, default: %{}
      add :media_refs, {:array, :string}, default: []
      add :edited_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:channel_id])
    create index(:messages, [:thread_parent_id])
    create index(:messages, [:sender_profile_id])
  end
end
