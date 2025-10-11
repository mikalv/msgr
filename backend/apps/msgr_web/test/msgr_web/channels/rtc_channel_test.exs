defmodule MessngrWeb.RTCChannelTest do
  use MessngrWeb.ChannelCase

  alias Messngr.{Accounts, Chat}
  alias MessngrWeb.{RTCChannel, UserSocket}

  setup do
    {:ok, host_account} = Accounts.create_account(%{"display_name" => "Kari"})
    {:ok, peer_account} = Accounts.create_account(%{"display_name" => "Ola"})

    host_profile = hd(host_account.profiles)
    peer_profile = hd(peer_account.profiles)

    {:ok, conversation} = Chat.ensure_direct_conversation(host_profile.id, peer_profile.id)

    {:ok,
     conversation: conversation,
     host_profile: host_profile,
     peer_profile: peer_profile}
  end

  test "host can start a call", %{conversation: conversation, host_profile: host_profile} do
    {:ok, response, socket} =
      UserSocket
      |> socket("user_id", %{})
      |> subscribe_and_join(RTCChannel, "rtc:#{conversation.id}", %{
        "profile_id" => host_profile.id,
        "media" => ["audio"]
      })

    assert response["call_id"]
    assert response["participant"]["profile_id"] == host_profile.id
    assert socket.assigns.call_id == response["call_id"]
  end

  test "participants receive offers", %{conversation: conversation, host_profile: host_profile, peer_profile: peer_profile} do
    {:ok, host_response, host_socket} =
      UserSocket
      |> socket("user_id", %{})
      |> subscribe_and_join(RTCChannel, "rtc:#{conversation.id}", %{"profile_id" => host_profile.id})

    {:ok, _peer_response, _peer_socket} =
      UserSocket
      |> socket("peer", %{})
      |> subscribe_and_join(RTCChannel, "rtc:#{conversation.id}", %{
        "profile_id" => peer_profile.id,
        "call_id" => host_response["call_id"]
      })

    push(host_socket, "signal:offer", %{"sdp" => "offer", "target" => peer_profile.id})

    assert_broadcast "signal:offer", %{"sdp" => "offer", "from" => host_profile.id, "target" => ^peer_profile.id}
  end

  test "leaving ends call when host disconnects", %{conversation: conversation, host_profile: host_profile, peer_profile: peer_profile} do
    {:ok, host_response, host_socket} =
      UserSocket
      |> socket("user_id", %{})
      |> subscribe_and_join(RTCChannel, "rtc:#{conversation.id}", %{"profile_id" => host_profile.id})

    {:ok, _peer_response, peer_socket} =
      UserSocket
      |> socket("peer", %{})
      |> subscribe_and_join(RTCChannel, "rtc:#{conversation.id}", %{
        "profile_id" => peer_profile.id,
        "call_id" => host_response["call_id"]
      })

    ref = push(peer_socket, "call:leave", %{})
    assert_reply ref, :ok
    assert_broadcast "participant:left", %{"profile_id" => peer_profile.id}

    ref = push(host_socket, "call:end", %{})
    assert_reply ref, :ok
    assert_broadcast "call:ended", %{"call_id" => host_response["call_id"]}
  end
end
