defmodule Messngr.Connectors.ServiceBridgeTest do
  use ExUnit.Case, async: true

  alias Msgr.Connectors.ServiceBridge
  alias Msgr.Support.QueueRecorder

  setup do
    {:ok, agent} = QueueRecorder.start_link([])
    bridge = ServiceBridge.new(:example, queue: QueueRecorder, queue_opts: [agent: agent])

    %{bridge: bridge, agent: agent}
  end

  test "topic/2 namespaces actions under the service", %{bridge: bridge} do
    assert ServiceBridge.topic(bridge, :send) == "bridge/example/send"
  end

  test "publish/4 forwards message envelopes to the queue", %{bridge: bridge, agent: agent} do
    assert :ok = ServiceBridge.publish(bridge, :send, %{body: "hi"}, trace_id: "trace")

    assert [message] = QueueRecorder.published(agent)
    assert message.topic == "bridge/example/send"
    assert message.payload == %{service: "example", action: "send", trace_id: "trace", payload: %{body: "hi"}}
  end

  test "request/4 delegates to the queue with default timeout", %{bridge: bridge, agent: agent} do
    assert {:ok, %{status: :accepted}} = ServiceBridge.request(bridge, :link, %{}, trace_id: "link")

    assert [request] = QueueRecorder.requests(agent)
    assert request.opts[:timeout] == 5_000
    assert request.payload.trace_id == "link"
  end

  test "request/4 allows overriding timeout", %{bridge: bridge, agent: agent} do
    assert {:ok, %{status: :accepted}} =
             ServiceBridge.request(bridge, :link, %{}, timeout: 1_000, trace_id: "override")

    assert [request] = QueueRecorder.requests(agent)
    assert request.opts[:timeout] == 1_000
    assert request.payload.trace_id == "override"
  end
end
