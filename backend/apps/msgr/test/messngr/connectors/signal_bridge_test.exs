defmodule Messngr.Connectors.SignalBridgeTest do
  use Messngr.DataCase, async: true

  alias Msgr.Connectors.SignalBridge
  alias Msgr.Support.QueueRecorder
  alias Messngr.Accounts.Account
  alias Messngr.Bridges

  setup do
    {:ok, agent} = QueueRecorder.start_link([])

    account =
      %Account{}
      |> Account.changeset(%{display_name: "Signal User"})
      |> Messngr.Repo.insert!()

    %{agent: agent, account: account}
  end

  test "link_account/3 forwards device-link payload", %{agent: agent} do
    bridge = SignalBridge.new(queue: QueueRecorder, queue_opts: [agent: agent])
    params = %{user_id: "u-1", session: %{blob: "abc"}, linking: %{device_name: "Msgr"}}
    assert {:ok, %{status: :accepted}} = SignalBridge.link_account(bridge, params, trace_id: "link")

    assert [request] = QueueRecorder.requests(agent)
    assert request.topic == "bridge/signal/link_account"
    assert request.payload.payload == %{user_id: "u-1", session: %{blob: "abc"}, linking: %{device_name: "Msgr"}}
    assert request.payload.trace_id == "link"
  end

  test "send_message/3 publishes outbound envelope", %{agent: agent} do
    bridge = SignalBridge.new(queue: QueueRecorder, queue_opts: [agent: agent])
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

  test "send_message/3 defaults optional payloads", %{agent: agent} do
    bridge = SignalBridge.new(queue: QueueRecorder, queue_opts: [agent: agent])
    params = %{chat_id: "uuid-456", message: "hei"}
    assert :ok = SignalBridge.send_message(bridge, params, instance: :signal_eu)

    assert [message] = QueueRecorder.published(agent)
    assert message.topic == "bridge/signal/signal_eu/outbound_message"
    assert message.payload.payload.attachments == []
    assert message.payload.payload.metadata == %{}
  end

  test "ack_event/3 notifies daemon", %{agent: agent} do
    bridge = SignalBridge.new(queue: QueueRecorder, queue_opts: [agent: agent])
    params = %{event_id: "evt-1", status: :processed}
    assert :ok = SignalBridge.ack_event(bridge, params, trace_id: "ack")

    assert [ack] = QueueRecorder.published(agent)
    assert ack.topic == "bridge/signal/ack_event"
    assert ack.payload.payload == %{event_id: "evt-1", status: :processed}
    assert ack.payload.trace_id == "ack"
  end

  test "link_account/3 stores signal capabilities and contacts", %{agent: agent, account: account} do
    response = %{
      "status" => "linked",
      "user" => %{"uuid" => "uuid-123", "display_name" => "Alice", "phone_number" => "+47"},
      "session" => %{"token" => "abc"},
      "capabilities" => %{"messaging" => %{"attachments" => ["image", "video"], "text" => true}},
      "contacts" => [
        %{ "uuid" => "uuid-200", "name" => "Bob" }
      ],
      "conversations" => [
        %{ "id" => "chat-1", "type" => "group", "title" => "Friends" }
      ]
    }

    bridge =
      SignalBridge.new(
        queue: QueueRecorder,
        queue_opts: [agent: agent, responder: fn -> {:ok, response} end]
      )

    params = %{user_id: account.id, session: %{}}

    assert {:ok, ^response} = SignalBridge.link_account(bridge, params)

    bridge_account = Bridges.get_account(account.id, "signal")
    refute bridge_account == nil
    assert bridge_account.capabilities["messaging"]["attachments"] == ["image", "video"]

    [contact] = bridge_account.contacts
    assert contact.external_id == "uuid-200"
    assert contact.display_name == "Bob"

    [conversation] = bridge_account.channels
    assert conversation.external_id == "chat-1"
    assert conversation.kind == "group"
  end
end
