defmodule SlackApiWeb.ChatApiControllerTest do
  use SlackApiWeb.ConnCase, async: true

  alias Messngr
  alias Messngr.Accounts
  alias SlackApi.{SlackId, SlackTimestamp}

  setup %{conn: conn} do
    {:ok, account} =
      Accounts.create_account(%{"display_name" => "Acme", "profile_name" => "Alice"})

    {:ok, peer_account} =
      Accounts.create_account(%{"display_name" => "Beta", "profile_name" => "Bob"})

    current_profile = hd(account.profiles)
    peer_profile = hd(peer_account.profiles)

    {:ok, conversation} = Messngr.ensure_direct_conversation(current_profile.id, peer_profile.id)

    authed_conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("x-account-id", account.id)
      |> put_req_header("x-profile-id", current_profile.id)

    {:ok,
     conn: authed_conn,
     conversation: conversation,
     current_profile: current_profile,
     account: account,
     peer_profile: peer_profile}
  end

  test "chat.postMessage stores and returns a Slack-style payload", %{
    conn: conn,
    conversation: conversation
  } do
    channel = SlackId.conversation(conversation)

    response =
      conn
      |> post(~p"/api/chat.postMessage", %{channel: channel, text: "Hei"})
      |> json_response(200)

    assert response["ok"]
    assert response["channel"] == channel
    assert response["message"]["text"] == "Hei"
    assert is_binary(response["ts"])
  end

  test "conversations.list returns the current workspace conversations", %{
    conn: conn,
    conversation: conversation
  } do
    channel = SlackId.conversation(conversation)

    response =
      conn
      |> get(~p"/api/conversations.list")
      |> json_response(200)

    channels = response["channels"]
    assert [%{"id" => ^channel}] = channels
  end

  test "conversations.history returns messages in chronological order", %{
    conn: conn,
    conversation: conversation
  } do
    channel = SlackId.conversation(conversation)

    conn
    |> post(~p"/api/chat.postMessage", %{channel: channel, text: "Hei"})
    |> json_response(200)

    history =
      conn
      |> get(~p"/api/conversations.history", %{channel: channel})
      |> json_response(200)

    assert history["ok"]
    assert [%{"text" => "Hei"}] = history["messages"]
  end

  test "conversations.mark updates the participant last_read_at", %{
    conn: conn,
    conversation: conversation,
    current_profile: current_profile
  } do
    {:ok, message} =
      Messngr.send_message(conversation.id, current_profile.id, %{"body" => "Hei"})

    channel = SlackId.conversation(conversation)
    ts = SlackTimestamp.encode(message.sent_at, message_id: message.id)

    response =
      conn
      |> post(~p"/api/conversations.mark", %{channel: channel, ts: ts})
      |> json_response(200)

    assert response["ok"]
    assert response["channel"] == channel
    assert response["ts"] == ts

    participant = Messngr.ensure_membership(conversation.id, current_profile.id)
    assert participant.last_read_at
    assert DateTime.compare(participant.last_read_at, message.sent_at) in [:gt, :eq]
  end

  test "conversations.mark with an invalid timestamp returns an error", %{
    conn: conn,
    conversation: conversation
  } do
    channel = SlackId.conversation(conversation)

    response =
      conn
      |> post(~p"/api/conversations.mark", %{channel: channel, ts: "invalid"})
      |> json_response(200)

    refute response["ok"]
    assert response["error"] == "invalid_ts"
  end
end
