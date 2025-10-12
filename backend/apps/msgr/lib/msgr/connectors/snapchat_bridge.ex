# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Msgr.Connectors.SnapchatBridge do
  @moduledoc """
  Connector facade for the Snapchat web bridge daemon.

  The Elixir core emits high level intents (account linking, message sends,
  sync cursors) and defers the proprietary web client protocol (attestation,
  protobuf payloads, bearer token refresh) to a language-specific worker that
  speaks Snapchat's private APIs.
  """

  alias Msgr.Connectors.ServiceBridge

  @type bridge :: ServiceBridge.t()

  @spec new(keyword()) :: bridge()
  def new(opts), do: ServiceBridge.new(:snapchat, opts)

  @doc """
  Kicks off the SSO + attestation linking ceremony for a Snapchat account.

  The payload includes whatever artefacts the web flow produced: SSO ticket,
  attestation bundle, device fingerprint and the rotating
  `X-Snapchat-Web-Client-Auth` token.
  """
  @spec link_account(bridge(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def link_account(bridge, params, opts \\ []) do
    payload =
      params
      |> Map.take([:user_id, :sso_ticket, :web_client_auth, :attestation, :device_info, :cookies])
      |> compact_map()

    ServiceBridge.request(bridge, :link_account, payload, opts)
  end

  @doc """
  Refreshes the attested chat session when Snapchat rotates bearer tokens.
  """
  @spec refresh_session(bridge(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def refresh_session(bridge, params, opts \\ []) do
    payload =
      params
      |> Map.take([:session_id, :client_id, :web_client_auth, :cookies])
      |> compact_map()

    ServiceBridge.request(bridge, :refresh_session, payload, opts)
  end

  @doc """
  Emits an outbound chat message intent for Snapchat conversations.
  """
  @spec send_message(bridge(), map(), keyword()) :: :ok | {:error, term()}
  def send_message(bridge, params, opts \\ []) do
    metadata = Map.get(params, :metadata)

    payload =
      params
      |> Map.take([:conversation_id, :message, :attachments, :client_context, :metadata])
      |> Map.put(:metadata, metadata || %{})
      |> compact_map()

    ServiceBridge.publish(bridge, :outbound_message, payload, opts)
  end

  @doc """
  Acknowledges message delivery/read state once persisted in the core.
  """
  @spec ack_message(bridge(), map(), keyword()) :: :ok | {:error, term()}
  def ack_message(bridge, params, opts \\ []) do
    payload =
      params
      |> Map.take([:conversation_id, :message_id, :status, :received_at, :read_at])
      |> compact_map()

    ServiceBridge.publish(bridge, :ack_message, payload, opts)
  end

  @doc """
  Requests a sync pass (DeltaSync, Spotlight batches, etc.) from the bridge.
  """
  @spec request_sync(bridge(), map(), keyword()) :: :ok | {:error, term()}
  def request_sync(bridge, params, opts \\ []) do
    payload =
      params
      |> Map.take([:cursor, :limit, :reason, :features])
      |> compact_map()

    ServiceBridge.publish(bridge, :request_sync, payload, opts)
  end

  defp compact_map(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end
end
