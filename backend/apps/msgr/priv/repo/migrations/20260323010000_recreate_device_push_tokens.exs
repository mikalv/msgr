defmodule Messngr.Repo.Migrations.RecreateDevicePushTokens do
  use Ecto.Migration

  def change do
    create table(:device_push_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :text, null: false
      add :platform, :string, null: false, default: "apns"  # apns, fcm
      add :device_name, :string
      add :enabled, :boolean, default: true
      timestamps(type: :utc_datetime)
    end

    create unique_index(:device_push_tokens, [:account_id, :token])
    create index(:device_push_tokens, [:account_id])
  end
end
