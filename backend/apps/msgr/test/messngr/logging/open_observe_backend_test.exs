defmodule Messngr.Logging.OpenObserveBackendTest do
  use ExUnit.Case, async: true

  alias Messngr.Logging.OpenObserveBackend
  alias Msgr.Connectors.Envelope
  alias Jason

  @timestamp {{2024, 1, 1}, {0, 0, 0, 0}}

  defmodule CaptureQueue do
    def publish(topic, payload, opts) do
      test_pid = Keyword.fetch!(opts, :test_pid)
      send(test_pid, {:queue_publish, topic, payload, Keyword.delete(opts, :test_pid)})
      :ok
    end

    def request(_topic, _payload, _opts) do
      raise "not implemented"
    end
  end

  defp build_state(overrides \\ []) do
    defaults = [
      endpoint: "http://openobserve:5080",
      org: "default",
      stream: "backend",
      dataset: "_json",
      username: "user@example.com",
      password: "secret",
      metadata: [:module],
      http_client: fn method, request, http_opts, opts ->
        send(self(), {:http_request, method, request, http_opts, opts})
        {:ok, :ok}
      end
    ]

    {:ok, state} = OpenObserveBackend.init({OpenObserveBackend, Keyword.merge(defaults, overrides)})
    state
  end

  test "emits JSON payloads with metadata" do
    state = build_state()

    {:ok, _state} =
      OpenObserveBackend.handle_event(
        {:info, self(), {Logger, "hello", @timestamp, [module: __MODULE__]}},
        state
      )

    assert_receive {:http_request, :post, {url, headers, 'application/json', body}, [], []}

    assert to_string(url) ==
             "http://openobserve:5080/api/default/logs/backend/_json"

    assert {'authorization', 'Basic dXNlckBleGFtcGxlLmNvbTpzZWNyZXQ='} in headers

    [entry] = Jason.decode!(body)

    assert entry["message"] == "hello"
    assert entry["service"] == state.service
    assert entry["metadata"]["module"] =~ "OpenObserveBackendTest"
  end

  test "respects minimum level" do
    state = build_state(level: :error)

    {:ok, _state} =
      OpenObserveBackend.handle_event(
        {:info, self(), {Logger, "ignored", @timestamp, []}},
        state
      )

    refute_received {:http_request, _, _, _, _}
  end

  test "short circuits when disabled" do
    state = build_state(enabled: false)

    {:ok, _state} =
      OpenObserveBackend.handle_event(
        {:error, self(), {Logger, "disabled", @timestamp, []}},
        state
      )

    refute_received {:http_request, _, _, _, _}
  end

  test "publishes queue envelope when using StoneMQ transport" do
    state =
      build_state(
        transport: :stonemq,
        queue_module: CaptureQueue,
        queue_topic: "observability/logs",
        queue_opts: [test_pid: self()],
        endpoint: ""
      )

    {:ok, _state} =
      OpenObserveBackend.handle_event(
        {:error, self(), {Logger, "failure", @timestamp, [module: __MODULE__]}},
        state
      )

    assert_receive {:queue_publish, "observability/logs", payload, []}

    {:ok, envelope} = Envelope.from_map(payload)

    assert envelope.service == "observability"
    assert envelope.action == "log"
    assert envelope.metadata["destination"] == "openobserve"
    assert envelope.metadata["service"] == state.service

    entry = envelope.payload["entry"]
    assert entry["message"] == "failure"
    assert entry["level"] == "error"
    assert entry["metadata"]["module"] =~ "OpenObserveBackendTest"
  end
end
