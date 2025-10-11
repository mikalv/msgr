defmodule Messngr.Logging.OpenObserveBackend do
  @moduledoc """
  Logger backend that forwards structured log entries to OpenObserve.

  The backend posts each log record as a JSON payload to the configured
  ingestion endpoint. Configuration lives under
  `config :logger, Messngr.Logging.OpenObserveBackend` and can be overridden with
  environment variables in `dev.exs`.
  """

  @behaviour :gen_event

  require Logger

  defstruct [
    :auth_header,
    :enabled,
    :http_client,
    :level,
    :metadata_keys,
    :service,
    :url
  ]

  @impl true
  def init({__MODULE__, opts}) do
    state =
      opts
      |> load_options()
      |> build_state()

    if state.enabled do
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
      payload =
        build_payload(level, message, timestamp, metadata, state.metadata_keys, state.service)

      send_payload(state, payload)
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

    endpoint =
      opts_map
      |> Map.fetch!(:endpoint)
      |> String.trim_trailing("/")

    org = Map.get(opts_map, :org, "default") |> String.trim("/")
    stream = Map.get(opts_map, :stream, "backend") |> String.trim("/")
    dataset = Map.get(opts_map, :dataset, "_json") |> to_string() |> String.trim("/")
    username = Map.get(opts_map, :username)
    password = Map.get(opts_map, :password)
    enabled? = Map.get(opts_map, :enabled, true)

    %__MODULE__{
      enabled: enabled? && endpoint != "",
      url: build_url(endpoint, org, stream, dataset),
      metadata_keys: Map.get(opts_map, :metadata, []),
      level: Map.get(opts_map, :level, :info),
      service: Map.get(opts_map, :service, "msgr_backend"),
      auth_header: build_auth(username, password),
      http_client: Map.get(opts_map, :http_client, &default_request/4)
    }
  end

  defp load_options(name) when is_atom(name) do
    base = Application.get_env(:logger, __MODULE__, [])
    overrides = Application.get_env(:logger, {__MODULE__, name}, [])
    Keyword.merge(base, overrides)
  end

  defp load_options(opts) when is_list(opts) do
    base = Application.get_env(:logger, __MODULE__, [])
    Keyword.merge(base, opts)
  end

  defp ensure_clients_started do
    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)
  end

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

  defp build_payload(level, message, timestamp, metadata, metadata_keys, service) do
    metadata_map =
      metadata
      |> Enum.into(%{})
      |> Map.take(metadata_keys)
      |> Enum.into(%{}, fn {key, value} ->
        {to_string(key), inspect_metadata(value)}
      end)

    entry =
      %{
        "level" => Atom.to_string(level),
        "message" => normalize_message(message),
        "service" => service,
        "timestamp" => format_timestamp(timestamp)
      }
      |> maybe_put_metadata(metadata_map)

    Jason.encode!([entry])
  end

  defp normalize_message(message) when is_binary(message), do: message
  defp normalize_message(message) when is_list(message), do: IO.iodata_to_binary(message)
  defp normalize_message(message), do: inspect(message)

  defp inspect_metadata(%{__struct__: _} = value), do: inspect(value)
  defp inspect_metadata(value) when is_tuple(value) or is_map(value) or is_list(value),
    do: inspect(value)

  defp inspect_metadata(value), do: value

  defp format_timestamp({{year, month, day}, {hour, minute, second, micro}}) do
    NaiveDateTime.new!(year, month, day, hour, minute, second, micro)
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_iso8601()
  end

  defp send_payload(%{http_client: client, url: url, auth_header: auth, enabled: true}, payload) do
    headers =
      [{'content-type', 'application/json'}]
      |> maybe_add_auth(auth)

    request = {String.to_charlist(url), headers, 'application/json', payload}

    case client.(:post, request, [], []) do
      {:ok, _response} -> :ok
      {:error, reason} ->
        IO.warn("Failed to deliver log entry to OpenObserve: #{inspect(reason)}")
        :error
    end
  end

  defp send_payload(_state, _payload), do: :ok

  defp maybe_add_auth(headers, nil), do: headers

  defp maybe_add_auth(headers, auth) do
    [{'authorization', String.to_charlist(auth)} | headers]
  end

  defp maybe_put_metadata(entry, metadata) when metadata == %{}, do: entry
  defp maybe_put_metadata(entry, metadata), do: Map.put(entry, "metadata", metadata)

  defp default_request(method, request, headers, options) do
    :httpc.request(method, request, headers, options)
  end
