defmodule Teams.Repo.TenantMigrations.AddPinnedToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :pinned, :boolean, default: false
      add :pinned_at, :utc_datetime
      add :pinned_by_profile_id, references(:profiles, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:messages, [:channel_id], where: "pinned = true", name: :messages_pinned_channel_idx)
  end
end
