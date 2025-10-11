# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Msgr.Connectors.Envelope do
  @moduledoc """
  Canonical StoneMQ envelope shared by bridge publishers and daemons.

  The envelope standardises metadata so queue subscribers across languages can
  parse and route messages deterministically.  It mirrors the helper types in
  the language-specific bridge SDKs under `bridge_sdks/`.
  """

  @type t :: %__MODULE__{
          schema: String.t(),
          service: String.t(),
          action: String.t(),
          trace_id: String.t(),
          payload: map(),
          metadata: map(),
          occurred_at: DateTime.t()
        }

  @schema "msgr.bridge.v1"

  @enforce_keys [:service, :action, :trace_id, :payload, :metadata, :occurred_at]
  defstruct [
    :service,
    :action,
    :trace_id,
    :payload,
    :metadata,
    :occurred_at,
    schema: @schema
  ]

  @spec new(atom() | String.t(), atom() | String.t(), map(), keyword()) ::
          {:ok, t()} | {:error, term()}
  def new(service, action, payload, opts \\ [])

  def new(service, action, payload, opts) when is_map(payload) do
    with {:ok, service} <- normalise_service(service),
         {:ok, action} <- normalise_action(action),
         {:ok, metadata} <- normalise_map(Keyword.get(opts, :metadata, %{}), :metadata),
         {:ok, trace_id} <- trace_id_from(opts),
         {:ok, occurred_at} <- occurred_at_from(opts) do
      envelope = %__MODULE__{
        schema: Keyword.get(opts, :schema, @schema),
        service: service,
        action: action,
        trace_id: trace_id,
        payload: payload,
        metadata: metadata,
        occurred_at: occurred_at
      }

      {:ok, envelope}
    end
  end

  def new(_service, _action, payload, _opts) do
    {:error, {:invalid_payload, payload}}
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = envelope) do
    %{
      schema: envelope.schema,
      service: envelope.service,
      action: envelope.action,
      trace_id: envelope.trace_id,
      occurred_at: DateTime.to_iso8601(envelope.occurred_at),
      metadata: envelope.metadata,
      payload: envelope.payload
    }
  end

  @spec from_map(map()) :: {:ok, t()} | {:error, term()}
  def from_map(map) when is_map(map) do
    normalised_map =
      map
      |> Enum.map(fn
        {key, value} when is_atom(key) -> {key, value}
        {key, value} when is_binary(key) -> {String.to_existing_atom(key) rescue key, value}
      end)
      |> Map.new()

    map_with_atom_keys =
      normalised_map
      |> Map.put_new(:schema, Map.get(normalised_map, "schema", @schema))
      |> Map.update(:service, Map.get(normalised_map, "service"), & &1)
      |> Map.update(:action, Map.get(normalised_map, "action"), & &1)
      |> Map.update(:trace_id, Map.get(normalised_map, "trace_id"), & &1)
      |> Map.update(:metadata, Map.get(normalised_map, "metadata", %{}), & &1)
      |> Map.update(:payload, Map.get(normalised_map, "payload", %{}), & &1)
      |> Map.update(:occurred_at, Map.get(normalised_map, "occurred_at"), & &1)

    with {:ok, occurred_at} <- occurred_at_from(Map.get(map_with_atom_keys, :occurred_at)) do
      new(
        Map.get(map_with_atom_keys, :service),
        Map.get(map_with_atom_keys, :action),
        Map.get(map_with_atom_keys, :payload),
        schema: Map.get(map_with_atom_keys, :schema, @schema),
        trace_id: Map.get(map_with_atom_keys, :trace_id),
        metadata: Map.get(map_with_atom_keys, :metadata, %{}),
        occurred_at: occurred_at
      )
    end
  end

  def from_map(other), do: {:error, {:invalid_envelope, other}}

  defp normalise_service(service) when is_atom(service), do: {:ok, Atom.to_string(service)}
  defp normalise_service(service) when is_binary(service) and service != "", do: {:ok, service}
  defp normalise_service(service), do: {:error, {:invalid_service, service}}

  defp normalise_action(action) when is_atom(action), do: {:ok, Atom.to_string(action)}
  defp normalise_action(action) when is_binary(action) and action != "", do: {:ok, action}
  defp normalise_action(action), do: {:error, {:invalid_action, action}}

  defp normalise_map(map, _field) when is_map(map), do: {:ok, map}
  defp normalise_map(value, field), do: {:error, {field, :not_a_map, value}}

  defp trace_id_from(opts) do
    case Keyword.get(opts, :trace_id) do
      nil -> {:ok, UUID.uuid4()}
      trace_id when is_binary(trace_id) and trace_id != "" -> {:ok, trace_id}
      trace_id -> {:error, {:invalid_trace_id, trace_id}}
    end
  end

  defp occurred_at_from(opts) when is_list(opts) do
    opts
    |> Keyword.get(:occurred_at)
    |> occurred_at_from()
  end

  defp occurred_at_from(nil), do: {:ok, DateTime.utc_now() |> DateTime.truncate(:millisecond)}

  defp occurred_at_from(%DateTime{} = datetime),
    do: {:ok, DateTime.truncate(datetime, :millisecond)}

  defp occurred_at_from(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, datetime, _offset} -> {:ok, DateTime.truncate(datetime, :millisecond)}
      _ -> {:error, {:invalid_occurred_at, timestamp}}
    end
  end

  defp occurred_at_from(other), do: {:error, {:invalid_occurred_at, other}}
end
