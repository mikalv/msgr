defmodule Teams.Repo.Migrations.CreateTenantTeams do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto"

    create table(:tenant_teams, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, primary_key: true
      add :description, :string, default: ""
      add :creator_uid, :string
      add :members, {:array, :string}
      add :metadata, :map, default: "{}"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tenant_teams, [:name])

    execute """
    create or replace function array_unique (a text[]) returns text[] as $$
      select array (
        select distinct v from unnest(a) as b(v)
      )
    $$ language sql;
    """
  end
end
