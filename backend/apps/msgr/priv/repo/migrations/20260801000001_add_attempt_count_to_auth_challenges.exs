defmodule Messngr.Repo.Migrations.AddAttemptCountToAuthChallenges do
  use Ecto.Migration

  def change do
    alter table(:auth_challenges) do
      add :attempt_count, :integer, null: false, default: 0
    end
  end
end
