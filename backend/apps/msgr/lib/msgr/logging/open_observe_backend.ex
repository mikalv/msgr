defmodule Messngr.Logging.OpenObserveBackend do
  @moduledoc """
  Logger backend that forwards structured log entries to OpenObserve.

  The backend posts each log record as a JSON payload to the configured
  ingestion endpoint or forwards the payload to StoneMQ so a downstream
  consumer can ingest it. Configuration lives under
  `config :logger, Messngr.Logging.OpenObserveBackend` and can be overridden with
  environment variables in `dev.exs`.
  """

  @behaviour :gen_event

  require Logger

  alias Msgr.Connectors.Envelope

  defstruct [
    :auth_header,
    :enabled,
    :envelope_action,
    :envelope_service,
    :http_client,
    :level,
    :metadata_keys,
    :queue,
    :queue_opts,
    :queue_topic,
    :service,
    :stream,
    :transport,
    :url
  ]

  @impl true
  def init({__MODULE__, opts}) do
    state =
      opts
      |> load_options()
      |> build_state()

    if state.enabled and state.transport == :http do
      ensure_clients_started()
    end

    {:ok, state}
  end

  def init(opts) when is_list(opts) do
    init({__MODULE__, opts})
  end

  @impl true
  def handle_event(:flush, state), do: {:ok, state}

  def handle_event({_level, _gl, {Logger, _msg, _ts, _md}}, %{enabled: false} = state) do
    {:ok, state}
  end

  def handle_event({level, _gl, {Logger, message, timestamp, metadata}}, state) do
    if Logger.compare_levels(level, state.level) != :lt do
      entry =
        build_entry(level, message, timestamp, metadata, state.metadata_keys, state.service)

      send_payload(state, entry)
    end

    {:ok, state}
  end

  def handle_event(_event, state), do: {:ok, state}

  @impl true
  def handle_call(_request, state), do: {:ok, :ok, state}

  @impl true
  def handle_info(_msg, state), do: {:ok, state}

  @impl true
  def code_change(_old, state, _extra), do: {:ok, state}

  @impl true
  def terminate(_reason, _state), do: :ok

  defp build_state(opts) do
    opts_map = Enum.into(opts, %{})

    endpoint = opts_map |> Map.get(:endpoint, "") |> String.trim_trailing("/")
    org = Map.get(opts_map, :org, "default") |> String.trim("/")
    stream = Map.get(opts_map, :stream, "backend") |> String.trim("/")
    dataset = Map.get(opts_map, :dataset, "_json") |> to_string() |> String.trim("/")
    username = Map.get(opts_map, :username)
    password = Map.get(opts_map, :password)
    enabled? = Map.get(opts_map, :enabled, true)
    transport = Map.get(opts_map, :transport, :http)
    queue_module = Map.get(opts_map, :queue_module)
    queue_opts = Map.get(opts_map, :queue_opts, [])
    queue_topic = Map.get(opts_map, :queue_topic, "observability/logs")
    envelope_service = Map.get(opts_map, :envelope_service, "observability")
    envelope_action = Map.get(opts_map, :envelope_action, "log")

    enabled? =
      enabled? &&
        case transport do
          :stonemq -> not is_nil(queue_module)
          _ -> endpoint != ""
        end

    %__MODULE__{
      enabled: enabled?,
      url: build_url(endpoint, org, stream, dataset),
      metadata_keys: Map.get(opts_map, :metadata, []),
      level: Map.get(opts_map, :level, :info),
      service: Map.get(opts_map, :service, "msgr_backend"),
      stream: stream,
      auth_header: build_auth(username, password),
      http_client: Map.get(opts_map, :http_client, &default_request/4),
      transport: transport,
      queue: queue_module,
      queue_opts: queue_opts,
      queue_topic: queue_topic,
      envelope_service: envelope_service,
      envelope_action: envelope_action
    }
  end

  defp load_options(name) when is_atom(name) do
    base_config = Application.get_env(:messngr_logging, __MODULE__, [])
    logger_base = Application.get_env(:logger, __MODULE__, [])

    global_opts =
      base_config
      |> Keyword.get(:default, [])
      |> Keyword.merge(logger_base)

    handler_opts =
      base_config
      |> Keyword.get(name, [])
      |> Keyword.merge(logger_handler_opts(name))

    Keyword.merge(global_opts, handler_opts)
  end

  defp load_options(opts) when is_list(opts) do
    base_config = Application.get_env(:messngr_logging, __MODULE__, [])
    logger_base = Application.get_env(:logger, __MODULE__, [])

    global_opts =
      base_config
      |> Keyword.get(:default, [])
      |> Keyword.merge(logger_base)

    Keyword.merge(global_opts, opts)
  end

  defp logger_handler_opts(name) do
    :logger
    |> Application.get_all_env()
    |> Enum.find_value([], fn
      {{__MODULE__, ^name}, opts} -> opts
      _ -> nil
    end)
  end

  defp ensure_clients_started do
    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)
  end

  defp build_url("", _org, _stream, _dataset), do: ""

  defp build_url(endpoint, org, stream, dataset) do
    [endpoint, "api", org, "logs", stream, dataset]
    |> Enum.map(&String.trim(&1, "/"))
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("/")
  end

  defp build_auth(nil, _), do: nil
  defp build_auth(_, nil), do: nil

  defp build_auth(username, password) do
    credentials = Base.encode64("#{username}:#{password}")
    "Basic #{credentials}"
  end

  defp build_entry(level, message, timestamp, metadata, metadata_keys, service) do
    metadata_map =
      metadata
      |> Enum.into(%{})
      |> Map.take(metadata_keys)
      |> Enum.into(%{}, fn {key, value} ->
        {to_string(key), inspect_metadata(value)}
      end)

    %{
      "level" => Atom.to_string(level),
      "message" => normalize_message(message),
      "service" => service,
      "timestamp" => format_timestamp(timestamp)
    }
    |> maybe_put_metadata(metadata_map)
  end

  defp normalize_message(message) when is_binary(message), do: message
  defp normalize_message(message) when is_list(message), do: IO.iodata_to_binary(message)
  defp normalize_message(message), do: inspect(message)

  defp inspect_metadata(%{__struct__: _} = value), do: inspect(value)

  defp inspect_metadata(value) when is_pid(value) or is_reference(value) or is_function(value) or is_port(value),
    do: inspect(value)

  defp inspect_metadata(value) when is_tuple(value) or is_map(value) or is_list(value),
    do: inspect(value)

  defp inspect_metadata(value) when is_integer(value) or is_float(value) or is_boolean(value),
    do: value

  defp inspect_metadata(value) when is_binary(value), do: value

  defp inspect_metadata(value), do: inspect(value)

  defp format_timestamp({{year, month, day}, {hour, minute, second, micro}}) do
    NaiveDateTime.new!(year, month, day, hour, minute, second, micro)
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_iso8601()
  end

  defp send_payload(%{transport: :http, enabled: true} = state, entry) do
    payload = Jason.encode!([entry])

    headers =
      [{~c"content-type", ~c"application/json"}]
      |> maybe_add_auth(state.auth_header)

    request = {String.to_charlist(state.url), headers, ~c"application/json", payload}

    case state.http_client.(:post, request, [], []) do
      {:ok, _response} -> :ok
      {:error, reason} ->
        IO.warn("Failed to deliver log entry to OpenObserve: #{inspect(reason)}")
        :error
    end
  end

  defp send_payload(%{transport: :stonemq} = state, entry) do
    publish_queue(state, entry)
  end

  defp send_payload(_state, _entry), do: :ok

  defp maybe_add_auth(headers, nil), do: headers

  defp maybe_add_auth(headers, auth) do
    [{~c"authorization", String.to_charlist(auth)} | headers]
  end

  defp maybe_put_metadata(entry, metadata) when metadata == %{}, do: entry
  defp maybe_put_metadata(entry, metadata), do: Map.put(entry, "metadata", metadata)

  defp default_request(method, request, headers, options) do
    :httpc.request(method, request, headers, options)
  end

  defp publish_queue(%{enabled: true, queue: queue} = state, entry) when not is_nil(queue) do
    metadata = %{
      "destination" => "openobserve",
      "stream" => state.stream,
      "service" => state.service
    }

    payload = %{"entry" => entry}

    case Envelope.new(state.envelope_service, state.envelope_action, payload, metadata: metadata) do
      {:ok, envelope} ->
        queue.publish(state.queue_topic, Envelope.to_map(envelope), state.queue_opts)

      {:error, reason} ->
        IO.warn("Failed to deliver log entry to OpenObserve via StoneMQ: #{inspect(reason)}")
        :error
    end
  end

  defp publish_queue(_state, _entry), do: :ok
end
