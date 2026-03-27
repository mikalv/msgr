defmodule Teams.Repo.Migrations.AddMetadataToChannels do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      add :metadata, :map, default: %{}
    end
  end
end
