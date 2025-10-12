defmodule Messngr.Connectors.MatrixBridgeTest do
  use ExUnit.Case, async: true

  alias Msgr.Connectors.MatrixBridge
  alias Msgr.Support.QueueRecorder

  setup do
    {:ok, agent} = QueueRecorder.start_link([])
    bridge = MatrixBridge.new(queue: QueueRecorder, queue_opts: [agent: agent])

    %{bridge: bridge, agent: agent}
  end

  test "link_account/3 forwards login envelope", %{bridge: bridge, agent: agent} do
    params = %{user_id: "u-1", homeserver: "https://example", login: %{type: :password}}
    assert {:ok, %{status: :accepted}} = MatrixBridge.link_account(bridge, params, trace_id: "matrix-link")

    assert [request] = QueueRecorder.requests(agent)
    assert request.topic == "bridge/matrix/link_account"
    assert request.payload.payload == %{user_id: "u-1", homeserver: "https://example", login: %{type: :password}}
  end

  test "send_event/3 publishes outbound Matrix event", %{bridge: bridge, agent: agent} do
    params = %{room_id: "!room:server", event_type: "m.room.message", content: %{body: "Hello"}}
    assert :ok = MatrixBridge.send_event(bridge, params, trace_id: "event")

    assert [message] = QueueRecorder.published(agent)
    assert message.topic == "bridge/matrix/outbound_event"
    assert message.payload.payload == %{
             room_id: "!room:server",
             event_type: "m.room.message",
             content: %{body: "Hello"},
             metadata: %{}
           }
    assert message.payload.trace_id == "event"
  end

  test "send_event/3 supports routing to a specific instance", %{bridge: bridge, agent: agent} do
    params = %{room_id: "!room:server", event_type: "m.room.message", content: %{body: "Hello"}}
    assert :ok = MatrixBridge.send_event(bridge, params, instance: "matrix-eu-1")

    assert [message] = QueueRecorder.published(agent)
    assert message.topic == "bridge/matrix/matrix-eu-1/outbound_event"
  end

  test "ack_sync/3 publishes sync acknowledgement", %{bridge: bridge, agent: agent} do
    params = %{next_batch: "s72595_4483_1934", stream_position: 10}
    assert :ok = MatrixBridge.ack_sync(bridge, params, trace_id: "sync")

    assert [ack] = QueueRecorder.published(agent)
    assert ack.topic == "bridge/matrix/ack_sync"
    assert ack.payload.payload == %{next_batch: "s72595_4483_1934", stream_position: 10}
  end
end
