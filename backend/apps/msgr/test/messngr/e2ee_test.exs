defmodule Messngr.E2eeTest do
  use Messngr.DataCase

  alias Messngr.{Accounts, Chat, E2ee}

  setup do
    {:ok, account} = Accounts.create_account(%{"display_name" => "E2EE User"})
    profile = hd(account.profiles)
    {:ok, profile: profile, account: account}
  end

  test "put_keys and fetch_bundles pops one OPK", %{profile: profile} do
    ik = Base.encode64(:crypto.strong_rand_bytes(32))
    spk = Base.encode64(:crypto.strong_rand_bytes(32))
    sig = Base.encode64(:crypto.strong_rand_bytes(64))

    {:ok, result} =
      E2ee.put_keys(profile.id, %{
        "device_id" => "device-a",
        "identity_key" => ik,
        "signed_prekey" => spk,
        "spk_id" => 1,
        "spk_signature" => sig,
        "one_time_prekeys" => [
          %{"opk_id" => 1, "public_key" => Base.encode64(:crypto.strong_rand_bytes(32))},
          %{"opk_id" => 2, "public_key" => Base.encode64(:crypto.strong_rand_bytes(32))}
        ]
      })

    assert result.device_id == "device-a"
    assert result.one_time_prekey_count == 2

    {:ok, bundles} = E2ee.fetch_bundles(profile.id)
    assert length(bundles) == 1
    assert hd(bundles)["device_id"] == "device-a"
    assert hd(bundles)["one_time_prekey"]["opk_id"] in [1, 2]

    {:ok, count} = E2ee.count_one_time_prekeys(profile.id, "device-a")
    assert count == 1
  end

  test "fetch_bundles returns empty list when no keys", %{profile: profile} do
    assert {:ok, []} = E2ee.fetch_bundles(profile.id)
  end

  test "encrypted message stores opaque payload without plaintext body", %{profile: profile} do
    {:ok, other} = Accounts.create_account(%{"display_name" => "Peer"})
    other_profile = hd(other.profiles)
    {:ok, conversation} = Chat.ensure_direct_conversation(profile.id, other_profile.id)

    envelope = %{
      "v" => 1,
      "e2ee" => %{
        "sid" => "device-a",
        "iv_ct" => nil,
        "keys" => [
          %{
            "rid" => "*",
            "type" => "init",
            "ik" => Base.encode64(:crypto.strong_rand_bytes(32)),
            "ek" => Base.encode64(:crypto.strong_rand_bytes(32)),
            "header" => %{"dh" => Base.encode64(:crypto.strong_rand_bytes(32)), "pn" => 0, "n" => 0},
            "ct" => nil
          }
        ]
      }
    }

    assert {:ok, message} =
             Chat.send_message(conversation.id, profile.id, %{
               "kind" => "encrypted",
               "body" => "",
               "payload" => envelope
             })

    assert message.kind == :encrypted
    assert message.body == ""
    assert message.payload["e2ee"]["sid"] == "device-a"
    refute message.payload["e2ee"]["keys"] |> hd() |> Map.get("ik") == nil
  end
end
