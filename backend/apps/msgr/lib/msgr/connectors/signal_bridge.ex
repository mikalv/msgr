# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Msgr.Connectors.SignalBridge do
  @moduledoc """
  Connector facade for Signal bridge daemons.

  Provides helpers for publishing queue envelopes that drive the device-link
  handshake, outbound messaging, and acknowledgement flows handled by the
  Python bridge daemon.
  """

  alias Msgr.Connectors.ServiceBridge

  @type bridge :: ServiceBridge.t()

  @spec new(keyword()) :: bridge()
  def new(opts), do: ServiceBridge.new(:signal, opts)

  @doc """
  Initiates or resumes the Signal device-link ceremony for a Msgr identity.
  """
  @spec link_account(bridge(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def link_account(bridge, params, opts \\ []) do
    payload = Map.take(params, [:user_id, :session, :linking])
    ServiceBridge.request(bridge, :link_account, payload, opts)
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
end
