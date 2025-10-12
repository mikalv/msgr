defmodule Messngr.Connectors.TelegramBridgeTest do
  use Messngr.DataCase, async: true

  alias Msgr.Connectors.TelegramBridge
  alias Msgr.Support.QueueRecorder
  alias Messngr.Accounts.Account
  alias Messngr.Bridges

  setup do
    {:ok, agent} = QueueRecorder.start_link([])

    account =
      %Account{}
      |> Account.changeset(%{display_name: "Alice Tester"})
      |> Messngr.Repo.insert!()

    %{agent: agent, account: account}
  end

  test "link_account/3 builds MTProto handshake request", %{agent: agent} do
    bridge = TelegramBridge.new(queue: QueueRecorder, queue_opts: [agent: agent])
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

  test "send_message/3 publishes outbound envelope", %{agent: agent} do
    bridge = TelegramBridge.new(queue: QueueRecorder, queue_opts: [agent: agent])
    params = %{chat_id: 42, message: "hei", metadata: %{locale: "nb"}}
    assert :ok = TelegramBridge.send_message(bridge, params, trace_id: "out")

    assert [message] = QueueRecorder.published(agent)
    assert message.topic == "bridge/telegram/outbound_message"
    assert message.payload.payload == %{chat_id: 42, message: "hei", metadata: %{locale: "nb"}}
    assert message.payload.trace_id == "out"
  end

  test "send_message/3 can target a bridge instance", %{agent: agent} do
    bridge = TelegramBridge.new(queue: QueueRecorder, queue_opts: [agent: agent])
    params = %{chat_id: 42, message: "hei"}
    assert :ok = TelegramBridge.send_message(bridge, params, instance: :mtproto_norway)

    assert [message] = QueueRecorder.published(agent)
    assert message.topic == "bridge/telegram/mtproto_norway/outbound_message"
    assert message.payload.payload.metadata == %{}
  end

  test "ack_update/3 notifies the worker", %{agent: agent} do
    bridge = TelegramBridge.new(queue: QueueRecorder, queue_opts: [agent: agent])
    params = %{update_id: 1001, status: :processed}
    assert :ok = TelegramBridge.ack_update(bridge, params, trace_id: "ack")

    assert [ack] = QueueRecorder.published(agent)
    assert ack.topic == "bridge/telegram/ack_update"
    assert ack.payload.payload == %{update_id: 1001, status: :processed}
    assert ack.payload.trace_id == "ack"
  end

  test "link_account/3 persists bridge capabilities and roster", %{agent: agent, account: account} do
    response = %{
      "status" => "linked",
      "user" => %{"id" => 101, "username" => "alice", "first_name" => "Alice"},
      "session" => %{"blob" => "deadbeef"},
      "capabilities" => %{"messaging" => %{"text" => true, "media_types" => ["image"]}},
      "contacts" => [
        %{ "id" => "200", "username" => "bob", "first_name" => "Bob", "last_name" => "Builder" }
      ],
      "chats" => [
        %{ "id" => 300, "name" => "Team", "type" => "supergroup", "muted" => true }
      ]
    }

    bridge =
      TelegramBridge.new(
        queue: QueueRecorder,
        queue_opts: [agent: agent, responder: fn -> {:ok, response} end]
      )

    params = %{user_id: account.id, phone_number: "+4712345678", session: %{}}

    assert {:ok, ^response} = TelegramBridge.link_account(bridge, params)

    bridge_account = Bridges.get_account(account.id, "telegram")
    refute bridge_account == nil
    assert bridge_account.capabilities["messaging"]["text"]
    assert bridge_account.session == %{"blob" => "deadbeef"}

    [contact] = bridge_account.contacts
    assert contact.external_id == "200"
    assert contact.display_name == "Bob Builder"
    assert contact.handle == "bob"

    [channel] = bridge_account.channels
    assert channel.external_id == "300"
    assert channel.kind == "supergroup"
    assert channel.muted == true
  end
end
