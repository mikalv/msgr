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
  end
end
