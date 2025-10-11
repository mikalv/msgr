defmodule TeamsWeb.GraphQL.Context do
  @behaviour Plug

  import Plug.Conn
  import Ecto.Query, only: [where: 2]

  alias Teams.TenantModels.{Profile}

  def init(opts), do: opts

  def call(conn, _) do
    context = build_context(conn)
    Absinthe.Plug.put_options(conn, context: context)
  end

  @doc """
  Return the current user context based on the authorization header
  """
  def build_context(conn) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
    {:ok, profile, uid} <- authorize(conn) do
      %{current_uid: uid, current_profile: profile}
    else
      _ -> %{}
    end
  end

  defp authorize(conn) do
    case get_authed_context(conn) do
      {tenant, nil, _} -> {:error, "invalid authorization token"}
      {tenant, profile, uid} -> {:ok, profile, uid}
    end
  end


  defp get_authed_context(conn) do
    tenant = conn.private[:subdomain]
    claims = Guardian.Plug.current_claims(conn)
    uid = claims["sub"]
    profile = Profile.get_by_uid(tenant, uid)
    {tenant, profile, uid}
  end

end
