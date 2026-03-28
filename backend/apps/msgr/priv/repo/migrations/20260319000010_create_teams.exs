defmodule Messngr.Repo.Migrations.CreateTeams do
  use Ecto.Migration

  def change do
    create table(:teams, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :schema_name, :string, null: false
      add :domain, :string
      add :owner_account_id, references(:accounts, type: :binary_id, on_delete: :nilify_all)
      add :settings, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:teams, [:slug])
    create unique_index(:teams, [:schema_name])
    create unique_index(:teams, [:domain], where: "domain IS NOT NULL")

    create table(:team_memberships, primary_key: false) do
      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all),
        primary_key: true,
        null: false

      add :team_id, references(:teams, type: :binary_id, on_delete: :delete_all),
        primary_key: true,
        null: false

      add :role, :string, default: "member", null: false
      add :joined_at, :utc_datetime, null: false, default: fragment("now()")
    end

    create index(:team_memberships, [:team_id])
  end
end
