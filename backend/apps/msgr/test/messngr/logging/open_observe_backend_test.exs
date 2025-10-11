defmodule Messngr.Logging.OpenObserveBackendTest do
  use ExUnit.Case, async: true

  alias Messngr.Logging.OpenObserveBackend
  alias Jason

  @timestamp {{2024, 1, 1}, {0, 0, 0, 0}}

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
end
