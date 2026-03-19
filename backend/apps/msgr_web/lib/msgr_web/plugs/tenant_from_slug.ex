defmodule MessngrWeb.Plugs.TenantFromSlug do
  @moduledoc """
  Plug that resolves a team tenant from the `:slug` path parameter.

  On success, assigns `:current_team` and `:tenant_prefix` to the conn.
  On failure (team not found), responds with 404.
  """

  import Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    slug = conn.path_params["slug"] || conn.params["slug"]

    case Messngr.Repo.get_by(Messngr.Teams.Team, slug: slug) do
      nil ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(:not_found, Jason.encode!(%{error: "Team not found"}))
        |> halt()

      team ->
        conn
        |> assign(:current_team, team)
        |> assign(:tenant_prefix, team.schema_name)
    end
  end
end
