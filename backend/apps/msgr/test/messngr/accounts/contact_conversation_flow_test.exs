defmodule Messngr.Accounts.ContactConversationFlowTest do
  use Messngr.DataCase

  alias Messngr.{Accounts, Chat}
  alias Messngr.Chat.Message

  test "account contact conversation broadcast flow" do
    {:ok, identity_a} =
      Accounts.ensure_identity(%{
        kind: :email,
        value: "alice@example.com",
        display_name: "Alice Example"
      })

    {:ok, identity_b} =
      Accounts.ensure_identity(%{
        kind: :email,
        value: "bob@example.com",
        display_name: "Bob Example"
      })

    account_a = Accounts.get_account!(identity_a.account_id)
    account_b = Accounts.get_account!(identity_b.account_id)

    profile_a = hd(account_a.profiles)
    profile_b = hd(account_b.profiles)

    {:ok, [contact]} =
      Accounts.import_contacts(account_a.id, [%{email: "bob@example.com", name: "Bob Example"}],
        profile_id: profile_a.id
      )

    assert contact.profile_id == profile_a.id
    assert contact.email == "bob@example.com"

    {:ok, [%{match: match}]} = Accounts.lookup_known_contacts([%{email: "bob@example.com"}])

    assert match.account_id == account_b.id
    assert match.identity_kind == :email

    assert {:ok, conversation} = Chat.ensure_direct_conversation(profile_a.id, profile_b.id)

    :ok = Chat.subscribe_to_conversation(conversation.id)

    assert {:ok, message} = Chat.send_message(conversation.id, profile_a.id, %{"body" => "Hei"})

    assert_receive {:message_created, %Message{id: ^message.id, profile_id: ^profile_a.id}}, 500
  end
end
