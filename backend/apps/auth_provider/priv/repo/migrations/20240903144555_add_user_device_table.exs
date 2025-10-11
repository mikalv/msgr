defmodule Messngr.Repo.Migrations.AddUserDeviceTable do
  use Ecto.Migration

  def change do
    create table(:account_user_devices, primary_key: false) do
      add :user_id, references(:account_users, on_delete: :delete_all, type: :binary_id), primary_key: true
      add :device_id, references(:account_devices, on_delete: :delete_all, type: :binary_id), primary_key: true
      timestamps(type: :utc_datetime)
    end
  end
end
