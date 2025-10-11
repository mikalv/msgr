defmodule Teams.Repo.Migrations.CreateRolesTable do
  use Ecto.Migration

  def change do
    create table(:roles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :permissions, {:array, :string}
      add :is_default, :boolean, default: false
      add :metadata, :map, default: "{}"
      timestamps(type: :utc_datetime)
    end

    create unique_index(:roles, [:name])
  end
end
