defmodule MessngrWeb.UserSocket do
  use Phoenix.Socket
  require Logger
  alias MessngrWeb.Plugs.NoiseSession

  # A Socket handler
  #
  # It's possible to control the websocket connection and
  # assign values that can be accessed by your channel topics.

  ## Channels
  # Uncomment the following line to define a "room:*" topic
  # pointing to the `MessngrWeb.RoomChannel`:
  #
  # channel "room:*", MessngrWeb.RoomChannel
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
  def connect(params, socket, connect_info) do
    case resolve_token(params, connect_info) do
      {:ok, token} ->
        case NoiseSession.verify_token(token) do
          {:ok, actor} ->
            Logger.debug("WebSocket authenticated via Noise session",
              account_id: actor.account.id,
              profile_id: actor.profile.id
            )

            {:ok,
             socket
             |> assign(:current_account, actor.account)
             |> assign(:current_profile, actor.profile)
             |> maybe_assign_device(actor.device)
             |> assign(:noise_session_token, actor.encoded_token)
             |> assign(:noise_session, actor.session)}

          {:error, reason} ->
            Logger.warning("Noise session verification failed", reason: inspect(reason))
            :error
        end

      :error ->
        Logger.warning("Missing Noise session token for websocket connection")
        :error
    end
  end

  channel "msgr:device", MessngrWeb.DeviceChannel
  channel "conversation:*", MessngrWeb.ConversationChannel
  channel "rtc:*", MessngrWeb.RTCChannel

  # Socket IDs are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     Elixir.MessngrWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(_socket), do: nil

  defp resolve_token(params, connect_info) do
    with :error <- normalize_token(Map.get(params, "noise_session")),
         :error <- normalize_token(Map.get(params, "token")),
         :error <- normalize_token(connect_info |> Map.get(:session, %{}) |> Map.get("noise_session_token")) do
      :error
    else
      {:ok, token} -> {:ok, token}
    end
  end

  defp normalize_token(token) when is_binary(token) do
    trimmed = String.trim(token)
    if trimmed == "", do: :error, else: {:ok, trimmed}
  end

  defp normalize_token(_), do: :error

  defp maybe_assign_device(socket, nil), do: socket
  defp maybe_assign_device(socket, device), do: assign(socket, :current_device, device)
end
