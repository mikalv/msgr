defmodule Messngr.Repo.Migrations.CreateAuthChallenges do
  use Ecto.Migration

  def change do
    create table(:auth_challenges, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :identity_id, references(:account_identities, type: :binary_id, on_delete: :delete_all)
      add :channel, :string, null: false
      add :target, :string, null: false
      add :code_hash, :string, null: false
      add :issued_for, :string
      add :expires_at, :utc_datetime, null: false
      add :consumed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:auth_challenges, [:identity_id])
    create index(:auth_challenges, [:channel])
    create index(:auth_challenges, [:issued_for])

    create unique_index(:auth_challenges, [:identity_id, :consumed_at],
             name: :auth_challenges_identity_id_consumed_at_index,
             where: "consumed_at IS NULL AND identity_id IS NOT NULL"
           )
  end
end

