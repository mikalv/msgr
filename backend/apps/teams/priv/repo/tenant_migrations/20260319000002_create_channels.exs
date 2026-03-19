defmodule Teams.Repo.TenantMigrations.CreateChannels do
  use Ecto.Migration

  def change do
    create table(:channels, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :icon, :string
      add :kind, :string, default: "channel", null: false
      add :visibility, :string, default: "public", null: false
      add :topic, :string
      add :created_by, references(:profiles, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:channels, [:slug])
  end
end
