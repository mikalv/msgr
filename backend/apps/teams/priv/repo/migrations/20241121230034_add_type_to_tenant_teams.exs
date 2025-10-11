defmodule Teams.Repo.Migrations.AddTypeToTenantTeams do
  use Ecto.Migration

  def change do
    execute("CREATE TYPE team_type AS ENUM ('business', 'family', 'local_group', 'interest_group', 'school', 'other');")

    alter table(:tenant_teams) do
      add :type, :team_type, null: false
    end
  end
end
