# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Msgr.Connectors.TelegramBridge do
  @moduledoc """
  Connector facade for Telegram bridge daemons.

  The Elixir side only understands how to describe intents. The actual network
  traffic flows through a separate worker (Go, Python, etc.) that speaks the
  proprietary MTProto stack and reports back via the message queue.
  """

  alias Msgr.Connectors.ServiceBridge

  @type bridge :: ServiceBridge.t()

  @spec new(keyword()) :: bridge()
  def new(opts), do: ServiceBridge.new(:telegram, opts)

  @doc """
  Initiates the out-of-band linking ceremony for a Telegram account.

  The payload delegates MTProto negotiations to the bridge worker which can be
  implemented in whichever language is most convenient.
  """
  @spec link_account(bridge(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def link_account(bridge, params, opts \\ []) do
    payload = Map.take(params, [:user_id, :phone_number, :session, :two_factor])
    ServiceBridge.request(bridge, :link_account, payload, opts)
  end

  @doc """
  Emits an outbound message intent for Telegram chats.
  """
  @spec send_message(bridge(), map(), keyword()) :: :ok | {:error, term()}
  def send_message(bridge, params, opts \\ []) do
    payload =
      params
      |> Map.take([:chat_id, :message, :entities, :reply_to, :media])
      |> Map.put_new(:metadata, Map.get(params, :metadata, %{}))

    ServiceBridge.publish(bridge, :outbound_message, payload, opts)
  end

  @doc """
  Acknowledges updates once the Elixir core has persisted them.
  """
  @spec ack_update(bridge(), map(), keyword()) :: :ok | {:error, term()}
  def ack_update(bridge, params, opts \\ []) do
    payload = Map.take(params, [:update_id, :status, :received_at])
    ServiceBridge.publish(bridge, :ack_update, payload, opts)
  end
end
