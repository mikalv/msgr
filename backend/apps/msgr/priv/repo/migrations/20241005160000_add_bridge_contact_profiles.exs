defmodule Messngr.Repo.Migrations.AddBridgeContactProfiles do
  use Ecto.Migration

  def change do
    create table(:bridge_contact_profiles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :canonical_name, :string
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create table(:bridge_contact_profile_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :profile_id, references(:bridge_contact_profiles, type: :binary_id, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :value, :string, null: false
      add :confidence, :integer, default: 1, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:bridge_contact_profile_keys, [:profile_id])
    create unique_index(:bridge_contact_profile_keys, [:kind, :value])

    create table(:bridge_contact_profile_links, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :profile_id, references(:bridge_contact_profiles, type: :binary_id, on_delete: :delete_all), null: false
      add :source, :string, null: false
      add :source_id, :string, null: false
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:bridge_contact_profile_links, [:source, :source_id])
    create index(:bridge_contact_profile_links, [:profile_id])

    alter table(:bridge_contacts) do
      add :profile_id, references(:bridge_contact_profiles, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:bridge_contacts, [:profile_id])
  end
end
