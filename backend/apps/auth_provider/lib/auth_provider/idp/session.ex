defmodule AuthProvider.Idp.Session do
  @moduledoc """
  Helpers for managing Phoenix sessions tied to IDP tenants.

  The session layer is responsible for keeping track of the current tenant,
  the identity provider used to sign-in and the authenticated user id. By
  centralising the logic here we make it trivial to extend in the future with
  additional metadata such as MFA state or downstream SP assertions.
  """

  import Plug.Conn

  alias AuthProvider.Account.User
  alias AuthProvider.Idp
  alias AuthProvider.Idp.{IdentityProvider, Tenant}

  @tenant_session_key "idp_tenant_id"
  @user_session_key "idp_user_id"
  @provider_session_key "idp_provider_id"

  @doc """
  Stores tenant, provider and user information in the Phoenix session.

  By default the session is renewed which protects against session fixation
  attacks. This can be overridden by passing `renew: false` in `opts`.
  """
  @spec sign_in(Plug.Conn.t(), Tenant.t(), User.t(), IdentityProvider.t(), keyword()) :: Plug.Conn.t()
  def sign_in(conn, %Tenant{} = tenant, %User{} = user, %IdentityProvider{} = provider, opts \\ []) do
    conn
    |> configure_session(renew: Keyword.get(opts, :renew, true))
    |> put_session(@tenant_session_key, tenant.id)
    |> put_session(@provider_session_key, provider.id)
    |> put_session(@user_session_key, user.id)
  end

  @doc """
  Clears the Phoenix session and removes IDP related metadata.
  """
  @spec sign_out(Plug.Conn.t()) :: Plug.Conn.t()
  def sign_out(conn) do
    conn
    |> configure_session(drop: true)
  end

  @doc """
  Hydrates the currently authenticated session, returning the tenant,
  provider and user if present.
  """
  @spec fetch_current(Plug.Conn.t()) :: {Plug.Conn.t(), {:ok, %{tenant: Tenant.t(), provider: IdentityProvider.t(), user: User.t()}} | :error}
  def fetch_current(conn) do
    with tenant_id when not is_nil(tenant_id) <- get_session(conn, @tenant_session_key),
         user_id when not is_nil(user_id) <- get_session(conn, @user_session_key),
         {:ok, tenant} <- Idp.fetch_tenant(tenant_id),
         {:ok, user} <- fetch_user(user_id),
         {:ok, provider} <- fetch_provider(conn, tenant) do
      {conn, {:ok, %{tenant: tenant, user: user, provider: provider}}}
    else
      _ -> {conn, :error}
    end
  end

  defp fetch_user(user_id) do
    case Idp.repo().get(User, user_id) do
      %User{} = user -> {:ok, user}
      _ -> :error
    end
  end

  defp fetch_provider(conn, tenant) do
    provider_id = get_session(conn, @provider_session_key)

    case provider_id && Idp.fetch_identity_provider(tenant, provider_id) do
      {:ok, provider} -> {:ok, provider}
      _ -> Idp.fetch_default_identity_provider(tenant)
    end
  end
end

