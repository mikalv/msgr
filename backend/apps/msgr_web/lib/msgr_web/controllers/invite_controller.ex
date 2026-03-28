defmodule MessngrWeb.InviteController do
  use MessngrWeb, :controller
  require Logger

  alias Messngr.Teams.InviteLink
  alias Teams.TeamManagement

  action_fallback MessngrWeb.FallbackController

  @doc "POST /api/invite/:code — redeem an invite code"
  def redeem(conn, %{"code" => code}) do
    account = conn.assigns.current_account

    case InviteLink.get_valid_by_code(code) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Invalid or expired invite link"})

      %{team: team} = link ->
        # Check if already a member
        case TeamManagement.member?(team.id, account.id) do
          true ->
            # Already a member — just return team info
            json(conn, %{
              data: %{
                team: team_json(team),
                already_member: true
              }
            })

          false ->
            case TeamManagement.join_team(team, account.id, %{
                   display_name: account.handle || account.email || "Member"
                 }) do
              {:ok, result} ->
                InviteLink.increment_used_count(link)

                Logger.info(
                  "Invite redeemed: account=#{account.id} team=#{team.slug} code=#{link.code}"
                )

                conn
                |> put_status(:created)
                |> json(%{
                  data: %{
                    team: team_json(team),
                    profile_id: result.profile.id,
                    already_member: false
                  }
                })

              {:error, reason} ->
                Logger.warning("Invite join failed: #{inspect(reason)}")

                conn
                |> put_status(:unprocessable_entity)
                |> json(%{error: "Failed to join team"})
            end
        end
    end
  end

  defp team_json(team) do
    %{
      id: team.id,
      name: team.name,
      slug: team.slug
    }
  end
end
