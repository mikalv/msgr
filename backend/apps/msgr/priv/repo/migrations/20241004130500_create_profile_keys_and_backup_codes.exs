defmodule Messngr.Repo.Migrations.CreateProfileKeysAndBackupCodes do
  use Ecto.Migration

  def change do
    create table(:profile_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :profile_id, references(:profiles, type: :binary_id, on_delete: :delete_all), null: false
      add :purpose, :string, null: false
      add :public_key, :text, null: false
      add :fingerprint, :string, null: false
      add :encryption, :map, null: false, default: %{"mode" => "envelope", "kdf" => "hkdf"}
      add :encrypted_payload, :binary
      add :client_snapshot_version, :integer, null: false, default: 1
      add :metadata, :map, null: false, default: %{}
      add :rotated_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:profile_keys, [:profile_id])
    create unique_index(:profile_keys, [:profile_id, :purpose], name: :profile_keys_profile_purpose_index)
    create index(:profile_keys, [:fingerprint])

    create table(:profile_backup_codes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :profile_id, references(:profiles, type: :binary_id, on_delete: :delete_all), null: false
      add :code_hash, :binary, null: false
      add :salt, :binary, null: false
      add :label, :string
      add :generation, :integer, null: false, default: 1
      add :used_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:profile_backup_codes, [:profile_id])
    create index(:profile_backup_codes, [:profile_id, :generation])
  end
end
