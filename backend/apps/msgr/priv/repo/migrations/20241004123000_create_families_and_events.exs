defmodule Messngr.Repo.Migrations.CreateFamiliesAndEvents do
  use Ecto.Migration

  def change do
    create table(:families, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :time_zone, :string, null: false, default: "Etc/UTC"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:families, [:slug])

    create table(:family_memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :family_id, references(:families, type: :binary_id, on_delete: :delete_all), null: false
      add :profile_id, references(:profiles, type: :binary_id, on_delete: :delete_all), null: false
      add :role, :string, null: false, default: "member"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:family_memberships, [:family_id, :profile_id])

    create table(:family_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :family_id, references(:families, type: :binary_id, on_delete: :delete_all), null: false
      add :created_by_profile_id, references(:profiles, type: :binary_id, on_delete: :nilify_all), null: false
      add :updated_by_profile_id, references(:profiles, type: :binary_id, on_delete: :nilify_all)
      add :title, :string, null: false
      add :description, :text
      add :location, :string
      add :starts_at, :utc_datetime, null: false
      add :ends_at, :utc_datetime, null: false
      add :all_day, :boolean, null: false, default: false
      add :color, :string

      timestamps(type: :utc_datetime)
    end

    create index(:family_events, [:family_id])
    create index(:family_events, [:starts_at])
  end
end
