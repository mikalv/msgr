defmodule Teams.AppNotification do
  alias Phoenix.PubSub

  def notify(uid, message) do
    PubSub.broadcast!(Teams.PubSub, "user:#{uid}", message)
  end
end
