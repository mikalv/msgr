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
     host_account: host_account,
     host_profile: host_profile,
     peer_account: peer_account,
     peer_profile: peer_profile}
  end

  test "host can start a call", %{conversation: conversation, host_profile: host_profile, host_account: host_account} do
    {socket, _session} =
      UserSocket
      |> socket("user_id", %{})
      |> attach_noise_socket(host_account, host_profile)

    {:ok, response, socket} =
      subscribe_and_join(socket, RTCChannel, "rtc:#{conversation.id}", %{"media" => ["audio"]})

    assert response["call_id"]
    assert response["participant"]["profile_id"] == host_profile.id
    assert socket.assigns.call_id == response["call_id"]
  end

  test "participants receive offers", %{conversation: conversation, host_profile: host_profile, host_account: host_account, peer_profile: peer_profile, peer_account: peer_account} do
    {host_socket, _} =
      UserSocket
      |> socket("user_id", %{})
      |> attach_noise_socket(host_account, host_profile)

    {:ok, host_response, host_socket} =
      subscribe_and_join(host_socket, RTCChannel, "rtc:#{conversation.id}", %{})

    {peer_socket, _} =
      UserSocket
      |> socket("peer", %{})
      |> attach_noise_socket(peer_account, peer_profile)

    {:ok, _peer_response, _peer_socket} =
      subscribe_and_join(peer_socket, RTCChannel, "rtc:#{conversation.id}", %{"call_id" => host_response["call_id"]})

    push(host_socket, "signal:offer", %{"sdp" => "offer", "target" => peer_profile.id})

    assert_broadcast "signal:offer", %{"sdp" => "offer", "from" => host_profile.id, "target" => ^peer_profile.id}
  end

  test "leaving ends call when host disconnects", %{conversation: conversation, host_profile: host_profile, host_account: host_account, peer_profile: peer_profile, peer_account: peer_account} do
    {host_socket, _} =
      UserSocket
      |> socket("user_id", %{})
      |> attach_noise_socket(host_account, host_profile)

    {:ok, host_response, host_socket} =
      subscribe_and_join(host_socket, RTCChannel, "rtc:#{conversation.id}", %{})

    {peer_socket, _} =
      UserSocket
      |> socket("peer", %{})
      |> attach_noise_socket(peer_account, peer_profile)

    {:ok, _peer_response, peer_socket} =
      subscribe_and_join(peer_socket, RTCChannel, "rtc:#{conversation.id}", %{"call_id" => host_response["call_id"]})

    ref = push(peer_socket, "call:leave", %{})
    assert_reply ref, :ok
    assert_broadcast "participant:left", %{"profile_id" => peer_profile.id}

    ref = push(host_socket, "call:end", %{})
    assert_reply ref, :ok
    assert_broadcast "call:ended", %{"call_id" => host_response["call_id"]}
  end

  test "direct calls refuse a third participant", %{conversation: conversation, host_profile: host_profile, host_account: host_account, peer_profile: peer_profile, peer_account: peer_account} do
    {host_socket, _} =
      UserSocket
      |> socket("host", %{})
      |> attach_noise_socket(host_account, host_profile)

    {:ok, host_response, _host_socket} =
      subscribe_and_join(host_socket, RTCChannel, "rtc:#{conversation.id}", %{"peer_profile_id" => peer_profile.id})

    {peer_socket, _} =
      UserSocket
      |> socket("peer", %{})
      |> attach_noise_socket(peer_account, peer_profile)

    {:ok, _peer_response, _peer_socket} =
      subscribe_and_join(peer_socket, RTCChannel, "rtc:#{conversation.id}", %{"call_id" => host_response["call_id"]})

    {:ok, observer_account} = Accounts.create_account(%{"display_name" => "Lise"})
    observer_profile = hd(observer_account.profiles)

    {observer_socket, _} =
      UserSocket
      |> socket("observer", %{})
      |> attach_noise_socket(observer_account, observer_profile)

    assert {:error, %{reason: "direct_call_full"}} =
             subscribe_and_join(observer_socket, RTCChannel, "rtc:#{conversation.id}", %{"call_id" => host_response["call_id"]})
  end
end
