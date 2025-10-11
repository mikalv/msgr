# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Msgr.Connectors.Queue do
  @moduledoc """
  Behaviour for queue adapters used to communicate with bridge services.

  Connectors push outbound actions to language-specific bridge daemons and
  retrieve responses for control flows such as account linking. The queue layer
  encapsulates the transport (StoneMQ, NATS, etc.) so we can swap
  implementations without rewriting connector logic.
  """

  @type topic :: String.t()
  @type payload :: map()
  @type opts :: keyword()

  @callback publish(topic(), payload(), opts()) :: :ok | {:error, term()}
  @callback request(topic(), payload(), opts()) :: {:ok, map()} | {:error, term()}
end
