defmodule Teams.Repo.TenantMigrations.AddAppIdToProfiles do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :app_id, :binary_id
    end
  end
end
