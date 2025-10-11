# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Msgr.Connectors.XMPPBridge do
  @moduledoc """
  Connector facade for XMPP bridge daemons.
  """

  alias Msgr.Connectors.ServiceBridge

  @type bridge :: ServiceBridge.t()

  @spec new(keyword()) :: bridge()
  def new(opts), do: ServiceBridge.new(:xmpp, opts)

  @doc """
  Configures XMPP credentials, resource bindings, and roster syncs.
  """
  @spec link_account(bridge(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def link_account(bridge, params, opts \\ []) do
    payload = Map.take(params, [:user_id, :jid, :password, :resource])
    ServiceBridge.request(bridge, :link_account, payload, opts)
  end

  @doc """
  Publishes outbound stanzas to the XMPP worker.
  """
  @spec send_stanza(bridge(), map(), keyword()) :: :ok | {:error, term()}
  def send_stanza(bridge, params, opts \\ []) do
    payload =
      params
      |> Map.take([:stanza, :format, :routing])
      |> Map.put_new(:metadata, Map.get(params, :metadata, %{}))

    ServiceBridge.publish(bridge, :outbound_stanza, payload, opts)
  end

  @doc """
  Acknowledges delivery receipts coming from the worker.
  """
  @spec ack_receipt(bridge(), map(), keyword()) :: :ok | {:error, term()}
  def ack_receipt(bridge, params, opts \\ []) do
    payload = Map.take(params, [:stanza_id, :status])
    ServiceBridge.publish(bridge, :ack_receipt, payload, opts)
  end
end
