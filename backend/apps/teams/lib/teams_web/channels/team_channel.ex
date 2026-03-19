defmodule TeamsWeb.TeamChannel do
  @moduledoc """
  Team-wide channel for broadcasting structural events like
  new channels, member joins/leaves, and channel updates.

  Topic: "team:{slug}"
  """

  use TeamsWeb, :channel
  require Logger

  alias Teams.TeamManagement
  alias Teams.Channels

  @impl true
  def join("team:" <> slug, _payload, socket) do
    account_id = socket.assigns[:uid]
    tenant = socket.assigns[:tenant]

    case TeamManagement.get_team_by_slug(slug) do
      nil ->
        {:error, %{reason: "team_not_found"}}

      team ->
        if TeamManagement.member?(team.id, account_id) do
          socket =
            socket
            |> assign(:team_slug, slug)
            |> assign(:team_id, team.id)
            |> assign(:prefix, team.schema_name)

          {:ok, socket}
        else
          {:error, %{reason: "not_a_member"}}
        end
    end
  end

  # ── Incoming events ──────────────────────────────────────────

  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # ── Broadcasting helpers (called from controllers/contexts) ──

  @doc """
  Broadcasts that a new channel was created in the team.
  Call from channel creation logic:

      TeamsWeb.Endpoint.broadcast("team:#{slug}", "new:channel", payload)
  """
  def broadcast_new_channel(slug, channel) do
    TeamsWeb.Endpoint.broadcast("team:#{slug}", "new:channel", %{
      id: channel.id,
      name: channel.name,
      slug: channel.slug,
      icon: channel.icon,
      kind: channel.kind,
      visibility: channel.visibility,
      topic: channel.topic
    })
  end

  @doc """
  Broadcasts that a member joined the team.
  """
  def broadcast_member_joined(slug, profile) do
    TeamsWeb.Endpoint.broadcast("team:#{slug}", "member:joined", %{
      profile_id: profile.id,
      display_name: profile.display_name,
      avatar_url: profile.avatar_url,
      role: profile.role
    })
  end

  @doc """
  Broadcasts that a member left the team.
  """
  def broadcast_member_left(slug, profile_id) do
    TeamsWeb.Endpoint.broadcast("team:#{slug}", "member:left", %{
      profile_id: profile_id
    })
  end

  @doc """
  Broadcasts that a channel was updated (topic, icon, etc.).
  """
  def broadcast_channel_updated(slug, channel) do
    TeamsWeb.Endpoint.broadcast("team:#{slug}", "channel:updated", %{
      id: channel.id,
      name: channel.name,
      slug: channel.slug,
      icon: channel.icon,
      topic: channel.topic,
      visibility: channel.visibility
    })
  end
end
