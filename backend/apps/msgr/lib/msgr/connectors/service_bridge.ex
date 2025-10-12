# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Msgr.Connectors.ServiceBridge do
  @moduledoc """
  Helpers for emitting bridge queue messages for a given chat service.

  A `ServiceBridge` owns the queue adapter and service name, exposing helpers for
  publishing fire-and-forget commands and request/response control flows. The
  bridge normalises metadata (trace IDs, action names) to keep envelopes
  consistent across connectors.
  """

  alias Msgr.Connectors.Envelope

  @enforce_keys [:service, :queue]
  defstruct [:service, :queue, queue_opts: [], default_timeout: 5_000, instance: nil]

  @type t :: %__MODULE__{
          service: String.t(),
          queue: module(),
          queue_opts: keyword(),
          default_timeout: non_neg_integer(),
          instance: String.t() | nil
        }

  @doc """
  Builds a bridge configuration for a specific service.
  """
  @spec new(atom() | String.t(), keyword()) :: t()
  def new(service, opts) do
    queue = Keyword.fetch!(opts, :queue)
    queue_opts = Keyword.get(opts, :queue_opts, [])
    default_timeout = Keyword.get(opts, :default_timeout, 5_000)
    instance = normalise_instance!(Keyword.get(opts, :instance))

    %__MODULE__{
      service: normalise_service(service),
      queue: queue,
      queue_opts: queue_opts,
      default_timeout: default_timeout,
      instance: instance
    }
  end

  @doc """
  Publishes an asynchronous action for downstream bridge workers.
  """
  @spec publish(t(), atom(), map(), keyword()) :: :ok | {:error, term()}
  def publish(%__MODULE__{} = bridge, action, payload, opts \\ []) when is_atom(action) and is_map(payload) do
    with {:ok, envelope} <- build_envelope(bridge, action, payload, opts),
         {:ok, instance} <- resolve_instance(bridge, opts) do
      queue_opts =
        bridge.queue_opts
        |> Keyword.merge(Keyword.drop(opts, [:trace_id, :metadata, :occurred_at, :schema, :instance]))

      bridge.queue.publish(topic(bridge, action, instance), Envelope.to_map(envelope), queue_opts)
    end
  end

  @doc """
  Sends a request expecting a response from the bridge worker (e.g. account linking).
  """
  @spec request(t(), atom(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def request(%__MODULE__{} = bridge, action, payload, opts \\ []) when is_atom(action) and is_map(payload) do
    with {:ok, envelope} <- build_envelope(bridge, action, payload, opts),
         {:ok, instance} <- resolve_instance(bridge, opts) do
      queue_opts =
        bridge.queue_opts
        |> Keyword.merge(Keyword.drop(opts, [:trace_id, :metadata, :occurred_at, :schema, :instance]))
        |> Keyword.put_new(:timeout, bridge.default_timeout)

      bridge.queue.request(topic(bridge, action, instance), Envelope.to_map(envelope), queue_opts)
    end
  end

  @doc """
  Computes the queue topic used for a given action.
  """
  @spec topic(t(), atom()) :: String.t()
  def topic(%__MODULE__{} = bridge, action) when is_atom(action) or is_binary(action) do
    topic(bridge, action, bridge.instance)
  end

  @spec topic(t(), atom() | String.t(), String.t() | nil) :: String.t()
  def topic(%__MODULE__{service: service}, action, instance)
      when (is_atom(action) or is_binary(action)) and (is_binary(instance) or is_nil(instance)) do
    action = normalise_action!(action)

    case instance do
      nil -> "bridge/#{service}/#{action}"
      _ -> "bridge/#{service}/#{instance}/#{action}"
    end
  end

  defp build_envelope(%__MODULE__{service: service}, action, payload, opts) do
    Envelope.new(service, action, payload, opts)
  end

  defp resolve_instance(%__MODULE__{} = bridge, opts) do
    opts
    |> Keyword.get(:instance, bridge.instance)
    |> normalise_instance()
  end

  defp normalise_service(service) when is_atom(service), do: Atom.to_string(service)
  defp normalise_service(service) when is_binary(service), do: service

  defp normalise_action!(action) when is_atom(action), do: Atom.to_string(action)
  defp normalise_action!(action) when is_binary(action), do: action

  defp normalise_instance!(value) do
    case normalise_instance(value) do
      {:ok, instance} -> instance
      {:error, reason} -> raise ArgumentError, "invalid instance: #{inspect(reason)}"
    end
  end

  defp normalise_instance(nil), do: {:ok, nil}

  defp normalise_instance(instance) when is_atom(instance) do
    normalise_instance(Atom.to_string(instance))
  end

  defp normalise_instance(instance) when is_binary(instance) do
    trimmed = String.trim(instance)

    cond do
      trimmed == "" -> {:error, {:invalid_instance, instance}}
      String.contains?(trimmed, "/") -> {:error, {:invalid_instance, instance}}
      true -> {:ok, trimmed}
    end
  end

  defp normalise_instance(other), do: {:error, {:invalid_instance, other}}
end
