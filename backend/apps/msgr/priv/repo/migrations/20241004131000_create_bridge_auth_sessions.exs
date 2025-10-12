defmodule Messngr.Repo.Migrations.CreateBridgeAuthSessions do
  use Ecto.Migration

  def change do
    create table(:bridge_auth_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all), null: false
      add :service, :string, null: false
      add :state, :string, null: false
      add :login_method, :string, null: false
      add :auth_surface, :string, null: false
      add :client_context, :map, null: false, default: %{}
      add :metadata, :map, null: false, default: %{}
      add :catalog_snapshot, :map, null: false, default: %{}
      add :expires_at, :utc_datetime_usec
      add :last_transition_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:bridge_auth_sessions, [:account_id])
    create index(:bridge_auth_sessions, [:service])
    create index(:bridge_auth_sessions, [:state])
  end
end
