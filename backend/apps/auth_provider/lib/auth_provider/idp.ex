defmodule AuthProvider.Idp do
  @moduledoc """
  Umbrella context for the Messngr identity provider (IDP).

  The IDP owns tenant configuration, OAuth/OpenID Connect setup, JWT issuance
  via Guardian and Phoenix session orchestration. It also prepares Messngr to
  operate as a service provider (SP) when tenants bring their own upstream IDP.
  """

  import Ecto.Query

  alias Ecto.Changeset
  alias Ecto.Multi
  alias Ecto.UUID
  alias OAuth2.Client

  alias AuthProvider.Account.User
  alias AuthProvider.Guardian
  alias AuthProvider.Idp.IdentityProvider
  alias AuthProvider.Idp.Session
  alias AuthProvider.Idp.Tenant
  alias AuthProvider.Repo

  @refresh_defaults [ttl: {4, :weeks}, token_type: "refresh"]

  @doc false
  def repo, do: Repo

  ## Tenant management -------------------------------------------------------

  @spec list_tenants() :: [Tenant.t()]
  def list_tenants, do: Repo.all(Tenant)

  @spec get_tenant!(binary() | String.t()) :: Tenant.t()
  def get_tenant!(id), do: Repo.get!(Tenant, id)

  @spec fetch_tenant(binary() | String.t()) :: {:ok, Tenant.t()} | :error
  def fetch_tenant(id) do
    case Repo.get(Tenant, id) || Repo.get_by(Tenant, slug: Tenant.slugify(id)) do
      %Tenant{} = tenant -> {:ok, tenant}
      _ -> :error
    end
  end

  @spec get_tenant_by_slug!(String.t()) :: Tenant.t()
  def get_tenant_by_slug!(slug), do: Repo.get_by!(Tenant, slug: Tenant.slugify(slug))

  @spec change_tenant(Tenant.t(), map()) :: Changeset.t()
  def change_tenant(%Tenant{} = tenant, attrs \\ %{}), do: Tenant.changeset(tenant, attrs)

  @spec create_tenant(map()) :: {:ok, Tenant.t()} | {:error, Changeset.t()}
  def create_tenant(attrs \\ %{}) do
    Multi.new()
    |> Multi.insert(:tenant, Tenant.changeset(%Tenant{}, attrs))
    |> Multi.merge(fn %{tenant: tenant} -> ensure_default_provider_multi(tenant, attrs) end)
    |> Repo.transaction()
    |> case do
      {:ok, %{tenant: tenant}} -> {:ok, tenant}
      {:error, _step, %Changeset{} = changeset, _} -> {:error, changeset}
    end
  end

  @spec update_tenant(Tenant.t(), map()) :: {:ok, Tenant.t()} | {:error, Changeset.t()}
  def update_tenant(%Tenant{} = tenant, attrs) do
    tenant
    |> Tenant.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_tenant(Tenant.t()) :: {:ok, Tenant.t()} | {:error, Changeset.t()}
  def delete_tenant(%Tenant{} = tenant) do
    Repo.delete(tenant)
  end

  ## Identity providers -----------------------------------------------------

  @spec list_identity_providers(Tenant.t()) :: [IdentityProvider.t()]
  def list_identity_providers(%Tenant{} = tenant) do
    tenant
    |> Ecto.assoc(:identity_providers)
    |> Repo.all()
  end

  @spec change_identity_provider(IdentityProvider.t(), map()) :: Changeset.t()
  def change_identity_provider(%IdentityProvider{} = provider, attrs \\ %{}) do
    IdentityProvider.changeset(provider, attrs)
  end

  @spec create_identity_provider(Tenant.t(), map()) :: {:ok, IdentityProvider.t()} | {:error, Changeset.t()}
  def create_identity_provider(%Tenant{} = tenant, attrs) do
    attrs = attrs |> normalise_provider_attrs() |> Map.put(:tenant_id, tenant.id)

    Multi.new()
    |> maybe_clear_existing_default(tenant, attrs)
    |> Multi.insert(:provider, IdentityProvider.changeset(%IdentityProvider{}, attrs))
    |> Repo.transaction()
    |> case do
      {:ok, %{provider: provider}} -> {:ok, provider}
      {:error, :provider, %Changeset{} = changeset, _} -> {:error, changeset}
    end
  end

  @spec update_identity_provider(IdentityProvider.t(), map()) :: {:ok, IdentityProvider.t()} | {:error, Changeset.t()}
  def update_identity_provider(%IdentityProvider{} = provider, attrs) do
    provider
    |> IdentityProvider.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_identity_provider(IdentityProvider.t()) :: {:ok, IdentityProvider.t()} | {:error, Changeset.t()}
  def delete_identity_provider(%IdentityProvider{is_default: true}), do: {:error, :cannot_delete_default}
  def delete_identity_provider(%IdentityProvider{} = provider), do: Repo.delete(provider)

  @spec fetch_identity_provider(Tenant.t(), binary() | String.t()) :: {:ok, IdentityProvider.t()} | :error
  def fetch_identity_provider(%Tenant{} = tenant, id_or_slug) do
    query = from p in IdentityProvider, where: p.tenant_id == ^tenant.id

    result =
      case UUID.cast(id_or_slug) do
        {:ok, uuid} -> Repo.get(query, uuid)
        :error -> Repo.get_by(query, slug: Tenant.slugify(id_or_slug))
      end

    case result do
      %IdentityProvider{} = provider -> {:ok, provider}
      _ -> :error
    end
  end

  @spec fetch_default_identity_provider(Tenant.t()) :: {:ok, IdentityProvider.t()} | :error
  def fetch_default_identity_provider(%Tenant{} = tenant) do
    tenant
    |> list_identity_providers()
    |> Enum.find(& &1.is_default)
    |> case do
      %IdentityProvider{} = provider -> {:ok, provider}
      _ -> :error
    end
  end

  @spec default_identity_provider!(Tenant.t()) :: IdentityProvider.t()
  def default_identity_provider!(%Tenant{} = tenant) do
    {:ok, provider} = fetch_default_identity_provider(tenant)
    provider
  end

  ## Tokens -----------------------------------------------------------------

  @doc """
  Issues an access token and refresh token for the user scoped to the tenant.
  """
  @spec issue_tokens(Tenant.t(), User.t(), keyword()) ::
          {:ok, %{access_token: String.t(), refresh_token: String.t(), claims: map()}}
          | {:error, term()}
  def issue_tokens(%Tenant{} = tenant, %User{} = user, opts \\ []) do
    base_claims = Map.put(Map.new(Keyword.get(opts, :claims, %{})), "tenant", tenant.slug)

    with {:ok, token, claims} <- Guardian.encode_and_sign(user, base_claims, Keyword.take(opts, [:permissions])),
         {:ok, refresh_token, _} <- Guardian.encode_and_sign(user, base_claims, refresh_options(opts)) do
      {:ok, %{access_token: token, refresh_token: refresh_token, claims: claims}}
    end
  end

  @doc """
  Refreshes an access token in place using Guardian.
  """
  @spec refresh_token(String.t()) :: {:ok, term()} | {:error, term()}
  def refresh_token(token), do: Guardian.refresh(token)

  @doc """
  Verifies a token and returns the stored claims.
  """
  @spec verify_token(String.t()) :: {:ok, map()} | {:error, term()}
  def verify_token(token), do: Guardian.decode_and_verify(token)

  ## Phoenix session helpers ------------------------------------------------

  @doc """
  Stores tenant and provider metadata in the Phoenix session.
  """
  @spec sign_in(Plug.Conn.t(), Tenant.t(), User.t(), IdentityProvider.t(), keyword()) :: Plug.Conn.t()
  def sign_in(conn, tenant, user, provider, opts \\ []) do
    Session.sign_in(conn, tenant, user, provider, opts)
  end

  @doc """
  Drops the Phoenix session.
  """
  @spec sign_out(Plug.Conn.t()) :: Plug.Conn.t()
  def sign_out(conn), do: Session.sign_out(conn)

  @doc """
  Loads tenant/provider/user from the session if available.
  """
  @spec fetch_current_session(Plug.Conn.t()) :: {Plug.Conn.t(), {:ok, map()} | :error}
  def fetch_current_session(conn), do: Session.fetch_current(conn)

  ## Service provider helpers -----------------------------------------------

  @doc """
  Builds an OAuth2 client for an external OIDC identity provider configuration.
  Returns `{:error, :unsupported_strategy}` for native providers.
  """
  @spec build_service_provider_client(IdentityProvider.t()) :: {:ok, Client.t()} | {:error, term()}
  def build_service_provider_client(%IdentityProvider{strategy: :external_oidc} = provider) do
    {:ok,
     Client.new(
       strategy: OAuth2.Strategy.AuthCode,
       client_id: provider.client_id,
       client_secret: provider.client_secret,
       site: provider.issuer,
       authorize_url: provider.authorization_endpoint,
       token_url: provider.token_endpoint
     )}
  end

  def build_service_provider_client(_provider), do: {:error, :unsupported_strategy}

  ## Private ----------------------------------------------------------------

  defp ensure_default_provider_multi(%Tenant{} = tenant, attrs) do
    strategy =
      Map.get(attrs, :default_identity_provider) ||
        Map.get(attrs, "default_identity_provider") || tenant.default_identity_provider

    default_attrs =
      attrs
      |> Map.get(:default_identity_provider_config, %{})
      |> Map.merge(Map.get(attrs, "default_identity_provider_config", %{}))
      |> normalise_provider_attrs()
      |> Map.merge(%{
        name:
          Map.get(attrs, :default_identity_provider_name) ||
            Map.get(attrs, "default_identity_provider_name") ||
            "#{tenant.name} IDP",
        slug:
          Map.get(attrs, :default_identity_provider_slug) ||
            Map.get(attrs, "default_identity_provider_slug") ||
            to_string(strategy),
        strategy: strategy,
        is_default: true
      })
      |> Map.put(:tenant_id, tenant.id)

    Multi.new()
    |> Multi.update_all(:clear_defaults, identity_provider_query(tenant), set: [is_default: false])
    |> Multi.insert(:default_provider, IdentityProvider.changeset(%IdentityProvider{}, default_attrs))
  end

  defp maybe_clear_existing_default(multi, %Tenant{} = tenant, attrs) do
    attrs = normalise_provider_attrs(attrs)

    if truthy?(Map.get(attrs, :is_default) || Map.get(attrs, "is_default")) do
      Multi.update_all(multi, :unset_default, identity_provider_query(tenant), set: [is_default: false])
    else
      multi
    end
  end

  defp normalise_provider_attrs(%{} = attrs), do: attrs
  defp normalise_provider_attrs(value) when is_list(value), do: Enum.into(value, %{})
  defp normalise_provider_attrs(value), do: value

  defp identity_provider_query(%Tenant{} = tenant) do
    from p in IdentityProvider, where: p.tenant_id == ^tenant.id and p.is_default == true
  end

  defp truthy?(value) when value in [true, "true", 1, "1"], do: true
  defp truthy?(_), do: false

  defp refresh_options(opts) do
    opts
    |> Keyword.get(:refresh_options, [])
    |> Keyword.merge(@refresh_defaults)
  end
end

