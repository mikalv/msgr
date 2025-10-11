defmodule Messngr.Repo.Migrations.EnhanceMediaUploads do
  use Ecto.Migration

  def up do
    execute("ALTER TYPE message_kind ADD VALUE IF NOT EXISTS 'voice'")
    execute("ALTER TYPE message_kind ADD VALUE IF NOT EXISTS 'file'")

    execute("ALTER TYPE message_kind ADD VALUE IF NOT EXISTS 'thumbnail'")

    alter table(:media_uploads) do
      add :width, :integer
      add :height, :integer
      add :checksum, :string
    end

    alter table(:messages) do
      modify :kind, :string, null: false
    end

    execute("ALTER TABLE messages ALTER COLUMN kind TYPE message_kind USING kind::message_kind")

    execute("ALTER TABLE media_uploads ALTER COLUMN kind TYPE message_kind USING kind::message_kind")
  end

  def down do
    alter table(:media_uploads) do
      remove :width
      remove :height
      remove :checksum
    end

    execute("ALTER TABLE messages ALTER COLUMN kind TYPE text")
    execute("ALTER TABLE media_uploads ALTER COLUMN kind TYPE text")
  end
end
