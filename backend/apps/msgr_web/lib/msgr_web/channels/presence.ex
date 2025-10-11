defmodule MessngrWeb.Presence do
  @moduledoc """
  Tracks realtime presence for conversation participants.
  """

  use Phoenix.Presence,
    otp_app: :msgr_web,
    pubsub_server: Messngr.PubSub
end
