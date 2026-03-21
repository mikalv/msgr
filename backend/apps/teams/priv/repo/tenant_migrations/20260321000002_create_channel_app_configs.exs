defmodule Teams.Repo.TenantMigrations.CreateChannelAppConfigs do
  use Ecto.Migration

  def change do
    create table(:channel_app_configs, primary_key: false) do
      add :channel_id, references(:channels, type: :binary_id, on_delete: :delete_all),
        primary_key: true

      add :app_id, :binary_id, primary_key: true
      add :config, :map, default: %{}
    end
  end
end
