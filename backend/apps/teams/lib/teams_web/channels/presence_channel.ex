defmodule TeamsWeb.PresenceChannel do
  @moduledoc """
  Per-team presence tracking using Phoenix.Presence.

  Topic: "presence:{team_slug}"

  Tracks online/offline status for team members. Auto-broadcasts
  join/leave events to all subscribers in the team.
  """

  use TeamsWeb, :channel
  require Logger

  alias TeamsWeb.TeamPresence
  alias Teams.TeamManagement

  @impl true
  def join("presence:" <> slug, _payload, socket) do
    account_id = socket.assigns[:uid]
    prefix = socket.assigns[:tenant]
    profile_id = socket.assigns[:profile_id]

    case TeamManagement.get_team_by_slug(slug) do
      nil ->
        {:error, %{reason: "team_not_found"}}

      team ->
        if TeamManagement.member?(team.id, account_id) do
          socket =
            socket
            |> assign(:team_slug, slug)
            |> assign(:prefix, prefix)

          send(self(), :after_join)
          {:ok, socket}
        else
          {:error, %{reason: "not_a_member"}}
        end
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    prefix = socket.assigns[:prefix]
    profile_id = socket.assigns[:profile_id]

    # Resolve display name from profile
    display_name =
      case Teams.TenantModels.Profile.get_by_id(prefix, profile_id) do
        nil -> "Unknown"
        profile -> profile.display_name || "Unknown"
      end

    # Track this user's presence
    {:ok, _} =
      TeamPresence.track(socket, profile_id, %{
        profile_id: profile_id,
        display_name: display_name,
        online_at: DateTime.utc_now() |> DateTime.to_iso8601()
      })

    # Push current presence state to the newly joined client
    push(socket, "presence_state", TeamPresence.list(socket))

    {:noreply, socket}
  end

  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end
end
