defmodule Messngr.Repo.Migrations.AddMessageEnhancements do
  use Ecto.Migration

  def change do
    create table(:message_threads, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :conversation_id,
          references(:conversations, type: :binary_id, on_delete: :delete_all),
          null: false

      add :root_message_id,
          references(:messages, type: :binary_id, on_delete: :delete_all),
          null: false

      add :created_by_id,
          references(:profiles, type: :binary_id, on_delete: :nilify_all),
          null: false

      add :metadata, :map, default: %{}, null: false
      add :last_activity_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:message_threads, [:root_message_id])

    alter table(:messages) do
      add :edited_at, :utc_datetime
      add :deleted_at, :utc_datetime
      add :metadata, :map, default: %{}, null: false
      add :thread_id, references(:message_threads, type: :binary_id, on_delete: :nilify_all)
    end

    create table(:message_reactions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :message_id,
          references(:messages, type: :binary_id, on_delete: :delete_all),
          null: false

      add :profile_id,
          references(:profiles, type: :binary_id, on_delete: :delete_all),
          null: false

      add :emoji, :string, null: false
      add :metadata, :map, default: %{}, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:message_reactions, [:message_id, :profile_id, :emoji],
             name: :message_reactions_unique_reaction
           )

    create table(:pinned_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :conversation_id,
          references(:conversations, type: :binary_id, on_delete: :delete_all),
          null: false

      add :message_id,
          references(:messages, type: :binary_id, on_delete: :delete_all),
          null: false

      add :pinned_by_id,
          references(:profiles, type: :binary_id, on_delete: :delete_all),
          null: false

      add :pinned_at, :utc_datetime, null: false
      add :metadata, :map, default: %{}, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:pinned_messages, [:conversation_id, :message_id])
  end
end
