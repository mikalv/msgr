defmodule Messngr.Repo.Migrations.CreateContacts do
  use Ecto.Migration

  def change do
    create table(:contacts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all), null: false
      add :profile_id, references(:profiles, type: :binary_id, on_delete: :delete_all)
      add :name, :string, null: false
      add :email, :string
      add :phone_number, :string
      add :labels, {:array, :string}, default: []
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:contacts, [:account_id])
    create index(:contacts, [:profile_id])
    execute(
      "CREATE UNIQUE INDEX contacts_account_id_email_index ON contacts (account_id, email) WHERE email IS NOT NULL",
      "DROP INDEX IF EXISTS contacts_account_id_email_index"
    )

    execute(
      "CREATE UNIQUE INDEX contacts_account_id_phone_number_index ON contacts (account_id, phone_number) WHERE phone_number IS NOT NULL",
      "DROP INDEX IF EXISTS contacts_account_id_phone_number_index"
    )
  end
end
