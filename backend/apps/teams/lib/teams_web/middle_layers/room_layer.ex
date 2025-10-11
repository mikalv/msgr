defmodule TeamsWeb.MiddleLayers.RoomLayer do
  require Logger
  alias Teams.TenantModels.{Profile, Room}

  def create_room(team, profile_id, options, members \\ []) do
    profile = Profile.get_by_id(team, profile_id)
    if Profile.can?(team, profile, "can_create_room") do
      case Room.create_room(team, profile, %{
        "name" => options["room_name"],
        "description" => options["room_description"],
        "is_secret" => options["is_secret"]
      }, members) do
        {:ok, room} ->
          {:ok, room}
        {:error, err} ->
          {:error, "Error while trying to create room!"}
      end
    else
      {:permission_error, "Profile lacks 'can_create_room' permission"}
    end
  end
end
