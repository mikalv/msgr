defmodule Messngr.Repo.Migrations.CreateInviteLinks do
  use Ecto.Migration

  def change do
    create table(:invite_links, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :team_id, references(:teams, type: :binary_id, on_delete: :delete_all), null: false
      add :code, :string, size: 12, null: false
      add :created_by_account_id, references(:accounts, type: :binary_id), null: false
      add :expires_at, :utc_datetime, null: false
      add :used_count, :integer, null: false, default: 0
      add :revoked, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:invite_links, [:code])
    create index(:invite_links, [:team_id])
  end
end
