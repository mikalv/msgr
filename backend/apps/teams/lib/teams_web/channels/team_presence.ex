defmodule TeamsWeb.TeamPresence do
  @moduledoc """
  Per-team presence tracking module.

  Used by PresenceChannel to track which team members are online.
  Phoenix.Presence handles the CRDT-based distributed state and
  automatic diff broadcasting on join/leave.
  """

  use Phoenix.Presence,
    otp_app: :teams,
    pubsub_server: Teams.PubSub
end
