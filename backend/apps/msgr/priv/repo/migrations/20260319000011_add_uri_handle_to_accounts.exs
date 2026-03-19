defmodule Messngr.Repo.Migrations.AddUriHandleToAccounts do
  use Ecto.Migration

  def change do
    alter table(:accounts) do
      add :uri, :string
      add :handle_changed_at, :utc_datetime
    end

    create unique_index(:accounts, [:uri], where: "uri IS NOT NULL")
  end
end
