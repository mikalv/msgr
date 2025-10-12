defmodule MessngrWeb.MessageControllerTest do
  use MessngrWeb.ConnCase, async: true

  alias Messngr.Accounts
  alias Messngr.Chat
  alias Messngr.Media
  alias Messngr.Chat.MessageReceipt
  alias Messngr.Repo

  setup %{conn: conn} do
    {:ok, current_account} = Accounts.create_account(%{"display_name" => "Kari"})
    {:ok, other_account} = Accounts.create_account(%{"display_name" => "Ola"})

    current_profile = hd(current_account.profiles)
    other_profile = hd(other_account.profiles)

    {:ok, conversation} = Chat.ensure_direct_conversation(current_profile.id, other_profile.id)

    {conn, _session} = attach_noise_session(conn, current_account, current_profile)

    {:ok,
     conn: conn,
     conversation: conversation,
     current_profile: current_profile,
     other_profile: other_profile}
  end

  test "lists messages", %{conn: conn, conversation: conversation, current_profile: profile, other_profile: other} do
    {:ok, message} = Chat.send_message(conversation.id, profile.id, %{"body" => "Hei"})

    conn = get(conn, ~p"/api/conversations/#{conversation.id}/messages")

    assert %{"data" => [msg], "meta" => meta} = json_response(conn, 200)
    assert msg["body"] == "Hei"
    assert [
             %{
               "status" => "pending",
               "recipient_id" => other.id,
               "message_id" => message.id
             }
           ] = Enum.map(msg["receipts"], &Map.take(&1, ["status", "recipient_id", "message_id"]))

    assert meta["start_cursor"] == message.id
    assert meta["end_cursor"] == message.id
    assert meta["has_more"] == %{"before" => false, "after" => false}
  end

  test "creates message", %{conn: conn, conversation: conversation, other_profile: other} do
    conn =
      post(conn, ~p"/api/conversations/#{conversation.id}/messages", %{
        message: %{body: "Hei"}
      })

    assert %{"data" => %{"body" => "Hei", "type" => "text", "receipts" => receipts}} =
             json_response(conn, 201)

    assert [%{"status" => "pending", "recipient_id" => ^other.id}] =
             Enum.map(receipts, &Map.take(&1, ["status", "recipient_id"]))
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
    assert upload_info["retention_expires_at"]
    assert upload_info["thumbnail_upload"] == nil

    conn_message =
      post(conn, ~p"/api/conversations/#{conversation.id}/messages", %{
        message: %{
          kind: "audio",
          body: "Hør på dette",
          media: %{
            upload_id: upload_id,
            durationMs: 1200,
            caption: "Hør på dette",
            waveform: [0, 10, 20]
          }
        }
      })

    assert %{"data" => %{"type" => "audio", "payload" => %{"media" => media}, "media" => media_view}} =
             json_response(conn_message, 201)

    assert media["durationMs"] == 1200
    assert media["url"] =~ upload_info["object_key"]
    assert media["retention"]["expiresAt"]
    assert media["waveform"] == [0, 10, 20]
    assert media_view == media
    assert Media.consume_upload(upload_id, conversation.id, profile.id, %{}) == {:error, :already_consumed}
  end

  test "acknowledges message delivery", %{conn: conn, conversation: conversation, current_profile: profile, other_profile: other} do
    {:ok, message} = Chat.send_message(conversation.id, other.id, %{"body" => "Hei"})

    conn = post(conn, ~p"/api/conversations/#{conversation.id}/messages/#{message.id}/delivery")

    assert %{"data" => %{"status" => "delivered", "recipient_id" => profile.id}} =
             json_response(conn, 200)

    receipt = Repo.get_by!(MessageReceipt, message_id: message.id, recipient_id: profile.id)
    assert receipt.status == :delivered
    assert receipt.delivered_at
  end
end
