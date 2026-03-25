defmodule Teams.Repo.Migrations.AllowNullAccountIdOnProfiles do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      modify :account_id, :binary_id, null: true
    end
  end
end
