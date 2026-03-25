defmodule Teams.Repo.Migrations.CreateMessageReminders do
  use Ecto.Migration

  def change do
    create table(:message_reminders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :message_id, references(:messages, type: :binary_id, on_delete: :delete_all), null: false
      add :channel_id, :binary_id, null: false
      add :profile_id, references(:profiles, type: :binary_id, on_delete: :delete_all), null: false
      add :remind_at, :utc_datetime, null: false
      add :delivered, :boolean, null: false, default: false
      add :message_preview, :text

      timestamps(type: :utc_datetime)
    end

    create index(:message_reminders, [:profile_id])
    create index(:message_reminders, [:remind_at, :delivered])
  end
end
