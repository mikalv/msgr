defmodule Messngr.AccountsTest do
  use Messngr.DataCase

  alias Messngr.Accounts

  describe "create_account/1" do
    test "creates account with default profile" do
      {:ok, account} =
        Accounts.create_account(%{
          "display_name" => "Kari Nordmann",
          "email" => "kari@example.com"
        })

      assert account.display_name == "Kari Nordmann"
      assert [%{name: "Privat"}] = account.profiles
      assert account.handle =~ "kari"
    end

    test "requires display_name" do
      assert {:error, changeset} = Accounts.create_account(%{})
      assert %{display_name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "create_profile/1" do
    test "associates to account" do
      {:ok, account} =
        Accounts.create_account(%{
          "display_name" => "Ola",
          "email" => "ola@example.com"
        })

      {:ok, profile} =
        Accounts.create_profile(%{
          "name" => "Jobb",
          "mode" => :work,
          "account_id" => account.id
        })

      assert profile.mode == :work
      assert profile.account_id == account.id
    end
  end

  describe "ensure_identity/1" do
    test "creates account and identity for new email" do
      assert {:ok, identity} =
               Accounts.ensure_identity(%{kind: :email, value: "new.user@example.com"})

      assert identity.kind == :email
      assert identity.value == "new.user@example.com"
      assert identity.account.display_name == "New User"
    end

    test "reuses existing account for the same phone" do
      {:ok, identity} =
        Accounts.ensure_identity(%{kind: :phone, value: "+4790000000", display_name: "Mobil"})

      {:ok, same_identity} = Accounts.ensure_identity(%{kind: :phone, value: "+47 900 00 000"})

      assert identity.account_id == same_identity.account_id
      assert same_identity.account.display_name == "Mobil"
    end

    test "links additional oidc identity to an existing account" do
      {:ok, email_identity} =
        Accounts.ensure_identity(%{kind: :email, value: "mikal@example.com", display_name: "Mikal"})

      {:ok, oidc_identity} =
        Accounts.ensure_identity(%{
          kind: :oidc,
          provider: "github",
          subject: "123",
          account_id: email_identity.account_id,
          display_name: "Mikal GitHub"
        })

      assert oidc_identity.account_id == email_identity.account_id
      assert oidc_identity.provider == "github"
      assert oidc_identity.subject == "123"
    end

    test "prevents linking an existing identity to a different account" do
      {:ok, first_identity} =
        Accounts.ensure_identity(%{
          kind: :oidc,
          provider: "google",
          subject: "abc",
          display_name: "Google User"
        })

      {:ok, other_identity} =
        Accounts.ensure_identity(%{kind: :email, value: "other@example.com", display_name: "Other"})

      assert {:error, :identity_already_linked} =
               Accounts.ensure_identity(%{
                 kind: :oidc,
                 provider: "google",
                 subject: "abc",
                 account_id: other_identity.account_id
               })

      assert first_identity.account_id != other_identity.account_id
    end
  end

  describe "import_contacts/3" do
    setup do
      {:ok, account} = Accounts.create_account(%{"display_name" => "Eva"})
      profile = List.first(account.profiles)

      {:ok, account: account, profile: profile}
    end

    test "creates and updates contacts", %{account: account, profile: profile} do
      {:ok, [contact]} =
        Accounts.import_contacts(account.id, [%{name: "  Eva N.  ", email: "Eva.N@example.com"}],
          profile_id: profile.id
        )

      assert contact.email == "eva.n@example.com"
      assert contact.profile_id == profile.id
      assert contact.name == "Eva N."

      {:ok, [updated]} =
        Accounts.import_contacts(account.id, [%{email: "eva.n@example.com", phone_number: "+47 900 00 000"}])

      assert updated.id == contact.id
      assert updated.phone_number == "4790000000"
    end
  end

  describe "lookup_known_contacts/1" do
    test "returns match for known email" do
      {:ok, identity} =
        Accounts.ensure_identity(%{kind: :email, value: "known@example.com", display_name: "Known"})

      {:ok, [%{query: %{email: "known@example.com"}, match: match}]} =
        Accounts.lookup_known_contacts([%{email: "KNOWN@example.com"}])

      assert match.account_id == identity.account_id
      assert match.identity_kind == :email
      assert match.identity_value == "known@example.com"
    end

    test "returns nil match for unknown target" do
      assert {:ok, [%{match: nil, query: %{email: "missing@example.com", phone_number: nil}}]} =
               Accounts.lookup_known_contacts([%{email: "missing@example.com"}])
    end
  end
end
