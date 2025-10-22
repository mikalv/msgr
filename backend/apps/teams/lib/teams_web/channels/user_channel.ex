defmodule TeamsWeb.UserChannel do
  use TeamsWeb, :channel

  @impl true
  def join("user:lobby", payload, socket) do
    if authorized?(payload) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def join("user:" <> uid, payload, socket) do
    unless socket.assigns[:uid] == uid do
      {:error, %{reason: "unauthorized"}}
    else
      send(self(), :after_join)
      {:ok, socket}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    tenant = socket.assigns[:tenant]
    uid = socket.assigns[:uid]
    token = socket.assigns[:token]
    {:ok, claims} = AuthProvider.Guardian.decode_and_verify(token)
    profileID = claims["pid"]
    Logger.info "User #{uid} joined their own channel under the #{tenant} tenant"
    data = Teams.ClientBootstrap.build_bootstrap_payload_for(tenant, profileID)
    push(socket, "bootstrap:packet", %{type: "bootstrap", status: "ok", "data": data})
    {:noreply, socket}
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (user:lobby).
  @impl true
  def handle_in("shout", payload, socket) do
    broadcast(socket, "shout", payload)
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
