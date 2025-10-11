defmodule Messngr.Repo.Migrations.CreateConversationsAndMessages do
  use Ecto.Migration

  def change do
    execute("CREATE TYPE conversation_kind AS ENUM ('direct','group')",
            "DROP TYPE IF EXISTS conversation_kind")
    execute("CREATE TYPE participant_role AS ENUM ('member','owner')",
            "DROP TYPE IF EXISTS participant_role")
    execute("CREATE TYPE message_status AS ENUM ('sending','sent','delivered','read')",
            "DROP TYPE IF EXISTS message_status")

    create table(:conversations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :topic, :string
      add :kind, :string, null: false, default: "direct"

      timestamps(type: :utc_datetime)
    end

    execute("ALTER TABLE conversations ALTER COLUMN kind TYPE conversation_kind USING kind::conversation_kind",
            "ALTER TABLE conversations ALTER COLUMN kind TYPE text")

    create table(:conversation_participants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :role, :string, null: false, default: 'member'
      add :last_read_at, :utc_datetime
      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all), null: false
      add :profile_id, references(:profiles, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    execute("ALTER TABLE conversation_participants ALTER COLUMN role TYPE participant_role USING role::participant_role",
            "ALTER TABLE conversation_participants ALTER COLUMN role TYPE text")

    create unique_index(:conversation_participants, [:conversation_id, :profile_id])

    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :body, :text, null: false
      add :status, :string, null: false, default: 'sent'
      add :sent_at, :utc_datetime
      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all), null: false
      add :profile_id, references(:profiles, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    execute("ALTER TABLE messages ALTER COLUMN status TYPE message_status USING status::message_status",
            "ALTER TABLE messages ALTER COLUMN status TYPE text")

    create index(:messages, [:conversation_id, :inserted_at])
  end
end
