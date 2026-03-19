defmodule Teams.Repo.TenantMigrations.CreateDrafts do
  use Ecto.Migration

  def change do
    create table(:drafts, primary_key: false) do
      add :channel_id, references(:channels, type: :binary_id, on_delete: :delete_all),
        primary_key: true, null: false
      add :profile_id, references(:profiles, type: :binary_id, on_delete: :delete_all),
        primary_key: true, null: false
      add :content, :map, default: %{}
      add :updated_at, :utc_datetime, null: false, default: fragment("now()")
    end
  end
end
