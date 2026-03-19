defmodule Teams.Repo.TenantMigrations.CreateProfiles do
  use Ecto.Migration

  def change do
    create table(:profiles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :account_id, :binary_id, null: false
      add :display_name, :string
      add :avatar_url, :string
      add :email, :string
      add :phone, :string
      add :role, :string, default: "member"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:profiles, [:account_id])
  end
end
