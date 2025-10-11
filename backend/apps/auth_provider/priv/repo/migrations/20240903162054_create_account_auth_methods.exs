defmodule Messngr.Repo.Migrations.CreateAccountAuthMethods do
  use Ecto.Migration

  def change do
    create table(:account_auth_methods, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :auth_type, :string, null: false
      add :value, :string, null: false
      add :is_disabled, :boolean, default: false, null: false
      add :metadata, :map, default: "{}"
      add :user_id, references(:account_users, on_delete: :nothing, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:account_auth_methods, [:user_id])
  end
end
