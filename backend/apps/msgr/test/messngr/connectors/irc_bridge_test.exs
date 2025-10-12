defmodule Messngr.Connectors.IRCBridgeTest do
  use ExUnit.Case, async: true

  alias Msgr.Connectors.IRCBridge
  alias Msgr.Support.QueueRecorder

  setup do
    {:ok, agent} = QueueRecorder.start_link([])
    bridge = IRCBridge.new(queue: QueueRecorder, queue_opts: [agent: agent])

    %{bridge: bridge, agent: agent}
  end

  test "configure_identity/3 records identity config", %{bridge: bridge, agent: agent} do
    params = %{user_id: "u-irc", network: "irc.libera.chat", nickname: "msgr", auth: %{method: :sasl}}
    assert {:ok, %{status: :accepted}} = IRCBridge.configure_identity(bridge, params, trace_id: "irc-config")

    assert [request] = QueueRecorder.requests(agent)
    assert request.topic == "bridge/irc/configure_identity"
    assert request.payload.payload == params
  end

  test "send_command/3 publishes IRC command payload", %{bridge: bridge, agent: agent} do
    params = %{command: "PRIVMSG", target: "#msgr", arguments: ["Hello"]}
    assert :ok = IRCBridge.send_command(bridge, params, trace_id: "cmd")

    assert [message] = QueueRecorder.published(agent)
    assert message.topic == "bridge/irc/outbound_command"
    assert message.payload.payload == %{
             command: "PRIVMSG",
             target: "#msgr",
             arguments: ["Hello"],
             metadata: %{}
           }
    assert message.payload.trace_id == "cmd"
  end

  test "ack_offset/3 publishes acknowledgement", %{bridge: bridge, agent: agent} do
    params = %{network: "irc.libera.chat", channel: "#msgr", offset: 101}
    assert :ok = IRCBridge.ack_offset(bridge, params, trace_id: "offset")

    assert [ack] = QueueRecorder.published(agent)
    assert ack.topic == "bridge/irc/ack_offset"
    assert ack.payload.payload == %{network: "irc.libera.chat", channel: "#msgr", offset: 101}
  end
end
