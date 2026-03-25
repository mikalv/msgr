defmodule Teams.Repo.Migrations.AllowNullMessageIdOnReminders do
  use Ecto.Migration

  def change do
    alter table(:message_reminders) do
      modify :message_id, :binary_id, null: true
    end
  end
end
