defmodule MessngrWeb.TeamAuth do
  @moduledoc """
  Shared authorization helpers for team-scoped controllers.
  """

  @admin_roles ["owner", "admin"]

  @doc """
  Returns `:ok` when the current team membership has owner/admin role,
  otherwise `{:error, :forbidden}`.
  """
  def require_team_admin(conn) do
    case conn.assigns[:current_team_membership] do
      %{role: role} when role in @admin_roles -> :ok
      _ -> {:error, :forbidden}
    end
  end

  @doc "True when the membership role is owner or admin."
  def team_admin?(conn) do
    match?(:ok, require_team_admin(conn))
  end
end
