defmodule Messngr.Connectors.ServiceBridgeTest do
  use ExUnit.Case, async: true

  alias Msgr.Connectors.ServiceBridge
  alias Msgr.Support.QueueRecorder

  setup do
    {:ok, agent} = QueueRecorder.start_link([])
    bridge = ServiceBridge.new(:example, queue: QueueRecorder, queue_opts: [agent: agent])

    %{bridge: bridge, agent: agent, agent_pid: agent}
  end

  test "topic/2 namespaces actions under the service", %{bridge: bridge} do
    assert ServiceBridge.topic(bridge, :send) == "bridge/example/send"
  end

  test "topic/2 includes instance namespace when configured", %{agent: agent} do
    bridge = ServiceBridge.new(:example, queue: QueueRecorder, queue_opts: [agent: agent], instance: "shard-a")

    assert ServiceBridge.topic(bridge, :send) == "bridge/example/shard-a/send"
    assert ServiceBridge.topic(bridge, "outbound", "shard-b") == "bridge/example/shard-b/outbound"
  end

  test "publish/4 forwards message envelopes to the queue", %{bridge: bridge, agent: agent} do
    assert :ok = ServiceBridge.publish(bridge, :send, %{body: "hi"}, trace_id: "trace")

    assert [message] = QueueRecorder.published(agent)
    assert message.topic == "bridge/example/send"
    assert message.payload.service == "example"
    assert message.payload.action == "send"
    assert message.payload.schema == "msgr.bridge.v1"
    assert message.payload.trace_id == "trace"
    assert {:ok, _datetime, 0} = DateTime.from_iso8601(message.payload.occurred_at)
    assert message.payload.payload == %{body: "hi"}
  end

  test "publish/4 allows routing to a specific instance", %{bridge: bridge, agent: agent} do
    assert :ok = ServiceBridge.publish(bridge, :send, %{body: "hi"}, instance: "matrix-west")

    assert [message] = QueueRecorder.published(agent)
    assert message.topic == "bridge/example/matrix-west/send"
  end

  test "request/4 delegates to the queue with default timeout", %{bridge: bridge, agent: agent} do
    assert {:ok, %{status: :accepted}} = ServiceBridge.request(bridge, :link, %{}, trace_id: "link")

    assert [request] = QueueRecorder.requests(agent)
    assert request.opts[:timeout] == 5_000
    assert request.payload.trace_id == "link"
    assert request.payload.metadata == %{}
  end

  test "request/4 allows overriding timeout", %{bridge: bridge, agent: agent} do
    assert {:ok, %{status: :accepted}} =
             ServiceBridge.request(bridge, :link, %{}, timeout: 1_000, trace_id: "override")

    assert [request] = QueueRecorder.requests(agent)
    assert request.opts[:timeout] == 1_000
    assert request.payload.trace_id == "override"
  end

  test "request/4 propagates instance routing", %{bridge: bridge, agent: agent} do
    assert {:ok, %{status: :accepted}} =
             ServiceBridge.request(bridge, :link, %{}, instance: :matrix_east, trace_id: "instance")

    assert [request] = QueueRecorder.requests(agent)
    assert request.topic == "bridge/example/matrix_east/link"
  end

  test "publish/4 returns error when envelope cannot be built", %{bridge: bridge} do
    assert {:error, {:metadata, :not_a_map, _}} =
             ServiceBridge.publish(bridge, :send, %{}, metadata: [:invalid])
  end

  test "publish/4 rejects invalid instance override", %{bridge: bridge} do
    assert {:error, {:invalid_instance, ""}} = ServiceBridge.publish(bridge, :send, %{body: "hi"}, instance: "")
  end
end
