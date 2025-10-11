defmodule Teams.Repo.Migrations.CreateConversationsTable do
  use Ecto.Migration

  def change do
    create table(:conversations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :topic, :string, null: true
      add :members, {:array, :string}
      add :is_secret, :boolean, default: false
      add :metadata, :map, default: "{}"
      timestamps(type: :utc_datetime)
    end
  end
end
