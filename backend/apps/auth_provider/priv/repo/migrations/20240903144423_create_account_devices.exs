defmodule Messngr.Repo.Migrations.CreateAccountDevices do
  use Ecto.Migration

  def change do
    create table(:account_devices, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :device_id, :string
      add :public_key_sign, :string
      add :public_key_dh, :string
      add :device_info, :map
      add :metadata, :map, default: "{}"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:account_devices, [:public_key_sign])
  end
end
