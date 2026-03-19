defmodule Teams.Repo.TenantMigrations.RenameRoomsToChannels do
  use Ecto.Migration

  def change do
    rename table(:rooms), to: table(:channels)
    rename table(:messages), :room_id, to: :channel_id
  end
end
