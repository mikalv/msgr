defmodule Messngr.Connectors.TelegramBridgeTest do
  use ExUnit.Case, async: true

  alias Msgr.Connectors.TelegramBridge
  alias Msgr.Support.QueueRecorder

  setup do
    {:ok, agent} = QueueRecorder.start_link([])
    bridge = TelegramBridge.new(queue: QueueRecorder, queue_opts: [agent: agent])

    %{bridge: bridge, agent: agent}
  end

  test "link_account/3 builds MTProto handshake request", %{bridge: bridge, agent: agent} do
    params = %{user_id: "u-1", phone_number: "+4712345678", session: %{dc: 2}, two_factor: :enabled}
    assert {:ok, %{status: :accepted}} = TelegramBridge.link_account(bridge, params, trace_id: "link")

    assert [request] = QueueRecorder.requests(agent)
    assert request.topic == "bridge/telegram/link_account"
    assert request.payload.payload == %{
             user_id: "u-1",
             phone_number: "+4712345678",
             session: %{dc: 2},
             two_factor: :enabled
           }
    assert request.payload.trace_id == "link"
  end

  test "send_message/3 publishes outbound envelope", %{bridge: bridge, agent: agent} do
    params = %{chat_id: 42, message: "hei", metadata: %{locale: "nb"}}
    assert :ok = TelegramBridge.send_message(bridge, params, trace_id: "out")

    assert [message] = QueueRecorder.published(agent)
    assert message.topic == "bridge/telegram/outbound_message"
    assert message.payload.payload == %{chat_id: 42, message: "hei", metadata: %{locale: "nb"}}
    assert message.payload.trace_id == "out"
  end

  test "send_message/3 can target a bridge instance", %{bridge: bridge, agent: agent} do
    params = %{chat_id: 42, message: "hei"}
    assert :ok = TelegramBridge.send_message(bridge, params, instance: :mtproto_norway)

    assert [message] = QueueRecorder.published(agent)
    assert message.topic == "bridge/telegram/mtproto_norway/outbound_message"
    assert message.payload.payload.metadata == %{}
  end

  test "ack_update/3 notifies the worker", %{bridge: bridge, agent: agent} do
    params = %{update_id: 1001, status: :processed}
    assert :ok = TelegramBridge.ack_update(bridge, params, trace_id: "ack")

    assert [ack] = QueueRecorder.published(agent)
    assert ack.topic == "bridge/telegram/ack_update"
    assert ack.payload.payload == %{update_id: 1001, status: :processed}
    assert ack.payload.trace_id == "ack"
  end
end
