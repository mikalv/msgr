# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Msgr.Connectors.MatrixBridge do
  @moduledoc """
  Connector facade for Matrix homeserver bridge daemons.
  """

  alias Msgr.Connectors.ServiceBridge

  @type bridge :: ServiceBridge.t()

  @spec new(keyword()) :: bridge()
  def new(opts), do: ServiceBridge.new(:matrix, opts)

  @doc """
  Orchestrates login or SSO token exchange via the language-specific bridge worker.
  """
  @spec link_account(bridge(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def link_account(bridge, params, opts \\ []) do
    payload = Map.take(params, [:user_id, :homeserver, :login, :device_id])
    ServiceBridge.request(bridge, :link_account, payload, opts)
  end

  @doc """
  Broadcasts an outbound Matrix event (text, reactions, etc.).
  """
  @spec send_event(bridge(), map(), keyword()) :: :ok | {:error, term()}
  def send_event(bridge, params, opts \\ []) do
    payload =
      params
      |> Map.take([:room_id, :event_type, :content, :txn_id])
      |> Map.put_new(:metadata, Map.get(params, :metadata, %{}))

    ServiceBridge.publish(bridge, :outbound_event, payload, opts)
  end

  @doc """
  Acknowledges sync tokens once consumed by the Elixir core.
  """
  @spec ack_sync(bridge(), map(), keyword()) :: :ok | {:error, term()}
  def ack_sync(bridge, params, opts \\ []) do
    payload = Map.take(params, [:next_batch, :stream_position])
    ServiceBridge.publish(bridge, :ack_sync, payload, opts)
  end
end
