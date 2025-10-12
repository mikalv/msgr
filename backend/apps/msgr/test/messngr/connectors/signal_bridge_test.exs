defmodule Messngr.Connectors.SignalBridgeTest do
  use ExUnit.Case, async: true

  alias Msgr.Connectors.SignalBridge
  alias Msgr.Support.QueueRecorder

  setup do
    {:ok, agent} = QueueRecorder.start_link([])
    bridge = SignalBridge.new(queue: QueueRecorder, queue_opts: [agent: agent])

    %{bridge: bridge, agent: agent}
  end

  test "link_account/3 forwards device-link payload", %{bridge: bridge, agent: agent} do
    params = %{user_id: "u-1", session: %{blob: "abc"}, linking: %{device_name: "Msgr"}}
    assert {:ok, %{status: :accepted}} = SignalBridge.link_account(bridge, params, trace_id: "link")

    assert [request] = QueueRecorder.requests(agent)
    assert request.topic == "bridge/signal/link_account"
    assert request.payload.payload == %{user_id: "u-1", session: %{blob: "abc"}, linking: %{device_name: "Msgr"}}
    assert request.payload.trace_id == "link"
  end

  test "send_message/3 publishes outbound envelope", %{bridge: bridge, agent: agent} do
    params = %{chat_id: "uuid-123", message: "hei", attachments: [%{id: "file"}], metadata: %{sealed_sender: true}}
    assert :ok = SignalBridge.send_message(bridge, params, trace_id: "msg")

    assert [message] = QueueRecorder.published(agent)
    assert message.topic == "bridge/signal/outbound_message"
    assert message.payload.payload == %{
             chat_id: "uuid-123",
             message: "hei",
             attachments: [%{id: "file"}],
             metadata: %{sealed_sender: true}
           }
    assert message.payload.trace_id == "msg"
  end

  test "send_message/3 defaults optional payloads", %{bridge: bridge, agent: agent} do
    params = %{chat_id: "uuid-456", message: "hei"}
    assert :ok = SignalBridge.send_message(bridge, params, instance: :signal_eu)

    assert [message] = QueueRecorder.published(agent)
    assert message.topic == "bridge/signal/signal_eu/outbound_message"
    assert message.payload.payload.attachments == []
    assert message.payload.payload.metadata == %{}
  end

  test "ack_event/3 notifies daemon", %{bridge: bridge, agent: agent} do
    params = %{event_id: "evt-1", status: :processed}
    assert :ok = SignalBridge.ack_event(bridge, params, trace_id: "ack")

    assert [ack] = QueueRecorder.published(agent)
    assert ack.topic == "bridge/signal/ack_event"
    assert ack.payload.payload == %{event_id: "evt-1", status: :processed}
    assert ack.payload.trace_id == "ack"
  end
end
