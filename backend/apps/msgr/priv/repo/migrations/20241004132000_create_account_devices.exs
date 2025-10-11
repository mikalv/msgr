defmodule Messngr.Repo.Migrations.CreateAccountDevices do
  use Ecto.Migration

  def change do
    create table(:account_devices, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all), null: false
      add :profile_id, references(:profiles, type: :binary_id, on_delete: :nilify_all)
      add :device_public_key, :string, null: false
      add :attesters, {:array, :map}, default: [], null: false
      add :last_handshake_at, :utc_datetime
      add :enabled, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:account_devices, [:account_id])
    create index(:account_devices, [:profile_id])

    create unique_index(:account_devices, [:account_id, :device_public_key],
             name: :account_devices_account_id_device_public_key_index
           )
  end
end
