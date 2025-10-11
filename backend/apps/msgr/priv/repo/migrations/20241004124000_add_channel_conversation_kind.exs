defmodule Messngr.Repo.Migrations.AddChannelConversationKind do
  use Ecto.Migration

  def up do
    execute("ALTER TYPE conversation_kind ADD VALUE IF NOT EXISTS 'channel'")
  end

  def down do
    :ok
  end
end
