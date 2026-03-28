defmodule Messngr.Repo.Migrations.CreateAccountDevicesV2 do
  use Ecto.Migration

  def change do
    # Add new columns to the existing account_devices table for URI-based identity
    alter table(:account_devices) do
      add_if_not_exists :resource, :string
      add_if_not_exists :full_uri, :string
      add_if_not_exists :push_token, :map
      add_if_not_exists :noise_public_key, :binary
      add_if_not_exists :last_seen_at, :utc_datetime
    end

    create_if_not_exists unique_index(:account_devices, [:full_uri],
                           where: "full_uri IS NOT NULL"
                         )
  end
end
