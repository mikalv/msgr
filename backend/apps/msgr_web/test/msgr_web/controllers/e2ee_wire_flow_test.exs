defmodule MessngrWeb.E2eeWireFlowTest do
  @moduledoc """
  End-to-end opaque relay for personal-mode E2EE over REST.

  Two authenticated actors exchange init → init_ack → msg envelopes. The server
  must persist/fan-out payload.e2ee without requiring plaintext body content.
  Cryptographic correctness is covered by Dart tests; this suite verifies the
  wire/storage contract (no plaintext leakage server-side).
  """

  use MessngrWeb.ConnCase, async: true

  alias Messngr.Accounts
  alias Messngr.Chat
  alias Messngr.Chat.Message
  alias Messngr.Repo

  @plaintext_marker "E2EE_PLAINTEXT_SHOULD_NEVER_APPEAR_ON_SERVER"

  setup %{conn: conn} do
    {:ok, alice_account} = Accounts.create_account(%{"display_name" => "Alice E2E"})
    {:ok, bob_account} = Accounts.create_account(%{"display_name" => "Bob E2E"})
    alice_profile = hd(alice_account.profiles)
    bob_profile = hd(bob_account.profiles)

    {:ok, conversation} =
      Chat.ensure_direct_conversation(alice_profile.id, bob_profile.id)

    alice_conn = attach_jwt_session(conn, alice_account, alice_profile)
    bob_conn = attach_jwt_session(build_conn(), bob_account, bob_profile)

    {:ok,
     alice_conn: alice_conn,
     bob_conn: bob_conn,
     alice_profile: alice_profile,
     bob_profile: bob_profile,
     conversation: conversation}
  end

  test "init → init_ack → msg relay keeps plaintext off the server", %{
    alice_conn: alice_conn,
    bob_conn: bob_conn,
    conversation: conversation
  } do
    init_payload = envelope("alice-device", "*", "init", iv_ct: nil)

    alice_init =
      post(alice_conn, ~p"/api/conversations/#{conversation.id}/messages", %{
        message: %{kind: "encrypted", body: "", payload: init_payload}
      })

    assert %{"data" => %{"id" => init_id, "type" => "encrypted", "body" => init_body}} =
             json_response(alice_init, 201)

    assert init_body in [nil, ""]
    refute_inspect_contains(Repo.get!(Message, init_id), @plaintext_marker)

    ack_payload = envelope("bob-device", "alice-device", "init_ack", iv_ct: nil)

    bob_ack =
      post(bob_conn, ~p"/api/conversations/#{conversation.id}/messages", %{
        message: %{kind: "encrypted", body: "", payload: ack_payload}
      })

    assert %{"data" => %{"id" => ack_id, "type" => "encrypted"}} = json_response(bob_ack, 201)
    refute_inspect_contains(Repo.get!(Message, ack_id), @plaintext_marker)

    # Ciphertext blob intentionally does not include the plaintext marker.
    msg_payload =
      envelope("alice-device", "bob-device", "msg",
        iv_ct: Base.encode64(:crypto.strong_rand_bytes(48))
      )

    alice_msg =
      post(alice_conn, ~p"/api/conversations/#{conversation.id}/messages", %{
        message: %{
          kind: "encrypted",
          body: @plaintext_marker,
          payload: msg_payload
        }
      })

    assert %{"data" => %{"id" => msg_id, "type" => "encrypted", "body" => msg_body}} =
             json_response(alice_msg, 201)

    # Server must not keep client-supplied plaintext body for encrypted kind.
    assert msg_body in [nil, ""]
    stored = Repo.get!(Message, msg_id)
    assert stored.kind == :encrypted
    assert stored.body in [nil, ""]
    refute_inspect_contains(stored, @plaintext_marker)

    # History listing also stays opaque for both participants.
    alice_list = get(alice_conn, ~p"/api/conversations/#{conversation.id}/messages")
    bob_list = get(bob_conn, ~p"/api/conversations/#{conversation.id}/messages")

    assert %{"data" => alice_messages} = json_response(alice_list, 200)
    assert %{"data" => bob_messages} = json_response(bob_list, 200)
    assert length(alice_messages) == 3
    assert length(bob_messages) == 3

    for msg <- alice_messages ++ bob_messages do
      assert msg["type"] == "encrypted"
      assert msg["body"] in [nil, ""]
      assert is_map(msg["payload"]["e2ee"])
      refute inspect(msg) =~ @plaintext_marker
    end
  end

  test "reject encrypted message without payload.e2ee", %{
    alice_conn: alice_conn,
    conversation: conversation
  } do
    conn =
      post(alice_conn, ~p"/api/conversations/#{conversation.id}/messages", %{
        message: %{kind: "encrypted", body: "", payload: %{v: 1}}
      })

    assert json_response(conn, 422)
  end

  defp envelope(sid, rid, type, opts) do
    iv_ct = Keyword.get(opts, :iv_ct)

    %{
      "v" => 1,
      "e2ee" => %{
        "sid" => sid,
        "iv_ct" => iv_ct,
        "keys" => [
          %{
            "rid" => rid,
            "type" => type,
            "ik" => Base.encode64(:crypto.strong_rand_bytes(32)),
            "ek" => Base.encode64(:crypto.strong_rand_bytes(32)),
            "header" => %{
              "dh" => Base.encode64(:crypto.strong_rand_bytes(32)),
              "pn" => 0,
              "n" => 0
            },
            "ct" =>
              if(type == "msg",
                do: Base.encode64(:crypto.strong_rand_bytes(64)),
                else: nil
              )
          }
        ]
      }
    }
  end

  defp refute_inspect_contains(value, marker) do
    refute inspect(value) =~ marker
  end
end
