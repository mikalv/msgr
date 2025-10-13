defmodule Messngr.Repo.Migrations.AddDevicePublicKeyFingerprint do
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")

    alter table(:account_devices) do
      add :public_key_fingerprint, :string
    end

    execute("UPDATE account_devices SET public_key_fingerprint = encode(digest(device_public_key, 'sha256'), 'hex')")

    alter table(:account_devices) do
      modify :public_key_fingerprint, :string, null: false
    end

    create unique_index(:account_devices, [:account_id, :public_key_fingerprint],
             name: :account_devices_account_id_public_key_fingerprint_index
           )
  end

  def down do
    drop_if_exists index(:account_devices, [:account_id, :public_key_fingerprint],
             name: :account_devices_account_id_public_key_fingerprint_index
           )

    alter table(:account_devices) do
      remove :public_key_fingerprint
    end
  end
end
