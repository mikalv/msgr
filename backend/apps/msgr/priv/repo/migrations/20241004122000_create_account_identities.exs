defmodule Messngr.Repo.Migrations.CreateAccountIdentities do
  use Ecto.Migration

  def change do
    create table(:account_identities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :value, :string
      add :provider, :string
      add :subject, :string
      add :verified_at, :utc_datetime
      add :last_challenged_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:account_identities, [:account_id])
    create unique_index(:account_identities, [:account_id, :kind, :value],
             name: :account_identities_account_id_kind_value_index,
             where: "value IS NOT NULL"
           )

    create unique_index(:account_identities, [:provider, :subject],
             name: :account_identities_provider_subject_index,
             where: "provider IS NOT NULL AND subject IS NOT NULL"
           )

    create unique_index(:account_identities, [:kind, :value],
             name: :account_identities_kind_value_index,
             where: "value IS NOT NULL"
           )
  end
end

