defmodule Teams.Repo.TenantMigrations.AddReplyToIdToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :reply_to_id, references(:messages, type: :binary_id, on_delete: :nilify_all)
    end
  end
end
