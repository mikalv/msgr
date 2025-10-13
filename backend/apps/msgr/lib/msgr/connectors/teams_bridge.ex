# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Msgr.Connectors.TeamsBridge do
  @moduledoc """
  Connector facade for Microsoft Teams bridge daemons.

  Provides helpers for emitting queue messages that coordinate Azure AD consent,
  outbound messaging, and acknowledgement flows while supporting multi-tenant
  installations per Msgr account.
  """

  alias Msgr.Connectors.{ServiceBridge, SessionVault}
  alias Messngr.Bridges

  @type bridge :: ServiceBridge.t()

  @spec new(keyword()) :: bridge()
  def new(opts), do: ServiceBridge.new(:teams, opts)

  @doc """
  Initiates or resumes an Azure AD consent handshake for a tenant.
  """
  @spec link_account(bridge(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def link_account(bridge, params, opts \\ []) do
    payload =
      params
      |> Map.take([:user_id, :tenant, :session, :capabilities, :subscription])

    case ServiceBridge.request(bridge, :link_account, payload, opts) do
      {:ok, response} ->
        instance = resolve_instance(params, response)

        case persist_link_response(bridge, params, response, instance) do
          :ok -> {:ok, response}
          {:error, reason} -> {:error, reason}
        end

      other ->
        other
    end
  end

  @doc """
  Publishes an outbound Teams chat/message intent.
  """
  @spec send_message(bridge(), map(), keyword()) :: :ok | {:error, term()}
  def send_message(bridge, params, opts \\ []) do
    payload =
      params
      |> Map.take([:chat_id, :conversation_id, :message, :attachments, :mentions, :reply_to, :metadata])
      |> Map.put_new(:attachments, List.wrap(Map.get(params, :attachments, [])))
      |> Map.put_new(:mentions, List.wrap(Map.get(params, :mentions, [])))
      |> Map.put_new(:metadata, Map.get(params, :metadata, %{}))

    ServiceBridge.publish(bridge, :outbound_message, payload, opts)
  end

  @doc """
  Acknowledges inbound Teams webhook events.
  """
  @spec ack_event(bridge(), map(), keyword()) :: :ok | {:error, term()}
  def ack_event(bridge, params, opts \\ []) do
    payload = Map.take(params, [:event_id, :status, :received_at])
    ServiceBridge.publish(bridge, :ack_event, payload, opts)
  end

  defp persist_link_response(%ServiceBridge{} = bridge, params, response, instance) do
    status = Map.get(response, "status") || Map.get(response, :status)

    with :linked <- normalise_status(status),
         {:ok, account_id} <- fetch_account_id(params),
         {:ok, attrs} <- build_sync_attrs(response, bridge.service, account_id, instance),
         {:ok, _record} <- Bridges.sync_linked_identity(account_id, bridge.service, attrs, instance: instance) do
      :ok
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

  defp resolve_instance(params, response) do
    candidate =
      fetch_field(params, :instance) ||
        extract_tenant_id(fetch_tenant(params)) ||
        extract_tenant_id(fetch_tenant(response))

    candidate
    |> case do
      nil -> Bridges.default_instance()
      value ->
        value
        |> to_string()
        |> String.trim()
        |> case do
          "" -> Bridges.default_instance()
          trimmed -> trimmed
        end
    end
  end

  defp build_sync_attrs(response, service, account_id, instance) when is_map(response) do
    tenant = fetch_tenant(response)
    user = fetch_user(response)
    session = fetch_map(response, :session)
    capabilities = fetch_map(response, :capabilities)

    with {:ok, session_map} <- SessionVault.scrub_and_store(service, account_id, instance, session) do
      contacts =
        response
        |> fetch_list([:members, :contacts])

      channels =
        response
        |> fetch_list([:chats, :conversations, :teams])

      {:ok,
       %{
         external_id: extract_user_id(user),
         display_name: extract_display_name(user),
         metadata: build_metadata(tenant, user),
         session: ensure_map(session_map),
         capabilities: ensure_map(capabilities),
         contacts: ensure_list(contacts),
         channels: ensure_list(channels)
       }}
    end
  end

  defp build_sync_attrs(_response, _service, _account_id, _instance), do: {:ok, %{}}

  defp fetch_tenant(data) when is_map(data) do
    fetch_map(data, :tenant) || fetch_map(data, :organization) || %{}
  end

  defp fetch_tenant(_), do: %{}

  defp fetch_user(data) when is_map(data) do
    fetch_map(data, :user) || fetch_map(data, :account) || %{}
  end

  defp fetch_user(_), do: %{}

  defp build_metadata(tenant, user) do
    %{}
    |> maybe_put("tenant", stringify_keys(tenant))
    |> maybe_put("user", stringify_keys(user))
  end

  defp maybe_put(map, _key, value) when value in [%{}, nil], do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp extract_user_id(user) when is_map(user) do
    fetch_field(user, :id) || fetch_field(user, :user_id)
    |> case do
      nil -> nil
      value -> to_string(value)
    end
  end

  defp extract_user_id(_), do: nil

  defp extract_display_name(user) when is_map(user) do
    fetch_field(user, :display_name) ||
      fetch_field(user, :displayName) ||
      build_name(fetch_field(user, :given_name) || fetch_field(user, :givenName),
        fetch_field(user, :surname) || fetch_field(user, :family_name)) ||
      fetch_field(user, :mail) ||
      extract_user_id(user)
  end

  defp extract_display_name(_), do: nil

  defp extract_tenant_id(tenant) when is_map(tenant) do
    fetch_field(tenant, :id) || fetch_field(tenant, :tenant_id) || fetch_field(tenant, :azure_ad_id)
    |> case do
      nil -> nil
      value -> to_string(value)
    end
  end

  defp extract_tenant_id(value) when is_binary(value) do
    value |> String.trim() |> case do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp extract_tenant_id(_), do: nil

  defp build_name(first, last) do
    [first, last]
    |> Enum.reject(fn value -> value in [nil, ""] end)
    |> case do
      [] -> nil
      values -> Enum.join(values, " ")
    end
  end

  defp fetch_map(map, key) when is_map(map) do
    case fetch_field(map, key) do
      value when is_map(value) -> value
      _ -> %{}
    end
  end

  defp fetch_map(_map, _key), do: %{}

  defp fetch_list(map, keys) when is_map(map) and is_list(keys) do
    keys
    |> Enum.find_value(fn key ->
      case fetch_field(map, key) do
        value when is_list(value) -> value
        _ -> nil
      end
    end) || []
  end

  defp fetch_list(_map, _keys), do: []

  defp fetch_field(map, key) when is_map(map) and is_atom(key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp fetch_field(map, key) when is_map(map) and is_binary(key) do
    Map.get(map, key) ||
      case safe_existing_atom(key) do
        nil -> nil
        atom_key -> Map.get(map, atom_key)
      end
  end

  defp fetch_field(_map, _key), do: nil

  defp ensure_map(value) when is_map(value), do: value
  defp ensure_map(_), do: %{}

  defp ensure_list(value) when is_list(value), do: value
  defp ensure_list(_), do: []

  defp stringify_keys(map) when is_map(map) do
    map
    |> Enum.map(fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), stringify_keys(value)}
      {key, value} when is_binary(key) -> {key, stringify_keys(value)}
      {key, value} -> {to_string(key), stringify_keys(value)}
    end)
    |> Map.new()
  end

  defp stringify_keys(list) when is_list(list), do: Enum.map(list, &stringify_keys/1)
  defp stringify_keys(value), do: value

  defp safe_existing_atom(value) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> nil
  end

  defp safe_existing_atom(_value), do: nil
end
