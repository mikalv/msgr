defmodule TeamsWeb.UserSocket do
  use Phoenix.Socket
  require Logger

  # A Socket handler
  #
  # It's possible to control the websocket connection and
  # assign values that can be accessed by your channel topics.

  channel "room:*", TeamsWeb.RoomChannel
  channel "conv:*", TeamsWeb.ConversationChannel
  channel "private:*", TeamsWeb.PrivateChannel
  channel "device:*", TeamsWeb.DeviceChannel
  channel "user:*", TeamsWeb.UserChannel
  channel "team:*", TeamsWeb.TeamChannel
  channel "call:*", TeamsWeb.CallChannel

  #
  # To create a channel file, use the mix task:
  #
  #     mix phx.gen.channel Room
  #
  # See the [`Channels guide`](https://hexdocs.pm/phoenix/channels.html)
  # for further details.


  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error` or `{:error, term}`. To control the
  # response the client receives in that case, [define an error handler in the
  # websocket
  # configuration](https://hexdocs.pm/phoenix/Phoenix.Endpoint.html#socket/3-websocket-configuration).
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  @impl true
  def connect(%{"token" => token} = _params, socket, %{uri: %URI{} = uri} = connect_info) do
    Logger.debug "New socket connection! with connect_info: #{inspect connect_info}"
    Logger.debug "uri: #{inspect uri}"
    case AuthProvider.Guardian.decode_and_verify(token) do
      {:ok, claims} ->
        Logger.info "User logged onto websocket with claims: #{inspect claims}"
        socket = socket
          |> assign(:uid, claims["sub"])
          |> assign(:tenant, claims["ten"])
          |> assign(:profile_id, claims["pid"])
          |> assign(:team_id, claims["tei"])
          |> assign(:token, token)
        {:ok, socket}
      {:error, emsg} ->
        Logger.warning "Socket connection had invalid token: #{inspect emsg} token: #{inspect token}"
        {:error, "Invalid token!"}
    end
  end

  def disconnect_user(uid) do
    TeamsWeb.Endpoint.broadcast("user_socket:#{uid}", "disconnect", %{"reason" => "testing"})
  end


  # Socket IDs are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     Elixir.TeamsWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(socket), do: "user:#{socket.assigns.uid}"
  #def id(_socket), do: nil
end
