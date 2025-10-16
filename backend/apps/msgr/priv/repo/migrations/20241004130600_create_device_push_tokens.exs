defmodule Messngr.Repo.Migrations.CreateDevicePushTokens do
  use Ecto.Migration

  def change do
    create table(:device_push_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :device_id, references(:account_devices, type: :binary_id, on_delete: :delete_all), null: false
      add :profile_id, references(:profiles, type: :binary_id, on_delete: :delete_all), null: false
      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all), null: false
      add :platform, :string, null: false
      add :token, :text, null: false
      add :status, :string, null: false, default: "active"
      add :last_registered_at, :utc_datetime, null: false
      add :metadata, :map, null: false, default: %{}
      add :mode, :string, null: false, default: "private"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:device_push_tokens, [:device_id, :platform], name: :device_push_tokens_device_platform_index)
    create index(:device_push_tokens, [:profile_id])
    create index(:device_push_tokens, [:account_id])
    create index(:device_push_tokens, [:status])
    create index(:device_push_tokens, [:mode])
  end
end
