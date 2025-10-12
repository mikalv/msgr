defmodule Messngr.Repo.Migrations.CreateBridgeData do
  use Ecto.Migration

  def change do
    create table(:bridge_accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all), null: false
      add :service, :string, null: false
      add :external_id, :string
      add :display_name, :string
      add :session, :map, null: false, default: %{}
      add :capabilities, :map, null: false, default: %{}
      add :metadata, :map, null: false, default: %{}
      add :last_synced_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:bridge_accounts, [:account_id, :service])

    create table(:bridge_contacts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :bridge_account_id, references(:bridge_accounts, type: :binary_id, on_delete: :delete_all),
        null: false
      add :external_id, :string, null: false
      add :display_name, :string
      add :handle, :string
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:bridge_contacts, [:bridge_account_id])
    create unique_index(:bridge_contacts, [:bridge_account_id, :external_id])

    create table(:bridge_channels, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :bridge_account_id, references(:bridge_accounts, type: :binary_id, on_delete: :delete_all),
        null: false
      add :external_id, :string, null: false
      add :name, :string
      add :kind, :string, null: false, default: "chat"
      add :topic, :string
      add :role, :string
      add :muted, :boolean, default: false, null: false
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:bridge_channels, [:bridge_account_id])
    create unique_index(:bridge_channels, [:bridge_account_id, :external_id])
  end
end
