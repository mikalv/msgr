defmodule Messngr.Repo.Migrations.ExtendMediaUploads do
  use Ecto.Migration

  def up do
    execute("ALTER TYPE message_kind ADD VALUE IF NOT EXISTS 'file'")
    execute("ALTER TYPE message_kind ADD VALUE IF NOT EXISTS 'voice'")
    execute("ALTER TYPE message_kind ADD VALUE IF NOT EXISTS 'thumbnail'")

    alter table(:media_uploads) do
      add_if_not_exists :width, :integer
      add_if_not_exists :height, :integer
      add_if_not_exists :sha256, :string
      add_if_not_exists :retention_expires_at, :utc_datetime
    end
  end

  def down do
    alter table(:media_uploads) do
      remove_if_exists :retention_expires_at
      remove_if_exists :sha256
      remove_if_exists :height
      remove_if_exists :width
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
