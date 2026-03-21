defmodule Teams.Repo.TenantMigrations.CreateCommandExecutions do
  use Ecto.Migration

  def change do
    create table(:command_executions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :app_id, :binary_id, null: false
      add :command_name, :text, null: false
      add :channel_id, references(:channels, type: :binary_id, on_delete: :delete_all)
      add :triggered_by, references(:profiles, type: :binary_id, on_delete: :nilify_all)
      add :args, :map
      add :status, :text, default: "pending"
      add :result, :map
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime

      add :inserted_at, :utc_datetime, default: fragment("now()")
    end

    create index(:command_executions, [:channel_id])
    create index(:command_executions, [:app_id])
  end
end
