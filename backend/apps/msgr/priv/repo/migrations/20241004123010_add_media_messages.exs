defmodule Messngr.Repo.Migrations.AddMediaMessages do
  use Ecto.Migration

  def up do
    execute(
      "CREATE TYPE message_kind AS ENUM ('text','markdown','code','system','image','video','audio','location')"
    )

    alter table(:messages) do
      add :kind, :string, null: false, default: "text"
      add :payload, :map, null: false, default: %{}
      modify :body, :text, null: true
    end

    execute("ALTER TABLE messages ALTER COLUMN kind DROP DEFAULT")

    execute(
      "ALTER TABLE messages ALTER COLUMN kind TYPE message_kind USING kind::message_kind"
    )

    execute("ALTER TABLE messages ALTER COLUMN kind SET DEFAULT 'text'::message_kind")

    create table(:media_uploads, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :kind, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :bucket, :string, null: false
      add :object_key, :string, null: false
      add :content_type, :string, null: false
      add :byte_size, :bigint, null: false
      add :metadata, :map, null: false, default: %{}
      add :expires_at, :utc_datetime, null: false
      add :conversation_id,
          references(:conversations, type: :binary_id, on_delete: :delete_all),
          null: false
      add :profile_id,
          references(:profiles, type: :binary_id, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime)
    end

    execute("ALTER TABLE media_uploads ALTER COLUMN kind TYPE message_kind USING kind::message_kind")

    execute(
      "CREATE TYPE media_upload_status AS ENUM ('pending','consumed')"
    )

    execute("ALTER TABLE media_uploads ALTER COLUMN status DROP DEFAULT")

    execute(
      "ALTER TABLE media_uploads ALTER COLUMN status TYPE media_upload_status USING status::media_upload_status"
    )

    execute(
      "ALTER TABLE media_uploads ALTER COLUMN status SET DEFAULT 'pending'::media_upload_status"
    )

    create index(:media_uploads, [:conversation_id])
    create index(:media_uploads, [:profile_id])
    create unique_index(:media_uploads, [:object_key])
  end

  def down do
    drop_if_exists unique_index(:media_uploads, [:object_key])
    drop_if_exists index(:media_uploads, [:profile_id])
    drop_if_exists index(:media_uploads, [:conversation_id])

    drop table(:media_uploads)

    execute("DROP TYPE IF EXISTS media_upload_status")

    execute("ALTER TABLE messages ALTER COLUMN kind DROP DEFAULT")

    execute("ALTER TABLE messages ALTER COLUMN kind TYPE text")

    alter table(:messages) do
      modify :body, :text, null: false
      remove :payload
      remove :kind
    end

    execute("DROP TYPE IF EXISTS message_kind")
  end
end
