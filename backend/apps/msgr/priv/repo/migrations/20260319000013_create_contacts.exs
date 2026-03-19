defmodule Messngr.Repo.Migrations.CreateContactsV2 do
  use Ecto.Migration

  def change do
    # Add new columns to existing contacts table for URI-based contact model
    alter table(:contacts) do
      add_if_not_exists :display_name, :string
      add_if_not_exists :notes, :text
      add_if_not_exists :owner_account_id, references(:accounts, type: :binary_id, on_delete: :delete_all)
    end

    create table(:contact_identities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :contact_id, references(:contacts, type: :binary_id, on_delete: :delete_all), null: false
      add :uri, :string
      add :canonical_uri, :string
      add :bridge_type, :string
      add :bridge_meta, :map, default: %{}
      add :is_primary, :boolean, default: false
      add :verified_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:contact_identities, [:uri], where: "uri IS NOT NULL")
    create index(:contact_identities, [:contact_id])
  end
end
