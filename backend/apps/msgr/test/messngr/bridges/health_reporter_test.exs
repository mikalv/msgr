defmodule Messngr.Bridges.HealthReporterTest do
  use ExUnit.Case, async: false

  alias Msgr.Connectors.SlackBridge
  alias Msgr.Support.QueueRecorder
  alias Messngr.Bridges.HealthReporter

  setup do
    {:ok, agent} = QueueRecorder.start_link([])
    %{agent: agent}
  end

  test "emits telemetry for configured bridges", %{agent: agent} do
    snapshot = %{
      "status" => "ok",
      "summary" => %{
        "total_clients" => 1,
        "connected_clients" => 1,
        "pending_events" => 2,
        "acked_events" => 1
      },
      "clients" => [
        %{
          "user_id" => "acct-1",
          "instance" => "T123",
          "pending_events" => 2,
          "connected" => true
        }
      ]
    }

    responder = fn -> {:ok, snapshot} end

    {:ok, pid} =
      HealthReporter.start_link(
        interval: 10,
        bridges: [
          %{
            name: :slack,
            connector: SlackBridge,
            connector_opts: [queue: QueueRecorder, queue_opts: [agent: agent, responder: responder]],
            metadata: %{env: :test}
          }
        ]
      )

    handler_id = "health-reporter-test-#{System.unique_integer([:positive])}"
    events = [[:messngr, :bridges, :slack, :health], [:messngr, :bridges, :slack, :client_health]]
    parent = self()

    :telemetry.attach_many(handler_id, events, fn event, measurements, metadata, _config ->
      send(parent, {:telemetry_event, event, measurements, metadata})
    end, %{})
    on_exit(fn -> :telemetry.detach(handler_id) end)

    assert_receive {:telemetry_event, [:messngr, :bridges, :slack, :health], measurements, metadata}, 200
    assert measurements.total_clients == 1
    assert measurements.connected_clients == 1
    assert measurements.pending_events == 2
    assert metadata.bridge == :slack
    assert metadata.env == :test

    assert_receive {:telemetry_event, [:messngr, :bridges, :slack, :client_health], client_measurements, client_meta}, 50
    assert client_measurements.pending_events == 2
    assert client_measurements.connected == 1
    assert client_meta.instance == "T123"
    assert client_meta.user_id == "acct-1"

    assert [request] = QueueRecorder.requests(agent)
    assert request.topic == "bridge/slack/health_snapshot"

    GenServer.stop(pid)
  end
end
