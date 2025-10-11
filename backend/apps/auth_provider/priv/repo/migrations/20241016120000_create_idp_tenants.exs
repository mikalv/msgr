defmodule AuthProvider.Repo.Migrations.CreateIdpTenants do
  use Ecto.Migration

  def change do
    create table(:idp_tenants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :default_locale, :string
      add :default_identity_provider, :string, null: false, default: "native"
      add :session_domain, :string
      add :session_max_age_seconds, :integer, null: false, default: 86_400
      add :metadata, :map, null: false, default: %{}

      timestamps()
    end

    create unique_index(:idp_tenants, [:slug])

    create table(:idp_identity_providers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:idp_tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :slug, :string, null: false
      add :strategy, :string, null: false, default: "native"
      add :issuer, :string
      add :client_id, :string
      add :client_secret, :string
      add :authorization_endpoint, :string
      add :token_endpoint, :string
      add :userinfo_endpoint, :string
      add :jwks_uri, :string
      add :metadata, :map, null: false, default: %{}
      add :is_default, :boolean, null: false, default: false

      timestamps()
    end

    create unique_index(:idp_identity_providers, [:tenant_id, :slug])
    create unique_index(:idp_identity_providers, [:tenant_id], where: "is_default = true", name: :idp_identity_providers_unique_default)
  end
end

