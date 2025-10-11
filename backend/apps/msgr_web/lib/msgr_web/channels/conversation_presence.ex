defmodule MessngrWeb.ConversationPresence do
  @moduledoc """
  Tracks active watchers for conversation channels using Phoenix Presence.
  """

  use Phoenix.Presence,
    otp_app: :msgr_web,
    pubsub_server: Messngr.PubSub
end
