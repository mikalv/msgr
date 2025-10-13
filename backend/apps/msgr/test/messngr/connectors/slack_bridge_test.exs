defmodule Messngr.Connectors.SlackBridgeTest do
  use Messngr.DataCase, async: true

  alias Msgr.Connectors.SlackBridge
  alias Msgr.Support.QueueRecorder
  alias Messngr.Accounts.Account
  alias Messngr.Bridges

  setup do
    {:ok, agent} = QueueRecorder.start_link([])

    account =
      %Account{}
      |> Account.changeset(%{display_name: "Slack Tester"})
      |> Messngr.Repo.insert!()

    %{agent: agent, account: account}
  end

  test "link_account/3 forwards installation payload", %{agent: agent} do
    bridge = SlackBridge.new(queue: QueueRecorder, queue_opts: [agent: agent])

    params = %{
      user_id: "acct-1",
      installation: %{code: "oauth-code"},
      workspace: %{id: "T123", name: "Acme"}
    }

    assert {:ok, %{status: :accepted}} = SlackBridge.link_account(bridge, params, trace_id: "slack-link")

    assert [request] = QueueRecorder.requests(agent)
    assert request.topic == "bridge/slack/link_account"
    assert request.payload.trace_id == "slack-link"
    assert request.payload.payload[:user_id] == "acct-1"
    assert request.payload.payload[:workspace] == %{id: "T123", name: "Acme"}
  end

  test "link_account/3 can target a specific bridge instance", %{agent: agent} do
    bridge = SlackBridge.new(queue: QueueRecorder, queue_opts: [agent: agent])

    params = %{user_id: "acct-2", installation: %{code: "oauth"}}

    assert {:ok, %{status: :accepted}} =
             SlackBridge.link_account(bridge, params, instance: :workspace_eu)

    assert [request] = QueueRecorder.requests(agent)
    assert request.topic == "bridge/slack/workspace_eu/link_account"
  end

  test "send_message/3 publishes Slack envelope", %{agent: agent} do
    bridge = SlackBridge.new(queue: QueueRecorder, queue_opts: [agent: agent])

    params = %{channel: "C123", text: "Hei", metadata: %{locale: "nb"}}
    assert :ok = SlackBridge.send_message(bridge, params, trace_id: "msg")

    assert [message] = QueueRecorder.published(agent)
    assert message.topic == "bridge/slack/outbound_message"
    assert message.payload.trace_id == "msg"
    assert message.payload.payload[:channel] == "C123"
    assert message.payload.payload[:metadata] == %{locale: "nb"}
    assert message.payload.payload[:blocks] == []
    assert message.payload.payload[:attachments] == []
  end

  test "ack_event/3 notifies bridge worker", %{agent: agent} do
    bridge = SlackBridge.new(queue: QueueRecorder, queue_opts: [agent: agent])

    params = %{event_id: "evt-1", status: :processed}
    assert :ok = SlackBridge.ack_event(bridge, params, trace_id: "ack")

    assert [ack] = QueueRecorder.published(agent)
    assert ack.topic == "bridge/slack/ack_event"
    assert ack.payload.trace_id == "ack"
    assert ack.payload.payload == %{event_id: "evt-1", status: :processed}
  end

  test "link_account/3 persists workspace snapshot", %{agent: agent, account: account} do
    response = %{
      "status" => "linked",
      "team" => %{ "id" => "T999", "name" => "Acme", "domain" => "acme" },
      "user" => %{
        "id" => "U123",
        "real_name" => "Alice Example",
        "profile" => %{ "display_name" => "alice" }
      },
      "session" => %{ "access_token" => "xoxp-1" },
      "capabilities" => %{ "messaging" => %{ "threads" => true } },
      "members" => [
        %{ "id" => "U234", "real_name" => "Bob Builder", "name" => "bobb" }
      ],
      "conversations" => [
        %{ "id" => "C1", "name" => "general", "type" => "channel" }
      ]
    }

    bridge =
      SlackBridge.new(
        queue: QueueRecorder,
        queue_opts: [agent: agent, responder: fn -> {:ok, response} end]
      )

    params = %{user_id: account.id, installation: %{code: "ok"}}

    assert {:ok, ^response} = SlackBridge.link_account(bridge, params)

    bridge_account = Bridges.get_account(account.id, :slack, instance: "T999")
    refute bridge_account == nil
    assert bridge_account.service == "slack"
    assert bridge_account.instance == "T999"
    assert bridge_account.external_id == "U123"
    assert bridge_account.display_name == "Alice Example"
    assert bridge_account.metadata["workspace"]["id"] == "T999"
    assert bridge_account.metadata["user"]["real_name"] == "Alice Example"

    [contact] = bridge_account.contacts
    assert contact.external_id == "U234"
    assert contact.display_name == "Bob Builder"

    [channel] = bridge_account.channels
    assert channel.external_id == "C1"
    assert channel.name == "general"
  end
end
