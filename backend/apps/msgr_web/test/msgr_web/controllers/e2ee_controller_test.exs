defmodule MessngrWeb.E2eeControllerTest do
  use MessngrWeb.ConnCase, async: true

  alias Messngr.Accounts

  setup %{conn: conn} do
    {:ok, account} = Accounts.create_account(%{"display_name" => "E2EE API"})
    profile = hd(account.profiles)
    conn = attach_jwt_session(conn, account, profile)
    {:ok, conn: conn, profile: profile, account: account}
  end

  test "put keys and fetch empty-or-populated bundles", %{conn: conn, profile: profile} do
    # Empty bundles are OK
    conn_empty = get(conn, ~p"/api/v1/e2ee/bundles/#{profile.id}")
    assert %{"data" => []} = json_response(conn_empty, 200)

    ik = Base.encode64(:crypto.strong_rand_bytes(32))
    spk = Base.encode64(:crypto.strong_rand_bytes(32))
    sig = Base.encode64(:crypto.strong_rand_bytes(64))

    conn_put =
      put(conn, ~p"/api/v1/e2ee/keys", %{
        device_id: "dev-1",
        identity_key: ik,
        signed_prekey: spk,
        spk_id: 1,
        spk_signature: sig,
        one_time_prekeys: [
          %{opk_id: 10, public_key: Base.encode64(:crypto.strong_rand_bytes(32))}
        ]
      })

    assert %{"data" => %{"device_id" => "dev-1", "one_time_prekey_count" => 1}} =
             json_response(conn_put, 200)

    conn_count = get(conn, ~p"/api/v1/e2ee/keys/count?device_id=dev-1")
    assert %{"data" => %{"one_time_prekey_count" => 1}} = json_response(conn_count, 200)

    conn_bundles = get(conn, ~p"/api/v1/e2ee/bundles/#{profile.id}")
    assert %{"data" => [bundle]} = json_response(conn_bundles, 200)
    assert bundle["device_id"] == "dev-1"
    assert bundle["one_time_prekey"]["opk_id"] == 10
  end

  test "creates encrypted message via REST", %{conn: conn, profile: profile} do
    {:ok, other} = Accounts.create_account(%{"display_name" => "Peer"})
    other_profile = hd(other.profiles)
    {:ok, conversation} = Messngr.Chat.ensure_direct_conversation(profile.id, other_profile.id)

    conn =
      post(conn, ~p"/api/conversations/#{conversation.id}/messages", %{
        message: %{
          kind: "encrypted",
          body: "",
          payload: %{
            v: 1,
            e2ee: %{
              sid: "dev-1",
              iv_ct: nil,
              keys: [
                %{
                  rid: "*",
                  type: "init",
                  ik: Base.encode64(:crypto.strong_rand_bytes(32)),
                  ek: Base.encode64(:crypto.strong_rand_bytes(32)),
                  header: %{
                    dh: Base.encode64(:crypto.strong_rand_bytes(32)),
                    pn: 0,
                    n: 0
                  },
                  ct: nil
                }
              ]
            }
          }
        }
      })

    assert %{"data" => %{"type" => "encrypted", "body" => body, "payload" => payload}} =
             json_response(conn, 201)

    assert body in [nil, ""]
    assert payload["e2ee"]["sid"] == "dev-1"
  end
end
