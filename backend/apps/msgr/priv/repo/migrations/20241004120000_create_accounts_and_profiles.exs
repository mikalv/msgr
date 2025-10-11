defmodule Messngr.Repo.Migrations.CreateAccountsAndProfiles do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS citext", "DROP EXTENSION IF EXISTS citext")

    create table(:accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext
      add :phone_number, :string
      add :display_name, :string, null: false
      add :handle, :string
      add :locale, :string, default: "nb_NO"
      add :time_zone, :string, default: "Europe/Oslo"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:accounts, [:email], where: "email IS NOT NULL")
    create unique_index(:accounts, [:handle], where: "handle IS NOT NULL")
    create unique_index(:accounts, [:phone_number], where: "phone_number IS NOT NULL")

    create table(:profiles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string
      add :mode, :string, null: false
      add :theme, :map, default: %{}
      add :notification_policy, :map, default: %{}
      add :security_policy, :map, default: %{}
      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    execute("CREATE TYPE conversation_mode AS ENUM ('private','work','family')",
            "DROP TYPE IF EXISTS conversation_mode")
    execute("ALTER TABLE profiles ALTER COLUMN mode TYPE conversation_mode USING mode::conversation_mode")

    create index(:profiles, [:account_id])
    create unique_index(:profiles, [:account_id, :slug])
  end
end
