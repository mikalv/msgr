defmodule Messngr.Repo.Migrations.CreateMessageReceipts do
  use Ecto.Migration

  def change do
    create table(:message_receipts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :message_id, references(:messages, type: :binary_id, on_delete: :delete_all), null: false
      add :recipient_id,
          references(:profiles, type: :binary_id, on_delete: :delete_all),
          null: false
      add :device_id, references(:account_devices, type: :binary_id, on_delete: :nilify_all)
      add :status, :string, null: false, default: "pending"
      add :delivered_at, :utc_datetime
      add :read_at, :utc_datetime
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:message_receipts, [:message_id])
    create index(:message_receipts, [:recipient_id])
    create index(:message_receipts, [:device_id])
    create unique_index(:message_receipts, [:message_id, :recipient_id])
  end
end
