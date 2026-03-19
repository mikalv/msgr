defmodule Teams.Repo.TenantMigrations.CreateReactions do
  use Ecto.Migration

  def change do
    create table(:reactions, primary_key: false) do
      add :message_id, references(:messages, type: :binary_id, on_delete: :delete_all),
        primary_key: true, null: false
      add :profile_id, references(:profiles, type: :binary_id, on_delete: :delete_all),
        primary_key: true, null: false
      add :emoji, :string, primary_key: true, null: false
    end
  end
end
