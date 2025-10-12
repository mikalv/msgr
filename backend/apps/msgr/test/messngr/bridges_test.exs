defmodule Messngr.BridgesTest do
  use Messngr.DataCase, async: true

  alias Messngr.Accounts.Account
  alias Messngr.Bridges

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
end
