defmodule MessngrWeb.Plugs.RequireTeamMembership do
  @moduledoc """
  Ensures the authenticated account is a member of the current team tenant.

  Must run after `MessngrWeb.Plugs.TenantFromSlug` and the actor/session plug.
  On success, assigns:
    * `:current_team_profile` — tenant profile for the account
    * `:current_team_membership` — public-schema `TeamMembership` (with role)
  On failure, responds with 403 and halts.
  """

  import Plug.Conn

  alias Teams.TeamManagement

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    team = conn.assigns[:current_team]
    account = conn.assigns[:current_account]
    prefix = conn.assigns[:tenant_prefix]

    with true <- not is_nil(team) and not is_nil(account) and not is_nil(prefix),
         profile when not is_nil(profile) <-
           TeamManagement.get_profile_for_account(prefix, account.id),
         membership when not is_nil(membership) <-
           TeamManagement.get_membership(team.id, account.id) do
      conn
      |> assign(:current_team_profile, profile)
      |> assign(:current_team_membership, membership)
    else
      _ ->
        respond_forbidden(conn)
    end
  end

  defp respond_forbidden(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(:forbidden, Jason.encode!(%{error: "forbidden"}))
    |> halt()
  end
end
