defmodule TeamsWeb.MiddleLayers.InviteLayer do
  require Logger

  @doc """
  Invite a user to a team

  This will also make a User record in AuthProvider if the user doesn't exist. This is so that we can add
  the user id to the team members list - so when the user signs in, the team will be listed.
  """
  @spec invite_user(String.t(), Teams.TenantModels.Profile.t(), String.t()) :: {:ok, Teams.TenantModels.Invitation.t}
  def invite_user(teamName, profile, whotoinvite) do
    {:ok, invitation} = case is_identifier_email?(whotoinvite) do
      true ->
        {:ok, res} = Teams.TenantModels.Invitation.create_email_invitation(teamName, profile, whotoinvite)
        {:ok, user} = AuthProvider.UserHelper.find_or_register_user_by_email(whotoinvite)
        Teams.TenantTeam.append_members(teamName, [user.id])
        {:ok, res}
      false ->
        {:ok, res} = Teams.TenantModels.Invitation.create_msisdn_invitation(teamName, profile, whotoinvite)
        {:ok, user} = AuthProvider.UserHelper.find_or_register_user_by_msisdn(whotoinvite)
        Teams.TenantTeam.append_members(teamName, [user.id])
        {:ok, res}
    end

  end

  @spec is_identifier_email?(String.t()) :: boolean
  defp is_identifier_email?(identifier) do
    String.match?(identifier, ~r/@/)
  end
end
