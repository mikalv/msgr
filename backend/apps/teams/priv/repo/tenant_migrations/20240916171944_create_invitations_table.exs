defmodule Teams.Repo.Migrations.CreateInvitationsTable do
  use Ecto.Migration

  def change do
    create table(:invitations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :is_used, :boolean, default: false
      add :msisdn, :string, null: true
      add :email, :string, null: true
      add :profile_id, :string, null: true

      add :metadata, :map, default: "{}"
      timestamps(type: :utc_datetime)
    end
  end
end
