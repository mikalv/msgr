defmodule Messngr.Repo.Migrations.AddInstanceToBridgeAccounts do
  use Ecto.Migration

  def change do
    alter table(:bridge_accounts) do
      add :instance, :string, null: false, default: "primary"
    end

    drop_if_exists unique_index(:bridge_accounts, [:account_id, :service])

    create unique_index(:bridge_accounts, [:account_id, :service, :instance],
             name: :bridge_accounts_account_service_instance_index
           )

    create index(:bridge_accounts, [:account_id, :service])
  end
end
