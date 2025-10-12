defmodule Messngr.BridgesTest do
  use Messngr.DataCase, async: true

  alias Messngr.Accounts.{Account, Contact}
  alias Messngr.Bridges
  alias Messngr.Bridges.BridgeAccount
  alias Messngr.ShareLinks
  alias Messngr.Repo

  describe "sync_linked_identity/3" do
    setup do
      account =
        %Account{}
        |> Account.changeset(%{display_name: "Bridge Owner"})
        |> Messngr.Repo.insert!()

      %{account: account}
    end

    test "persists capabilities, contacts, and channels", %{account: account} do
      attrs = %{
        external_id: "tg-101",
        display_name: "Alice Telegram",
        session: %{"blob" => "deadbeef"},
        capabilities: %{"messaging" => %{"text" => true, "media_types" => ["image"]}},
        metadata: %{"user" => %{"username" => "alice"}},
        contacts: [
          %{
            "external_id" => "200",
            "display_name" => "Bob",
            "handle" => "bob",
            "metadata" => %{"phone_number" => "+47"}
          }
        ],
        channels: [
          %{
            "external_id" => "300",
            "name" => "Team",
            "kind" => "supergroup",
            "role" => "admin",
            "muted" => true,
            "metadata" => %{"participant_count" => 3}
          }
        ]
      }

      assert {:ok, account_record} = Bridges.sync_linked_identity(account.id, :telegram, attrs)
      assert account_record.service == "telegram"
      assert account_record.external_id == "tg-101"
      assert account_record.capabilities["messaging"]["text"]
      assert account_record.session == %{"blob" => "deadbeef"}
      assert account_record.metadata["user"]["username"] == "alice"
      assert length(account_record.contacts) == 1
      assert length(account_record.channels) == 1

      contact = hd(account_record.contacts)
      assert contact.external_id == "200"
      assert contact.handle == "bob"
      assert contact.profile.canonical_name == "Bob"

      channel = hd(account_record.channels)
      assert channel.external_id == "300"
      assert channel.kind == "supergroup"
      assert channel.role == "admin"
      assert channel.muted
      assert channel.metadata["participant_count"] == 3
    end

    test "replaces stale contacts and channels", %{account: account} do
      initial_attrs = %{
        external_id: "sig-1",
        display_name: "Signal Account",
        contacts: [%{"external_id" => "old"}],
        channels: [%{"external_id" => "chat-1", "type" => "group"}]
      }

      assert {:ok, _} = Bridges.sync_linked_identity(account.id, "signal", initial_attrs)

      update_attrs = %{
        external_id: "sig-1",
        contacts: [%{"external_id" => "new", "name" => "Fresh"}],
        channels: [%{"external_id" => "chat-2", "name" => "New Chat", "type" => "direct"}]
      }

      assert {:ok, updated} = Bridges.sync_linked_identity(account.id, :signal, update_attrs)
      assert Enum.map(updated.contacts, & &1.external_id) == ["new"]
      assert Enum.map(updated.channels, & &1.external_id) == ["chat-2"]
      assert Enum.map(updated.channels, & &1.kind) == ["direct"]
    end

    test "ignores malformed payloads", %{account: account} do
      attrs = %{
        external_id: 123,
        contacts: ["not-a-map", %{external_id: nil}],
        channels: nil,
        capabilities: "invalid"
      }

      assert {:ok, record} = Bridges.sync_linked_identity(account.id, :telegram, attrs)
      assert record.external_id == "123"
      assert record.capabilities == %{}
      assert record.contacts == []
      assert record.channels == []
    end
  end

  describe "create_share_link/3" do
    setup do
      account = insert_account!("Share Link Owner")

      bridge_account =
        %BridgeAccount{}
        |> BridgeAccount.changeset(%{
          account_id: account.id,
          service: "irc",
          external_id: "irc-user"
        })
        |> Repo.insert!()

      %{account: account, bridge_account: bridge_account}
    end

    test "creates share link tied to bridge account", %{bridge_account: bridge_account} do
      attrs = %{payload: %{"download" => %{"url" => "https://example/file"}}}

      assert {:ok, link} = Bridges.create_share_link(bridge_account.id, :file, attrs)
      assert link.bridge_account_id == bridge_account.id
      assert link.account_id == bridge_account.account_id
      assert ShareLinks.public_url(link) =~ link.token
    end

    test "returns error for unknown bridge account" do
      assert {:error, :unknown_bridge_account} = Bridges.create_share_link(Ecto.UUID.generate(), :image, %{})
    end
  end

  describe "unlink_account/2" do
    setup do
      %{account: insert_account!("Unlink Owner")}
    end

    test "removes bridge account and cascades related data", %{account: account} do
      assert {:ok, linked} =
               Bridges.sync_linked_identity(account.id, :telegram, %{external_id: "unlink-me"})

      assert {:ok, link} =
               Bridges.create_share_link(linked.id, :file, %{payload: %{"url" => "https://example"}})

      assert {:ok, _deleted} = Bridges.unlink_account(account.id, :telegram)
      assert Bridges.get_account(account.id, :telegram) == nil
      assert Repo.get(ShareLinks.ShareLink, link.id) == nil
    end

    test "returns error when bridge is not linked", %{account: account} do
      assert {:error, :not_found} = Bridges.unlink_account(account.id, :matrix)
    end
  end

  test "get_account/2 returns persisted identity" do
    account =
      %Account{}
      |> Account.changeset(%{display_name: "Lookup"})
      |> Messngr.Repo.insert!()

    assert {:ok, _} =
             Bridges.sync_linked_identity(account.id, :telegram, %{external_id: "lookup", contacts: []})

    fetched = Bridges.get_account(account.id, :telegram)
    assert fetched.external_id == "lookup"
    assert fetched.service == "telegram"
  end

  describe "contact profile matching" do
    setup do
      account =
        %Account{}
        |> Account.changeset(%{display_name: "Matcher"})
        |> Repo.insert!()

      %{account: account}
    end

    test "reuses profiles across sync snapshots", %{account: account} do
      attrs = %{
        external_id: "tg-10",
        contacts: [
          %{
            "external_id" => "alice",
            "display_name" => "Alice",
            "metadata" => %{"phone_number" => "+47 888888"}
          }
        ]
      }

      assert {:ok, first} = Bridges.sync_linked_identity(account.id, :telegram, attrs)
      first_contact = hd(first.contacts)
      assert first_contact.profile_id

      resync_attrs = %{
        external_id: "tg-10",
        contacts: [
          %{
            "external_id" => "alice",
            "display_name" => "Alice Cooper",
            "metadata" => %{"phone_number" => "+47 888888"}
          }
        ]
      }

      assert {:ok, second} = Bridges.sync_linked_identity(account.id, :telegram, resync_attrs)
      second_contact = hd(second.contacts)

      assert second_contact.profile_id == first_contact.profile_id
      assert second_contact.profile.canonical_name == "Alice"
    end

    test "matches contacts across services by phone and username", %{account: account} do
      telegram_attrs = %{
        external_id: "tg-500",
        contacts: [
          %{
            "external_id" => "bob",
            "display_name" => "Bob TG",
            "metadata" => %{"phone_number" => "+47 999111", "username" => "bobby"}
          }
        ]
      }

      signal_attrs = %{
        external_id: "sig-500",
        contacts: [
          %{
            "external_id" => "bob-s",
            "display_name" => "Bob Signal",
            "metadata" => %{"phone_number" => "0047 999 111", "username" => "bobby"}
          }
        ]
      }

      assert {:ok, _} = Bridges.sync_linked_identity(account.id, :telegram, telegram_attrs)
      assert {:ok, _} = Bridges.sync_linked_identity(account.id, :signal, signal_attrs)

      profiles = Bridges.list_profiles(account.id)
      assert length(profiles) == 1

      profile = hd(profiles)
      assert Enum.sort(Enum.map(profile.contacts, & &1.external_id)) == ["bob", "bob-s"]
      assert Enum.any?(profile.keys, &(&1.kind == "phone" and &1.value == "47999111"))
      assert Enum.any?(profile.keys, &(&1.kind == "handle" and &1.value == "bobby"))
    end

    test "links msgr contacts into bridge profiles", %{account: account} do
      attrs = %{
        external_id: "tg-200",
        contacts: [
          %{
            "external_id" => "charlie",
            "display_name" => "Charlie",
            "metadata" => %{"email" => "charlie@example.com"}
          }
        ]
      }

      assert {:ok, synced} = Bridges.sync_linked_identity(account.id, :telegram, attrs)
      bridge_contact = hd(synced.contacts)

      msgr_contact =
        %Contact{}
        |> Contact.changeset(%{
          name: "Charlie",
          email: "charlie@example.com",
          account_id: account.id
        })
        |> Repo.insert!()

      assert {:ok, linked_profile} = Bridges.link_msgr_contact(msgr_contact)
      assert linked_profile.id == bridge_contact.profile_id
      assert Enum.any?(linked_profile.links, &(&1.source == "msgr_contact"))
    end

    test "list_profiles aggregates bridge and msgr entries", %{account: account} do
      assert {:ok, _} =
               Bridges.sync_linked_identity(account.id, :telegram, %{
                 external_id: "tg-777",
                 contacts: [
                   %{
                     "external_id" => "dora",
                     "display_name" => "Dora",
                     "metadata" => %{"phone_number" => "+47 707070"}
                   }
                 ]
               })

      msgr_contact =
        %Contact{}
        |> Contact.changeset(%{
          name: "Dora",
          phone_number: "+47 707070",
          account_id: account.id
        })
        |> Repo.insert!()

      assert {:ok, _profile} = Bridges.link_msgr_contact(msgr_contact)

      profiles = Bridges.list_profiles(account.id)
      assert length(profiles) == 1

      profile = hd(profiles)
      assert Enum.map(profile.contacts, & &1.external_id) == ["dora"]
      assert Enum.any?(profile.links, &(&1.source == "msgr_contact"))
    end
  end

  defp insert_account!(name) do
    %Account{}
    |> Account.changeset(%{display_name: name})
    |> Messngr.Repo.insert!()
  end
end
