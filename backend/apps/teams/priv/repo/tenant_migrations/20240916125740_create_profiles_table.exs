defmodule Teams.Repo.Migrations.CreateProfilesTable do
  use Ecto.Migration

  def change do
    create table(:profiles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :uid, :string, null: false
      add :username, :string
      add :first_name, :string, null: true
      add :last_name, :string, null: true
      add :avatar_url, :string, null: true
      add :is_bot, :boolean, default: false
      add :status, :string, default: ""
      add :settings, :map, default: "{}"
      add :metadata, :map, default: "{}"
      timestamps(type: :utc_datetime)
    end

    create constraint(:profiles, :either_uid_or_is_bot_true, check: "(uid IS NOT NULL OR is_bot IS true)")
    create unique_index(:profiles, [:username])
    create unique_index(:profiles, [:uid])
  end
end
