defmodule MessngrWeb.UserSocket do
  use Phoenix.Socket
  require Logger
  alias Messngr.Accounts

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
  def connect(%{"token" => token} = params, socket, _connect_info) when is_binary(token) and token != "" do
    # JWT-based authentication
    Logger.debug("WebSocket connection attempt via JWT")

    case AuthProvider.Guardian.decode_and_verify(token, %{"typ" => "access"}) do
      {:ok, claims} ->
        account_id = claims["sub"]
        profile_id = claims["pid"]

        with account when not is_nil(account) <- load_account(account_id) do
          profile = case validate_uuid(profile_id, "profile_id") do
            {:ok, pid} -> load_profile(pid, account)
            _ -> nil
          end

          socket =
            socket
            |> assign(:current_account, account)
            |> assign(:current_profile, profile)
            |> assign(:uid, account_id)
            |> assign(:account_id, account_id)
            |> assign(:profile_id, profile_id)
            |> assign(:session_id, nil)
            |> assign(:jwt_teams, claims["ten"])
            |> assign(:tenant, nil)
            |> assign(:team_id, nil)

          Logger.info("WebSocket authenticated via JWT: account=#{account_id}")
          {:ok, socket}
        else
          _ ->
            Logger.warning("WebSocket JWT auth failed: account not found")
            :error
        end

      {:error, reason} ->
        Logger.warning("WebSocket JWT auth failed", reason: inspect(reason))
        :error
    end
  end

  @impl true
  def connect(params, socket, _connect_info) do
    # Rust Gateway validates session and passes account/profile IDs
    account_id = params["account_id"]
    profile_id = params["profile_id"]
    device_id = params["device_id"]
    session_id = params["session_id"]

    Logger.debug("WebSocket connection attempt",
      account_id: account_id,
      profile_id: profile_id,
      session_id: session_id
    )

    with {:ok, account_id} <- validate_uuid(account_id, "account_id"),
         account when not is_nil(account) <- load_account(account_id) do

      # Profile is optional at connect time — team profile is resolved per-channel join
      profile = case validate_uuid(profile_id, "profile_id") do
        {:ok, pid} -> load_profile(pid, account)
        _ -> nil
      end

      socket =
        socket
        |> assign(:current_account, account)
        |> assign(:current_profile, profile)
        |> assign(:uid, account_id)
        |> assign(:account_id, account_id)
        |> assign(:profile_id, profile_id)
        |> assign(:session_id, session_id)
        |> assign(:tenant, nil)
        |> assign(:team_id, nil)

      socket = if device_id, do: maybe_assign_device(socket, device_id, account), else: socket

      Logger.info("WebSocket authenticated: account=#{account_id}")
      {:ok, socket}
    else
      error ->
        Logger.warning("WebSocket authentication failed", error: inspect(error))
        :error
    end
  end

  channel "msgr:device", MessngrWeb.DeviceChannel
  channel "conversation:*", MessngrWeb.ConversationChannel
  channel "rtc:*", MessngrWeb.RTCChannel

  # Team channels (from TeamsWeb, routed here since MessngrWeb.Endpoint serves /socket)
  channel "channel:*", TeamsWeb.ChatChannel
  channel "team:*", TeamsWeb.TeamChannel
  channel "presence:*", TeamsWeb.PresenceChannel

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

  defp validate_uuid(nil, _field), do: {:error, :missing_id}
  defp validate_uuid("", _field), do: {:error, :empty_id}

  defp validate_uuid(id, _field) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> {:error, :invalid_uuid}
    end
  end

  defp validate_uuid(_id, _field), do: {:error, :invalid_type}

  defp load_account(account_id) do
    Accounts.get_account!(account_id)
  rescue
    _ -> nil
  end

  defp load_profile(profile_id, account) do
    profile = Accounts.get_profile!(profile_id)

    if profile.account_id == account.id do
      profile
    else
      Logger.warning("Profile does not belong to account",
        profile_id: profile_id,
        profile_account_id: profile.account_id,
        account_id: account.id
      )

      nil
    end
  rescue
    _ -> nil
  end

  defp maybe_assign_device(socket, device_id, account) do
    device = Accounts.get_device!(device_id)

    if device.account_id == account.id && device.enabled do
      assign(socket, :current_device, device)
    else
      socket
    end
  rescue
    _ -> socket
  end
end
