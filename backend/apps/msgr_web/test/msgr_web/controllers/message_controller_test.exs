defmodule MessngrWeb.MessageControllerTest do
  use MessngrWeb.ConnCase, async: true

  alias Messngr.Accounts
  alias Messngr.Chat

  setup %{conn: conn} do
    {:ok, current_account} = Accounts.create_account(%{"display_name" => "Kari"})
    {:ok, other_account} = Accounts.create_account(%{"display_name" => "Ola"})

    current_profile = hd(current_account.profiles)
    other_profile = hd(other_account.profiles)

    {:ok, conversation} = Chat.ensure_direct_conversation(current_profile.id, other_profile.id)

    conn =
      conn
      |> put_req_header("x-account-id", current_account.id)
      |> put_req_header("x-profile-id", current_profile.id)

    {:ok,
     conn: conn,
     conversation: conversation,
     current_profile: current_profile}
  end

  test "lists messages", %{conn: conn, conversation: conversation, current_profile: profile} do
    {:ok, _} = Chat.send_message(conversation.id, profile.id, %{"body" => "Hei"})

    conn = get(conn, ~p"/api/conversations/#{conversation.id}/messages")

    assert %{"data" => [%{"body" => "Hei"}]} = json_response(conn, 200)
  end

  test "creates message", %{conn: conn, conversation: conversation} do
    conn =
      post(conn, ~p"/api/conversations/#{conversation.id}/messages", %{
        message: %{body: "Hei"}
      })

    assert %{"data" => %{"body" => "Hei"}} = json_response(conn, 201)
  end
end
