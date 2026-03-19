defmodule Teams.Repo.TenantMigrations.CreateReadCursors do
  use Ecto.Migration

  def change do
    create table(:read_cursors, primary_key: false) do
      add :channel_id, references(:channels, type: :binary_id, on_delete: :delete_all),
        primary_key: true, null: false
      add :profile_id, references(:profiles, type: :binary_id, on_delete: :delete_all),
        primary_key: true, null: false
      add :last_read_message_id, references(:messages, type: :binary_id, on_delete: :nilify_all)
    end
  end
end
