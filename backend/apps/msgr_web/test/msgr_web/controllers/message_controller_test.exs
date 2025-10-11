defmodule MessngrWeb.MessageControllerTest do
  use MessngrWeb.ConnCase, async: true

  alias Messngr.Accounts
  alias Messngr.Chat
  alias Messngr.Media

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

    assert %{"data" => [%{"body" => "Hei", "type" => "text", "payload" => %{}}], "meta" => meta} =
             json_response(conn, 200)

    assert meta["after_id"]
  end

  test "creates message", %{conn: conn, conversation: conversation} do
    conn =
      post(conn, ~p"/api/conversations/#{conversation.id}/messages", %{
        message: %{body: "Hei"}
      })

    assert %{"data" => %{"body" => "Hei", "type" => "text"}} = json_response(conn, 201)
  end

  test "creates media upload and audio message", %{conn: conn, conversation: conversation, current_profile: profile} do
    conn_upload =
      post(conn, ~p"/api/conversations/#{conversation.id}/uploads", %{
        upload: %{
          kind: "audio",
          content_type: "audio/mpeg",
          byte_size: 4096
        }
      })

    %{"data" => %{"id" => upload_id, "upload" => upload_info}} = json_response(conn_upload, 201)
    assert upload_info["method"] == "PUT"
    assert upload_info["object_key"]

    conn_message =
      post(conn, ~p"/api/conversations/#{conversation.id}/messages", %{
        message: %{
          kind: "audio",
          body: "Hør på dette",
          media: %{
            upload_id: upload_id,
            durationMs: 1200
          }
        }
      })

    assert %{"data" => %{"type" => "audio", "payload" => %{"media" => media}}} =
             json_response(conn_message, 201)

    assert media["durationMs"] == 1200
    assert media["url"] =~ upload_info["object_key"]
    assert Media.consume_upload(upload_id, conversation.id, profile.id, %{}) == {:error, :already_consumed}
  end
end
