defmodule Messngr.Repo.Migrations.CreateSpacesAndCollaboration do
  use Ecto.Migration

  def change do
    create table(:spaces, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :time_zone, :string, null: false, default: "Etc/UTC"
      add :kind, :string, null: false, default: "family"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:spaces, [:slug])

    create table(:space_memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :space_id, references(:spaces, type: :binary_id, on_delete: :delete_all), null: false
      add :profile_id, references(:profiles, type: :binary_id, on_delete: :delete_all), null: false
      add :role, :string, null: false, default: "member"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:space_memberships, [:space_id, :profile_id])

    create table(:space_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :space_id, references(:spaces, type: :binary_id, on_delete: :delete_all), null: false
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

    create index(:space_events, [:space_id])
    create index(:space_events, [:starts_at])

    create table(:shopping_lists, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :space_id, references(:spaces, type: :binary_id, on_delete: :delete_all), null: false
      add :created_by_profile_id, references(:profiles, type: :binary_id, on_delete: :nilify_all), null: false
      add :name, :string, null: false
      add :status, :string, null: false, default: "active"

      timestamps(type: :utc_datetime)
    end

    create index(:shopping_lists, [:space_id])

    create table(:shopping_list_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :list_id, references(:shopping_lists, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :quantity, :string
      add :checked, :boolean, null: false, default: false
      add :added_by_profile_id, references(:profiles, type: :binary_id, on_delete: :nilify_all), null: false
      add :checked_by_profile_id, references(:profiles, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:shopping_list_items, [:list_id])

    create table(:todo_lists, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :space_id, references(:spaces, type: :binary_id, on_delete: :delete_all), null: false
      add :created_by_profile_id, references(:profiles, type: :binary_id, on_delete: :nilify_all), null: false
      add :name, :string, null: false
      add :status, :string, null: false, default: "active"

      timestamps(type: :utc_datetime)
    end

    create index(:todo_lists, [:space_id])

    create table(:todo_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :list_id, references(:todo_lists, type: :binary_id, on_delete: :delete_all), null: false
      add :content, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :due_at, :utc_datetime
      add :created_by_profile_id, references(:profiles, type: :binary_id, on_delete: :nilify_all), null: false
      add :assignee_profile_id, references(:profiles, type: :binary_id, on_delete: :nilify_all)
      add :completed_by_profile_id, references(:profiles, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:todo_items, [:list_id])
  end
end
