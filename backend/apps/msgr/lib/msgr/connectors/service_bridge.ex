# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Msgr.Connectors.ServiceBridge do
  @moduledoc """
  Helpers for emitting bridge queue messages for a given chat service.

  A `ServiceBridge` owns the queue adapter and service name, exposing helpers for
  publishing fire-and-forget commands and request/response control flows. The
  bridge normalises metadata (trace IDs, action names) to keep envelopes
  consistent across connectors.
  """

  @enforce_keys [:service, :queue]
  defstruct [:service, :queue, queue_opts: [], default_timeout: 5_000]

  @type t :: %__MODULE__{
          service: String.t(),
          queue: module(),
          queue_opts: keyword(),
          default_timeout: non_neg_integer()
        }

  @doc """
  Builds a bridge configuration for a specific service.
  """
  @spec new(atom() | String.t(), keyword()) :: t()
  def new(service, opts) do
    queue = Keyword.fetch!(opts, :queue)
    queue_opts = Keyword.get(opts, :queue_opts, [])
    default_timeout = Keyword.get(opts, :default_timeout, 5_000)

    %__MODULE__{
      service: normalise_service(service),
      queue: queue,
      queue_opts: queue_opts,
      default_timeout: default_timeout
    }
  end

  @doc """
  Publishes an asynchronous action for downstream bridge workers.
  """
  @spec publish(t(), atom(), map(), keyword()) :: :ok | {:error, term()}
  def publish(%__MODULE__{} = bridge, action, payload, opts \\ []) when is_atom(action) and is_map(payload) do
    message = build_message(bridge, action, payload, opts)
    queue_opts = Keyword.merge(bridge.queue_opts, Keyword.drop(opts, [:trace_id]))

    bridge.queue.publish(topic(bridge, action), message, queue_opts)
  end

  @doc """
  Sends a request expecting a response from the bridge worker (e.g. account linking).
  """
  @spec request(t(), atom(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def request(%__MODULE__{} = bridge, action, payload, opts \\ []) when is_atom(action) and is_map(payload) do
    message = build_message(bridge, action, payload, opts)

    queue_opts =
      bridge.queue_opts
      |> Keyword.merge(Keyword.drop(opts, [:trace_id]))
      |> Keyword.put_new(:timeout, bridge.default_timeout)

    bridge.queue.request(topic(bridge, action), message, queue_opts)
  end

  @doc """
  Computes the queue topic used for a given action.
  """
  @spec topic(t(), atom()) :: String.t()
  def topic(%__MODULE__{service: service}, action) when is_atom(action) do
    "bridge/#{service}/#{action}"
  end

  defp build_message(%__MODULE__{service: service}, action, payload, opts) do
    %{
      service: service,
      action: Atom.to_string(action),
      trace_id: Keyword.get_lazy(opts, :trace_id, &UUID.uuid4/0),
      payload: payload
    }
  end

  defp normalise_service(service) when is_atom(service), do: Atom.to_string(service)
  defp normalise_service(service) when is_binary(service), do: service
end
