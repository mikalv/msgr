defmodule MessngrWeb.ConversationControllerTest do
  use MessngrWeb.ConnCase, async: true

  alias Messngr.{Accounts, Chat}

  setup %{conn: conn} do
    {:ok, current_account} = Accounts.create_account(%{"display_name" => "Kari"})
    {:ok, other_account} = Accounts.create_account(%{"display_name" => "Ola"})

    current_profile = hd(current_account.profiles)
    target_profile = hd(other_account.profiles)

    {conn, _session} = attach_noise_session(conn, current_account, current_profile)

    {:ok,
     conn: conn,
     target_profile: target_profile,
     current_profile: current_profile,
     current_account: current_account}
  end

  test "creates or returns conversation", %{conn: conn, target_profile: target_profile} do
    conn = post(conn, ~p"/api/conversations", %{target_profile_id: target_profile.id})

    assert %{"data" => %{"id" => id, "participants" => participants}} = json_response(conn, 200)
    assert is_binary(id)
    assert length(participants) == 2
  end

  test "lists conversations with metadata", %{conn: conn, target_profile: target_profile, current_profile: profile} do
    {:ok, conversation} = Chat.ensure_direct_conversation(profile.id, target_profile.id)
    {:ok, _} = Chat.send_message(conversation.id, profile.id, %{"body" => "Hei"})

    conn = get(conn, ~p"/api/conversations")

    assert %{
             "data" => [
               %{
                 "id" => ^conversation.id,
                 "unread_count" => 1,
                 "last_message" => %{"body" => "Hei"}
               }
             ],
             "meta" => %{"has_more" => %{"after" => false, "before" => false}}
           } = json_response(conn, 200)
  end

  test "watch endpoints manage watchers", %{conn: conn, target_profile: target_profile, current_profile: profile} do
    {:ok, conversation} = Chat.ensure_direct_conversation(profile.id, target_profile.id)

    watch_conn = post(conn, ~p"/api/conversations/#{conversation.id}/watch")

    assert %{"data" => %{"count" => 1, "watchers" => [%{"id" => ^profile.id}]}} =
             json_response(watch_conn, 200)

    watchers_conn = get(conn, ~p"/api/conversations/#{conversation.id}/watchers")

    assert %{"data" => %{"count" => 1}} = json_response(watchers_conn, 200)

    unwatch_conn = delete(conn, ~p"/api/conversations/#{conversation.id}/watch")

    assert %{"data" => %{"count" => 0}} = json_response(unwatch_conn, 200)
  end

  test "updates conversation read receipt preference", %{
    conn: conn,
    target_profile: target_profile,
    current_profile: profile
  } do
    {:ok, conversation} = Chat.ensure_direct_conversation(profile.id, target_profile.id)

    conn =
      patch(conn, ~p"/api/conversations/#{conversation.id}", %{
        "read_receipts_enabled" => false
      })

    assert %{
             "data" => %{
               "id" => ^conversation.id,
               "read_receipts_enabled" => false
             }
           } = json_response(conn, 200)
  end

  test "missing header returns unauthorized", %{target_profile: target_profile} do
    conn = build_conn()
    conn = post(conn, ~p"/api/conversations", %{target_profile_id: target_profile.id})

    assert json_response(conn, 401) == %{"error" => "missing or invalid noise session"}
  end
end
