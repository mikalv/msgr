defmodule AuthProvider.DeviceChannel do
  use AuthProvider, :channel
  require Logger

  # https://hexdocs.pm/guardian/readme.html

  @impl true
  def join("msgr:device", payload, socket) do
    if authorized?(payload) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("identify", %{"from" => from, "payload" => payload}, socket) do
    Logger.info "Payload: #{inspect payload}"
    if AuthProvider.DeviceHelper.validate_device_signature(payload) do
      {:ok, device} = AuthProvider.DeviceHelper.find_or_register_device(payload)
      Logger.info "Device #{inspect device}"
      {:reply, {:ok, from}, socket}
    else
      {:reply, {:error, "Invalid signature"}, socket}
    end
  end

  def handle_in("login_request", %{"from" => from, "number" => number}, socket) do
    Logger.info "Login request from #{number} via deviceId #{from}"
    {:ok, user} = AuthProvider.UserHelper.find_or_register_user_by_msisdn(number, from)
    :ok = AuthProvider.UserHelper.create_login_code_for_user(user)
    push(socket, "login_response", %{"status" => "ok", "next" => "code", "uid" => user.uid})
    {:noreply, socket}
  end

  def handle_in("login_code", %{"from" => from, "code" => code, "number" => number}, socket) do
    Logger.info "Login code (#{code}) from #{number} via deviceId #{from}"
    {:ok, user} = AuthProvider.UserHelper.find_or_register_user_by_msisdn(number, from)
    case AuthProvider.UserHelper.validate_login_code_for_user(code, user) do
      {:ok, :valid_code} ->
        handle_login(user, socket)
      {:error, :invalid_code} ->
        push(socket, "login_code_response", %{"status" => "error", "details" => "wrong code", "uid" => user.uid})
    end
    {:noreply, socket}
  end

  def handle_in("new_msg", %{"body" => body}, socket) do
    broadcast!(socket, "new_msg", %{body: body})
    {:noreply, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (device:lobby).
  @impl true
  def handle_in("shout", payload, socket) do
    broadcast(socket, "shout", payload)
    {:noreply, socket}
  end

  def handle_login(user, socket) do
    {:ok, token, claims} = AuthProvider.Guardian.encode_and_sign(user)
    push(socket, "login_code_response", %{"status" => "ok", "token" => token, "claims" => claims, "uid" => user.uid})
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
