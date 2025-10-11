# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Msgr.Connectors.IRCBridge do
  @moduledoc """
  Connector facade for IRC bridge daemons.
  """

  alias Msgr.Connectors.ServiceBridge

  @type bridge :: ServiceBridge.t()

  @spec new(keyword()) :: bridge()
  def new(opts), do: ServiceBridge.new(:irc, opts)

  @doc """
  Registers IRC credentials (NickServ, SASL, etc.) with the queue worker.
  """
  @spec configure_identity(bridge(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def configure_identity(bridge, params, opts \\ []) do
    payload = Map.take(params, [:user_id, :network, :nickname, :auth])
    ServiceBridge.request(bridge, :configure_identity, payload, opts)
  end

  @doc """
  Queues an outbound PRIVMSG/NOTICE/etc.
  """
  @spec send_command(bridge(), map(), keyword()) :: :ok | {:error, term()}
  def send_command(bridge, params, opts \\ []) do
    payload =
      params
      |> Map.take([:command, :target, :arguments])
      |> Map.put_new(:metadata, Map.get(params, :metadata, %{}))

    ServiceBridge.publish(bridge, :outbound_command, payload, opts)
  end

  @doc """
  Confirms message delivery offsets to allow the worker to trim buffers.
  """
  @spec ack_offset(bridge(), map(), keyword()) :: :ok | {:error, term()}
  def ack_offset(bridge, params, opts \\ []) do
    payload = Map.take(params, [:network, :channel, :offset])
    ServiceBridge.publish(bridge, :ack_offset, payload, opts)
  end
end
