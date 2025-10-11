defmodule TeamsWeb.TeamChannel do
  use TeamsWeb, :channel

  @impl true
  def join("team:lobby", payload, socket) do
    {:ok, socket}
  end

  @impl true
  def join("team:invite", payload, socket) do
    profile_id = socket.assigns[:profile_id]
    team = socket.assigns[:tenant]
    profile = Teams.TenantModels.Profile.get_by_id(team, profile_id)
    if authorized_to_invite?(team, profile) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("invite:user", %{"identifier" => whotoinvite, "team_name" => teamName, "profile_id" => profileID} = payload, %{topic: "team:invite"} = socket) do
    profile = Teams.TenantModels.Profile.get_by_id(teamName, profileID)
    if authorized_to_invite?(teamName, profile) do
      TeamsWeb.MiddleLayers.InviteLayer.invite_user(teamName, profile, whotoinvite)
      {:reply, {:ok, %{status: "ack"}}, socket}
    else
      {:reply, {:error, %{reason: "unauthorized"}}, socket}
    end
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (team:lobby).
  @impl true
  def handle_in("shout", payload, socket) do
    broadcast(socket, "shout", payload)
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized_to_invite?(team, profile) do
    Teams.TenantModels.Profile.can?(team, profile, "can_invite_user")
  end
end
