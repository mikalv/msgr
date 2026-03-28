defmodule TeamsWeb.MiddleLayers.ChannelLayer do
  require Logger
  alias Teams.TenantModels.{Profile, Channel}

  def create_channel(team, profile_id, options, members \\ []) do
    profile = Profile.get_by_id(team, profile_id)

    if Profile.can?(team, profile, "can_create_channel") do
      case Channel.create_channel(
             team,
             profile,
             %{
               "name" => options["channel_name"],
               "description" => options["channel_description"],
               "is_secret" => options["is_secret"]
             },
             members
           ) do
        {:ok, channel} ->
          {:ok, channel}

        {:error, err} ->
          {:error, "Error while trying to create channel!"}
      end
    else
      {:permission_error, "Profile lacks 'can_create_channel' permission"}
    end
  end
end
