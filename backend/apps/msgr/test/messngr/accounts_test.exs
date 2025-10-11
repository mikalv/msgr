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
end
