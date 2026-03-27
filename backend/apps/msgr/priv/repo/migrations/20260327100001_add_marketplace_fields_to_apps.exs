defmodule Messngr.Repo.Migrations.AddMarketplaceFieldsToApps do
  use Ecto.Migration

  def change do
    alter table(:apps) do
      add :category, :string, default: "custom"
      add :featured, :boolean, default: false
      add :install_count, :integer, default: 0
      add :config_schema, :map, default: %{}
      add :channel_config_schema, :map, default: %{}
      add :required_scopes, {:array, :string}, default: []
    end

    create index(:apps, [:category])
    create index(:apps, [:featured])
  end
end
