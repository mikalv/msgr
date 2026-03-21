defmodule Messngr.Repo.Migrations.CreateAppsPlatform do
  use Ecto.Migration

  def change do
    # ── Apps registry ──────────────────────────────────────────
    create table(:apps, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :slug, :text, null: false
      add :name, :text, null: false
      add :description, :text
      add :icon_url, :text
      add :developer_id, references(:accounts, type: :binary_id, on_delete: :nilify_all)
      add :manifest, :map, null: false, default: %{}
      add :visibility, :text, default: "private"
      add :executor_type, :text, null: false
      add :webhook_url, :text
      add :webhook_secret, :text
      add :bot_account_id, references(:accounts, type: :binary_id, on_delete: :nilify_all)
      add :status, :text, default: "active"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:apps, [:slug])

    # ── App installations per team ─────────────────────────────
    create table(:app_installations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :app_id, references(:apps, type: :binary_id, on_delete: :delete_all), null: false
      add :team_id, references(:teams, type: :binary_id, on_delete: :delete_all), null: false
      add :installed_by, references(:accounts, type: :binary_id, on_delete: :nilify_all)
      add :config, :map, default: %{}
      add :secrets_encrypted, :binary
      add :enabled_scopes, {:array, :text}, default: []
      add :enabled_channels, {:array, :binary_id}, default: []
      add :status, :text, default: "active"

      add :installed_at, :utc_datetime, default: fragment("now()")
      add :updated_at, :utc_datetime, default: fragment("now()")
    end

    create unique_index(:app_installations, [:app_id, :team_id])

    # ── Slash commands ─────────────────────────────────────────
    create table(:slash_commands, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :app_id, references(:apps, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :text, null: false
      add :description, :text
      add :args_schema, :map
      add :permissions, :text, default: "member"
    end

    create unique_index(:slash_commands, [:app_id, :name])

    # ── Bot tokens ─────────────────────────────────────────────
    create table(:bot_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :app_installation_id,
          references(:app_installations, type: :binary_id, on_delete: :delete_all),
          null: false

      add :token_hash, :text, null: false
      add :label, :text
      add :scopes, {:array, :text}, default: []
      add :last_used_at, :utc_datetime
      add :expires_at, :utc_datetime
      add :revoked_at, :utc_datetime

      add :inserted_at, :utc_datetime, default: fragment("now()")
    end

    create index(:bot_tokens, [:token_hash])
    create index(:bot_tokens, [:app_installation_id])
  end
end
