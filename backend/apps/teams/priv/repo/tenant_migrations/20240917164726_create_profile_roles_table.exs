defmodule Teams.Repo.Migrations.CreateProfileRolesTable do
  use Ecto.Migration

  def change do
    create table(:profile_roles, primary_key: false) do
      add(:role_id, references(:roles, on_delete: :delete_all, type: :binary_id), primary_key: true)
      add(:profile_id, references(:profiles, on_delete: :delete_all, type: :binary_id), primary_key: true)
      timestamps(type: :utc_datetime)
    end

    create unique_index(:profile_roles, [:profile_id, :role_id])
  end
end
