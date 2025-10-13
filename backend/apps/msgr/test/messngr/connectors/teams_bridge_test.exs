defmodule Messngr.Connectors.TeamsBridgeTest do
  use Messngr.DataCase, async: true

  alias Msgr.Connectors.TeamsBridge
  alias Msgr.Support.QueueRecorder
  alias Messngr.Accounts.Account
  alias Messngr.Bridges

  setup do
    {:ok, agent} = QueueRecorder.start_link([])

    account =
      %Account{}
      |> Account.changeset(%{display_name: "Teams Tester"})
      |> Messngr.Repo.insert!()

    %{agent: agent, account: account}
  end

  test "link_account/3 queues tenant handshake", %{agent: agent} do
    bridge = TeamsBridge.new(queue: QueueRecorder, queue_opts: [agent: agent])

    params = %{user_id: "acct-1", tenant: %{id: "tenant-a", name: "Acme"}}
    assert {:ok, %{status: :accepted}} = TeamsBridge.link_account(bridge, params, trace_id: "teams-link")

    assert [request] = QueueRecorder.requests(agent)
    assert request.topic == "bridge/teams/link_account"
    assert request.payload.trace_id == "teams-link"
    assert request.payload.payload[:tenant] == %{id: "tenant-a", name: "Acme"}
  end

  test "link_account/3 can route to a tenant-specific instance", %{agent: agent} do
    bridge = TeamsBridge.new(queue: QueueRecorder, queue_opts: [agent: agent])

    params = %{user_id: "acct-2", tenant: %{id: "tenant-b"}}
    assert {:ok, %{status: :accepted}} = TeamsBridge.link_account(bridge, params, instance: :tenant_b)

    assert [request] = QueueRecorder.requests(agent)
    assert request.topic == "bridge/teams/tenant_b/link_account"
  end

  test "send_message/3 publishes Teams payload", %{agent: agent} do
    bridge = TeamsBridge.new(queue: QueueRecorder, queue_opts: [agent: agent])

    params = %{chat_id: "19:chat", message: "Hei", mentions: [%{id: "user"}]}
    assert :ok = TeamsBridge.send_message(bridge, params, trace_id: "teams-msg")

    assert [message] = QueueRecorder.published(agent)
    assert message.topic == "bridge/teams/outbound_message"
    assert message.payload.trace_id == "teams-msg"
    assert message.payload.payload[:chat_id] == "19:chat"
    assert message.payload.payload[:mentions] == [%{id: "user"}]
    assert message.payload.payload[:attachments] == []
  end

  test "ack_event/3 notifies worker", %{agent: agent} do
    bridge = TeamsBridge.new(queue: QueueRecorder, queue_opts: [agent: agent])

    params = %{event_id: "evt-2", status: :processed}
    assert :ok = TeamsBridge.ack_event(bridge, params, trace_id: "ack")

    assert [ack] = QueueRecorder.published(agent)
    assert ack.topic == "bridge/teams/ack_event"
    assert ack.payload.payload == %{event_id: "evt-2", status: :processed}
  end

  test "link_account/3 persists tenant roster", %{agent: agent, account: account} do
    response = %{
      "status" => "linked",
      "tenant" => %{ "id" => "tenant-z", "name" => "Acme" },
      "user" => %{ "id" => "user-1", "displayName" => "Alice" },
      "session" => %{ "refresh_token" => "rt" },
      "capabilities" => %{ "messaging" => %{ "reactions" => true } },
      "members" => [
        %{ "id" => "user-2", "displayName" => "Bob" }
      ],
      "chats" => [
        %{ "id" => "chat-1", "topic" => "Project", "kind" => "group" }
      ]
    }

    bridge =
      TeamsBridge.new(
        queue: QueueRecorder,
        queue_opts: [agent: agent, responder: fn -> {:ok, response} end]
      )

    params = %{user_id: account.id, tenant: %{id: "tenant-z"}}

    assert {:ok, ^response} = TeamsBridge.link_account(bridge, params)

    bridge_account = Bridges.get_account(account.id, :teams, instance: "tenant-z")
    refute bridge_account == nil
    assert bridge_account.service == "teams"
    assert bridge_account.instance == "tenant-z"
    assert bridge_account.external_id == "user-1"
    assert bridge_account.metadata["tenant"]["id"] == "tenant-z"

    [contact] = bridge_account.contacts
    assert contact.external_id == "user-2"
    assert contact.display_name == "Bob"

    [channel] = bridge_account.channels
    assert channel.external_id == "chat-1"
    assert channel.kind == "group"
  end
end
