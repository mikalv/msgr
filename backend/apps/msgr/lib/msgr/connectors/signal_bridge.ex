# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Msgr.Connectors.SignalBridge do
  @moduledoc """
  Connector facade for Signal bridge daemons.

  Provides helpers for publishing queue envelopes that drive the device-link
  handshake, outbound messaging, and acknowledgement flows handled by the
  Python bridge daemon.
  """

  alias Msgr.Connectors.ServiceBridge
  alias Messngr.Bridges

  @type bridge :: ServiceBridge.t()

  @spec new(keyword()) :: bridge()
  def new(opts), do: ServiceBridge.new(:signal, opts)

  @doc """
  Initiates or resumes the Signal device-link ceremony for a Msgr identity.
  """
  @spec link_account(bridge(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def link_account(bridge, params, opts \\ []) do
    payload = Map.take(params, [:user_id, :session, :linking])

    case ServiceBridge.request(bridge, :link_account, payload, opts) do
      {:ok, response} ->
        case persist_link_response(bridge, params, response) do
          :ok -> {:ok, response}
          {:error, reason} -> {:error, reason}
        end

      other ->
        other
    end
  end

  @doc """
  Publishes an outbound message intent for a Signal conversation.
  """
  @spec send_message(bridge(), map(), keyword()) :: :ok | {:error, term()}
  def send_message(bridge, params, opts \\ []) do
    payload =
      params
      |> Map.take([:chat_id, :message, :attachments, :metadata])
      |> Map.put_new(:attachments, Map.get(params, :attachments, []))
      |> Map.put_new(:metadata, Map.get(params, :metadata, %{}))

    ServiceBridge.publish(bridge, :outbound_message, payload, opts)
  end

  @doc """
  Acknowledges inbound Signal events once Msgr has persisted them.
  """
  @spec ack_event(bridge(), map(), keyword()) :: :ok | {:error, term()}
  def ack_event(bridge, params, opts \\ []) do
    payload = Map.take(params, [:event_id, :status, :received_at])
    ServiceBridge.publish(bridge, :ack_event, payload, opts)
  end

  defp persist_link_response(%ServiceBridge{} = bridge, params, response) do
    status = Map.get(response, "status") || Map.get(response, :status)

    with :linked <- normalise_status(status),
         {:ok, account_id} <- fetch_account_id(params),
         attrs <- build_sync_attrs(response) do
      Bridges.sync_linked_identity(account_id, bridge.service, attrs)
      |> case do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    else
      :skip -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalise_status(status) when status in ["linked", :linked], do: :linked
  defp normalise_status(_other), do: :skip

  defp fetch_account_id(params) when is_map(params) do
    params
    |> Map.get(:user_id) || Map.get(params, "user_id")
    |> case do
      nil -> {:error, :missing_account_id}
      value when is_binary(value) and value != "" -> {:ok, value}
      value -> {:error, {:invalid_account_id, value}}
    end
  end

  defp build_sync_attrs(response) when is_map(response) do
    user = Map.get(response, "user") || Map.get(response, :user) || %{}
    session = Map.get(response, "session") || Map.get(response, :session) || %{}
    capabilities = Map.get(response, "capabilities") || Map.get(response, :capabilities) || %{}

    contacts =
      response
      |> Map.get("contacts") || Map.get(response, :contacts) || []

    conversations =
      response
      |> Map.get("conversations") || Map.get(response, :conversations) || []

    %{
      external_id: extract_user_id(user),
      display_name: extract_display_name(user),
      metadata: %{"user" => stringify_keys(user)},
      session: ensure_map(session),
      capabilities: ensure_map(capabilities),
      contacts: ensure_list(contacts),
      channels: ensure_list(conversations)
    }
  end

  defp extract_user_id(user) do
    cond do
      is_map(user) and Map.has_key?(user, "uuid") -> user["uuid"]
      is_map(user) and Map.has_key?(user, :uuid) -> user[:uuid]
      is_map(user) and Map.has_key?(user, "id") -> user["id"]
      true -> nil
    end
    |> case do
      nil -> nil
      value -> to_string(value)
    end
  end

  defp extract_display_name(user) when is_map(user) do
    display = Map.get(user, "display_name") || Map.get(user, :display_name)
    name = Map.get(user, "name") || Map.get(user, :name)
    phone = Map.get(user, "phone_number") || Map.get(user, :phone_number)

    cond do
      is_binary(display) and display != "" -> display
      is_binary(name) and name != "" -> name
      is_binary(phone) and phone != "" -> phone
      true -> extract_user_id(user)
    end
  end

  defp extract_display_name(_user), do: nil

  defp ensure_map(value) when is_map(value), do: value
  defp ensure_map(_), do: %{}

  defp ensure_list(value) when is_list(value), do: value
  defp ensure_list(_), do: []

  defp stringify_keys(map) when is_map(map) do
    map
    |> Enum.map(fn
      {key, value} when is_binary(key) -> {key, value}
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {to_string(key), value}
    end)
    |> Map.new()
  end

  defp stringify_keys(_), do: %{}
end
