defmodule TeamsWeb.ChatChannel do
  use TeamsWeb, :channel
  alias TeamsWeb.UserPresence
  alias Teams.TenantModels.{Profile, Message}
  alias TeamsWeb.MiddleLayers.ChannelLayer
  require Logger

  intercept ["new_msg", "user_joined"]

  @impl true
  def join("channel:lobby", payload, socket) do
    if authorized?(payload) do
      #Logger.info "socket: #{inspect socket}"
      send(self(), :after_join)
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  alias Phoenix.Socket.Broadcast
  def handle_info(%Broadcast{topic: topic, event: event, payload: payload}, socket) do
    Logger.info "handle_info: topic=#{topic} event=#{event} socket=#{inspect socket}"
    push(socket, event, payload)
    {:noreply, socket}
  end

  def join("channel:" <> destdata, _payload, socket) do
    [team, channel_id] = String.split(destdata, ".")
    uid = socket.assigns[:uid]
    Logger.info "Joining channel: #{channel_id} for user: #{uid} team #{team}"
    :ok = ChannelWatcher.monitor(:channels, self(), {__MODULE__, :leave, [channel_id, uid]})
    {:ok, socket}
  end

  def join("channel:" <> _private_channel_id, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  def handle_info(:after_join, socket) do
    {:ok, _} =
    UserPresence.track(socket, socket.assigns.uid, %{
        online_at: inspect(System.system_time(:second))
      })

    push(socket, "presence_state", UserPresence.list(socket))
    {:noreply, socket}
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  def handle_in("leave", _payload, socket) do
    {:stop, :normal, socket}
  end

  def handle_in("create:channel", payload, socket) do
    team = payload["team"]
    profile_id = payload["profile_id"]
    options = payload["options"]
    members = Map.get(payload, "members", [])
    Logger.info "Got create:channel: #{inspect payload}"
    case ChannelLayer.create_channel(team, profile_id, options, members) do
      {:ok, channel} ->
        Logger.info "Channel created: #{inspect channel}"
        broadcast!(socket, "new:channel", %{"team" => team, "channels" => [filter_channel_for_json(channel)]})
        {:reply, {:ok, %{"channel" => filter_channel_for_json(channel)}}, socket}

      {:error, err} ->
        Logger.error "Error while trying to create channel: #{inspect err}"
        {:reply, {:error, %{"status" => "error", "details" => "Error while trying to create channel!"}}, socket}

      {:permission_error, err} ->
        {:reply, {:error, %{"status" => "error", "details" => "You don't have the roles or permission to create a new channel! (#{err})"}}, socket}
    end
  end

  def handle_in("create:msg", payload, %{topic: "channel:" <> destdata} = socket) do
    [team, channel_id] = String.split(destdata, ".")
    Logger.info "Got create:msg: #{inspect payload} socket: #{inspect socket}"
    message = Message.create_channel_message(team, channel_id, payload["profile_id"], payload["content"])
    Logger.info "Message created: #{inspect message}"
    broadcast!(socket, "new:msg", filter_msg_for_json(message))
    {:reply, {:ok, %{"message" => "ack"}}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (channel:lobby).
  @impl true
  def handle_in("shout", payload, socket) do
    broadcast(socket, "shout", payload)
    {:noreply, socket}
  end

  def handle_out("user_joined", msg, socket) do
    push(socket, "user_joined", msg)
    #{:noreply, socket}
  end

  def handle_out("new:msg", msg, socket) do
    push(socket, "new:msg", msg)
  end

  def leave(channel_id, uid) do
    Logger.info "Leaving channel: #{channel_id} for user: #{uid}"
    ChannelWatcher.unmonitor(:channels, self())
  end


  defp filter_channel_for_json(channel), do: Map.drop(Map.from_struct(channel), [:__meta__])
  defp filter_msg_for_json(msg), do: Map.drop(Map.from_struct(msg), [:__meta__, :id, :metadata, :channel, :conversation, :profile, :parent, :children])


  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
