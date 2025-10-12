defmodule AuthProvider.Idp.IdentityProvider do
  @moduledoc """
  Schema representing either the built-in IDP or an upstream integration
  where Messngr acts as the service provider.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type strategy :: :native | :external_oidc
  @type t :: %__MODULE__{
          id: binary() | nil,
          tenant:
            AuthProvider.Idp.Tenant.t()
            | Ecto.Association.NotLoaded.t()
            | nil,
          tenant_id: binary() | nil,
          name: String.t() | nil,
          slug: String.t() | nil,
          strategy: strategy() | nil,
          issuer: String.t() | nil,
          client_id: String.t() | nil,
          client_secret: String.t() | nil,
          authorization_endpoint: String.t() | nil,
          token_endpoint: String.t() | nil,
          userinfo_endpoint: String.t() | nil,
          jwks_uri: String.t() | nil,
          metadata: map(),
          is_default: boolean(),
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "idp_identity_providers" do
    belongs_to :tenant, AuthProvider.Idp.Tenant

    field :name, :string
    field :slug, :string
    field :strategy, Ecto.Enum, values: [:native, :external_oidc]
    field :issuer, :string
    field :client_id, :string
    field :client_secret, :string
    field :authorization_endpoint, :string
    field :token_endpoint, :string
    field :userinfo_endpoint, :string
    field :jwks_uri, :string
    field :metadata, :map, default: %{}
    field :is_default, :boolean, default: false

    timestamps()
  end

  @doc false
  def changeset(%IdentityProvider{} = provider, attrs) when is_map(attrs) do
    provider
    |> cast(attrs, [
      :tenant_id,
      :name,
      :slug,
      :strategy,
      :issuer,
      :client_id,
      :client_secret,
      :authorization_endpoint,
      :token_endpoint,
      :userinfo_endpoint,
      :jwks_uri,
      :metadata,
      :is_default
    ])
    |> validate_required([:tenant_id, :name])
    |> put_default_strategy(attrs)
    |> maybe_generate_slug()
    |> validate_strategy_requirements()
    |> put_default_metadata()
    |> unique_constraint(:slug, name: :idp_identity_providers_tenant_id_slug_index)
  end

  defp put_default_strategy(changeset, attrs) do
    case {get_field(changeset, :strategy), Map.get(attrs, "strategy")} do
      {nil, nil} -> put_change(changeset, :strategy, :native)
      {nil, val} when val in ["native", :native] -> put_change(changeset, :strategy, :native)
      {nil, val} when val in ["external_oidc", :external_oidc] ->
        put_change(changeset, :strategy, :external_oidc)
      _ -> changeset
    end
  end

  defp maybe_generate_slug(changeset) do
    cond do
      slug = get_field(changeset, :slug) -> put_change(changeset, :slug, AuthProvider.Idp.Tenant.slugify(slug))
      name = get_field(changeset, :name) -> put_change(changeset, :slug, AuthProvider.Idp.Tenant.slugify(name))
      true -> changeset
    end
  end

  defp validate_strategy_requirements(changeset) do
    case get_field(changeset, :strategy) do
      :external_oidc ->
        changeset
        |> validate_required([
          :issuer,
          :client_id,
          :client_secret,
          :authorization_endpoint,
          :token_endpoint
        ])
      _ -> changeset
    end
  end

  defp put_default_metadata(changeset) do
    update_change(changeset, :metadata, fn
      nil -> %{}
      %{} = metadata -> metadata
      value when is_map(value) -> value
      _ -> %{}
    end)
  end

  @doc """
  Returns true if the provider uses an upstream OpenID Connect authority.
  """
  @spec external_oidc?(IdentityProvider.t()) :: boolean()
  def external_oidc?(%IdentityProvider{strategy: :external_oidc}), do: true
  def external_oidc?(_), do: false
end
