defmodule Messngr.Repo.Migrations.AddEncryptedMessageKindAndE2eeKeys do
  use Ecto.Migration

  def up do
    execute("ALTER TYPE message_kind ADD VALUE IF NOT EXISTS 'encrypted'")

    create table(:e2ee_device_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :profile_id, references(:profiles, type: :binary_id, on_delete: :delete_all), null: false
      add :device_id, :string, null: false
      add :identity_key, :binary, null: false
      add :signed_prekey, :binary, null: false
      add :spk_id, :integer, null: false
      add :spk_signature, :binary, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:e2ee_device_keys, [:profile_id, :device_id])
    create index(:e2ee_device_keys, [:profile_id])

    create table(:e2ee_one_time_prekeys, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :device_key_id,
          references(:e2ee_device_keys, type: :binary_id, on_delete: :delete_all),
          null: false

      add :opk_id, :integer, null: false
      add :public_key, :binary, null: false
      add :used_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:e2ee_one_time_prekeys, [:device_key_id, :opk_id])
    create index(:e2ee_one_time_prekeys, [:device_key_id, :used_at])
  end

  def down do
    drop table(:e2ee_one_time_prekeys)
    drop table(:e2ee_device_keys)
    # Postgres cannot remove enum values safely; leave 'encrypted' in place.
  end
end
