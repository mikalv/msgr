defmodule Messngr.Connectors.XMPPBridgeTest do
  use ExUnit.Case, async: true

  alias Msgr.Connectors.XMPPBridge
  alias Msgr.Support.QueueRecorder

  setup do
    {:ok, agent} = QueueRecorder.start_link([])
    bridge = XMPPBridge.new(queue: QueueRecorder, queue_opts: [agent: agent])

    %{bridge: bridge, agent: agent}
  end

  test "link_account/3 publishes credentials request", %{bridge: bridge, agent: agent} do
    params = %{user_id: "u-xmpp", jid: "msgr@example.com", password: "secret"}
    assert {:ok, %{status: :accepted}} = XMPPBridge.link_account(bridge, params, trace_id: "xmpp-link")

    assert [request] = QueueRecorder.requests(agent)
    assert request.topic == "bridge/xmpp/link_account"
    assert request.payload.payload == %{user_id: "u-xmpp", jid: "msgr@example.com", password: "secret"}
  end

  test "send_stanza/3 publishes outbound stanza", %{bridge: bridge, agent: agent} do
    params = %{stanza: "<message/>", format: :xml, routing: %{to: "user@example.com"}}
    assert :ok = XMPPBridge.send_stanza(bridge, params, trace_id: "stanza")

    assert [message] = QueueRecorder.published(agent)
    assert message.topic == "bridge/xmpp/outbound_stanza"
    assert message.payload.payload == %{stanza: "<message/>", format: :xml, routing: %{to: "user@example.com"}}
    assert message.payload.trace_id == "stanza"
  end

  test "send_stanza/3 supports routing to a specific instance", %{bridge: bridge, agent: agent} do
    params = %{stanza: "<message/>", format: :xml, routing: %{to: "user@example.com"}}
    assert :ok = XMPPBridge.send_stanza(bridge, params, instance: "xmpp-shard-1")

    assert [message] = QueueRecorder.published(agent)
    assert message.topic == "bridge/xmpp/xmpp-shard-1/outbound_stanza"
  end

  test "ack_receipt/3 publishes receipt acknowledgement", %{bridge: bridge, agent: agent} do
    params = %{stanza_id: "abc-123", status: :delivered}
    assert :ok = XMPPBridge.ack_receipt(bridge, params, trace_id: "receipt")

    assert [ack] = QueueRecorder.published(agent)
    assert ack.topic == "bridge/xmpp/ack_receipt"
    assert ack.payload.payload == %{stanza_id: "abc-123", status: :delivered}
  end
end
