defmodule TeamsWeb.ConversationChannel do
  use TeamsWeb, :channel

  @impl true
  def join("conversation:lobby", payload, socket) do
    if authorized?(payload) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end


  @impl true
  def handle_in("create:msg", payload, %{topic: "conversation:" <> destdata} = socket) do
    [team, conversation_id] = String.split(destdata, ".")
    Logger.info "Got create:msg: #{inspect payload} socket: #{inspect socket}"
    message = Message.create_conversation_message(team, conversation_id, payload["profile_id"], payload["content"])
    Logger.info "Message created: #{inspect message}"
    broadcast!(socket, "new:msg", filter_msg_for_json(message))
    {:reply, {:ok, %{"status" => "ok"}}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (room:lobby).
  @impl true
  def handle_in("shout", payload, socket) do
    broadcast(socket, "shout", payload)
    {:noreply, socket}
  end


  defp filter_room_for_json(room), do: Map.drop(Map.from_struct(room), [:__meta__])
  defp filter_msg_for_json(msg), do: Map.drop(Map.from_struct(msg), [:__meta__, :id, :metadata, :room, :conversation, :profile, :parent, :children])


  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
