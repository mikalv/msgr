defmodule Messngr.Connectors.SnapchatBridgeTest do
  use ExUnit.Case, async: true

  alias Msgr.Connectors.SnapchatBridge
  alias Msgr.Support.QueueRecorder

  setup do
    {:ok, agent} = QueueRecorder.start_link([])
    bridge = SnapchatBridge.new(queue: QueueRecorder, queue_opts: [agent: agent])

    %{bridge: bridge, agent: agent}
  end

  test "link_account/3 captures attestation artefacts", %{bridge: bridge, agent: agent} do
    params = %{
      user_id: "snap-1",
      sso_ticket: "ticket",
      web_client_auth: "auth-token",
      attestation: %{challenge: "abc"},
      device_info: %{platform: "mac"},
      cookies: nil
    }

    assert {:ok, %{status: :accepted}} = SnapchatBridge.link_account(bridge, params, trace_id: "link")

    assert [request] = QueueRecorder.requests(agent)
    assert request.topic == "bridge/snapchat/link_account"

    assert request.payload.payload == %{
             user_id: "snap-1",
             sso_ticket: "ticket",
             web_client_auth: "auth-token",
             attestation: %{challenge: "abc"},
             device_info: %{platform: "mac"}
           }

    refute Map.has_key?(request.payload.payload, :cookies)
    assert request.payload.trace_id == "link"
  end

  test "refresh_session/3 requests renewed chat cookies", %{bridge: bridge, agent: agent} do
    params = %{session_id: "sess", client_id: "web-calling-corp--prod", web_client_auth: "auth"}

    assert {:ok, %{status: :accepted}} = SnapchatBridge.refresh_session(bridge, params, trace_id: "refresh")

    assert [request] = QueueRecorder.requests(agent)
    assert request.topic == "bridge/snapchat/refresh_session"
    assert request.payload.payload == %{
             session_id: "sess",
             client_id: "web-calling-corp--prod",
             web_client_auth: "auth"
           }

    assert request.payload.trace_id == "refresh"
  end

  test "send_message/3 publishes outbound envelope with default metadata", %{bridge: bridge, agent: agent} do
    params = %{conversation_id: "conv", message: %{text: "hei"}, client_context: %{uuid: "1"}}

    assert :ok = SnapchatBridge.send_message(bridge, params, trace_id: "out")

    assert [message] = QueueRecorder.published(agent)
    assert message.topic == "bridge/snapchat/outbound_message"

    assert message.payload.payload == %{
             conversation_id: "conv",
             message: %{text: "hei"},
             client_context: %{uuid: "1"},
             metadata: %{}
           }

    assert message.payload.trace_id == "out"
  end

  test "ack_message/3 omits unset fields", %{bridge: bridge, agent: agent} do
    params = %{conversation_id: "conv", message_id: "m1", status: :delivered, read_at: nil}

    assert :ok = SnapchatBridge.ack_message(bridge, params, trace_id: "ack")

    assert [ack] = QueueRecorder.published(agent)
    assert ack.topic == "bridge/snapchat/ack_message"

    assert ack.payload.payload == %{
             conversation_id: "conv",
             message_id: "m1",
             status: :delivered
           }

    refute Map.has_key?(ack.payload.payload, :read_at)
    assert ack.payload.trace_id == "ack"
  end

  test "request_sync/3 forwards cursor hints", %{bridge: bridge, agent: agent} do
    params = %{cursor: "delta:123", limit: 25, reason: nil, features: [:deltaforce, :spotlight]}

    assert :ok = SnapchatBridge.request_sync(bridge, params, trace_id: "sync")

    assert [sync] = QueueRecorder.published(agent)
    assert sync.topic == "bridge/snapchat/request_sync"

    assert sync.payload.payload == %{
             cursor: "delta:123",
             limit: 25,
             features: [:deltaforce, :spotlight]
           }

    refute Map.has_key?(sync.payload.payload, :reason)
    assert sync.payload.trace_id == "sync"
  end
end
