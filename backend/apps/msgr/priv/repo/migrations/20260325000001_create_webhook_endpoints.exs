defmodule Messngr.Repo.Migrations.CreateWebhookEndpoints do
  use Ecto.Migration

  def change do
    create table(:webhook_endpoints, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :team_id, references(:teams, type: :binary_id, on_delete: :delete_all), null: false
      add :channel_id, :binary_id, null: false
      add :token, :string, size: 40, null: false
      add :name, :string, null: false
      add :avatar_url, :string
      add :created_by_account_id, references(:accounts, type: :binary_id), null: false
      add :enabled, :boolean, null: false, default: true
      add :message_count, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:webhook_endpoints, [:token])
    create index(:webhook_endpoints, [:team_id])
  end
end
