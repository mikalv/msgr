defmodule Messngr.Repo.Migrations.ExtendMediaUploads do
  use Ecto.Migration

  def up do
    execute("ALTER TYPE message_kind ADD VALUE IF NOT EXISTS 'file'")
    execute("ALTER TYPE message_kind ADD VALUE IF NOT EXISTS 'voice'")
    execute("ALTER TYPE message_kind ADD VALUE IF NOT EXISTS 'thumbnail'")

    alter table(:media_uploads) do
      add :width, :integer
      add :height, :integer
      add :sha256, :string
      add :retention_expires_at, :utc_datetime
    end
  end

  def down do
    alter table(:media_uploads) do
      remove :retention_expires_at
      remove :sha256
      remove :height
      remove :width
    end

    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='media_uploads' AND column_name='kind') THEN
        UPDATE media_uploads SET kind='audio' WHERE kind IN ('voice');
        UPDATE media_uploads SET kind='image' WHERE kind IN ('file','thumbnail');
      END IF;
    END
    $$;
    """)

    execute("ALTER TABLE media_uploads ALTER COLUMN kind TYPE text")
    execute("ALTER TABLE messages ALTER COLUMN kind TYPE text")

    execute("DROP TYPE IF EXISTS message_kind")

    execute("CREATE TYPE message_kind AS ENUM ('text','markdown','code','system','image','video','audio','location')")

    execute("ALTER TABLE messages ALTER COLUMN kind TYPE message_kind USING kind::message_kind")
    execute("ALTER TABLE media_uploads ALTER COLUMN kind TYPE message_kind USING kind::message_kind")
  end
end
