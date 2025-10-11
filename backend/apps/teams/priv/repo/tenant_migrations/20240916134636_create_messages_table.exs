defmodule Teams.Repo.Migrations.CreateMessagesTable do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :msgid, :string, null: true
      add :profile_id, references(:profiles, type: :binary_id), null: true
      add :room_id, references(:rooms, type: :binary_id), null: true
      add :conversation_id, references(:conversations, type: :binary_id), null: true
      add :in_reply_to_id, references(:messages), null: true
      add :is_system_msg, :boolean, default: false
      add :content, :text
      add :metadata, :map, default: "{}"

      timestamps(type: :utc_datetime)
    end

    create constraint(:messages, :either_conversation_id_or_room_id_must_be_set, check: "(room_id IS NOT NULL OR conversation_id IS NOT NULL)")
    create constraint(:messages, :either_profile_id_or_is_system_msg_true, check: "(profile_id IS NOT NULL OR is_system_msg IS true)")
    create index(:messages, [:in_reply_to_id])
    create index(:messages, [:room_id])
    create index(:messages, [:conversation_id])
    create index(:messages, [:profile_id])
  end
end
