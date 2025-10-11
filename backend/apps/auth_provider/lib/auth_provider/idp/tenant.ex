defmodule AuthProvider.Idp.Tenant do
  @moduledoc """
  Ecto schema representing an identity tenant.

  A tenant encapsulates branding, default authentication strategy and
  session settings that are used when issuing IDP tokens or cookies. The
  schema is deliberately small and extensible through the `metadata` map so
  we can keep iterating on tenant specific features without running new
  migrations for every tweak.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @typedoc """
  Supported default identity provider strategies for a tenant.

  `:native` means we rely on our own IDP stack. `:external_oidc` configures the
  tenant to authenticate against an upstream OpenID Connect provider where
  Messngr acts as a service provider.
  """
  @type strategy :: :native | :external_oidc

  schema "idp_tenants" do
    field :name, :string
    field :slug, :string
    field :default_locale, :string
    field :default_identity_provider, Ecto.Enum, values: [:native, :external_oidc]
    field :session_domain, :string
    field :session_max_age_seconds, :integer, default: 86_400
    field :metadata, :map, default: %{}

    has_many :identity_providers, AuthProvider.Idp.IdentityProvider

    timestamps()
  end

  @doc false
  def changeset(%Tenant{} = tenant, attrs) when is_map(attrs) do
    tenant
    |> cast(attrs, [
      :name,
      :slug,
      :default_locale,
      :default_identity_provider,
      :session_domain,
      :session_max_age_seconds,
      :metadata
    ])
    |> validate_required([:name])
    |> cast_default_identity_provider(attrs)
    |> maybe_generate_slug()
    |> validate_length(:slug, min: 2)
    |> unique_constraint(:slug)
    |> validate_number(:session_max_age_seconds, greater_than: 0)
    |> put_default_metadata()
  end

  defp cast_default_identity_provider(changeset, attrs) do
    case {get_field(changeset, :default_identity_provider), Map.get(attrs, "default_identity_provider")} do
      {nil, val} when val in ["native", :native] -> put_change(changeset, :default_identity_provider, :native)
      {nil, val} when val in ["external_oidc", :external_oidc] ->
        put_change(changeset, :default_identity_provider, :external_oidc)
      {nil, nil} ->
        put_change(changeset, :default_identity_provider, :native)
      _ ->
        changeset
    end
  end

  defp maybe_generate_slug(changeset) do
    cond do
      slug = get_field(changeset, :slug) -> put_change(changeset, :slug, slugify(slug))
      name = get_field(changeset, :name) -> put_change(changeset, :slug, slugify(name))
      true -> changeset
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
  Normalises an arbitrary string into a tenant slug.
  """
  @spec slugify(String.t()) :: String.t()
  def slugify(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.replace(~r/-+/u, "-")
    |> String.trim("-")
  end

  def slugify(value), do: to_string(value) |> slugify()

  @doc """
  Builds the recommended cookie/session configuration for the tenant.
  """
  @spec session_options(Tenant.t(), keyword()) :: keyword()
  def session_options(%Tenant{} = tenant, overrides \\ []) do
    [
      store: :cookie,
      key: tenant_cookie_key(tenant),
      signing_salt: "iQMaQJWY",
      same_site: "Lax",
      domain: tenant.session_domain,
      max_age: tenant.session_max_age_seconds
    ]
    |> Keyword.merge(overrides)
  end

  @doc """
  Default cookie key used for the Phoenix session.
  """
  @spec tenant_cookie_key(Tenant.t()) :: String.t()
  def tenant_cookie_key(%Tenant{slug: slug}) do
    "_msgr_auth_" <> (slug || "tenant")
  end
end

