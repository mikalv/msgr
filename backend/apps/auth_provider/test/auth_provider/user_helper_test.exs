defmodule AuthProvider.UserHelperTest do
  use ExUnit.Case
  alias AuthProvider.UserHelper
  alias AuthProvider.Account.{User, AuthMethod, UserDevice}
  alias AuthProvider.Repo

  import Mock

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "find_or_register_user_by_email/2" do
    test "registers a new user if email not found" do
      with_mock Repo, [get_by: fn _, _ -> nil end, insert: fn _ -> {:ok, %User{id: 1, email: "test@example.com"}} end] do
        assert {:ok, %User{id: 1, email: "test@example.com"}} = UserHelper.find_or_register_user_by_email("test@example.com")
      end
    end

    test "returns existing user if email found" do
      with_mock Repo, [get_by: fn _, _ -> %User{id: 1, email: "test@example.com"} end] do
        assert {:ok, %User{id: 1, email: "test@example.com"}} = UserHelper.find_or_register_user_by_email("test@example.com")
      end
    end
  end

  describe "find_or_register_user_by_msisdn/2" do
    test "registers a new user if msisdn not found" do
      with_mock Repo, [get_by: fn _, _ -> nil end, insert: fn _ -> {:ok, %User{id: 1, msisdn: "1234567890"}} end] do
        assert {:ok, %User{id: 1, msisdn: "1234567890"}} = UserHelper.find_or_register_user_by_msisdn("1234567890")
      end
    end

    test "returns existing user if msisdn found" do
      with_mock Repo, [get_by: fn _, _ -> %User{id: 1, msisdn: "1234567890"} end] do
        assert {:ok, %User{id: 1, msisdn: "1234567890"}} = UserHelper.find_or_register_user_by_msisdn("1234567890")
      end
    end
  end

  describe "create_login_code_for_user/1" do
    test "creates a new login code for user" do
      user = %User{id: 1, msisdn: "+1234567890"}
      with_mock Repo, [insert_or_update: fn _ -> {:ok, %AuthMethod{auth_type: "one_time_code", user_id: user.id, value: "123456"}} end] do
        assert :ok = UserHelper.create_login_code_for_user(user)
      end
    end
  end

  describe "validate_login_code_for_user/2" do
    test "validates correct login code" do
      user = %User{id: 1}
      with_mock Repo, [get_by: fn _, _ -> %AuthMethod{value: "123456"} end, update: fn _ -> {:ok, %AuthMethod{}} end] do
        assert {:ok, :valid_code} = UserHelper.validate_login_code_for_user("123456", user)
      end
    end

    test "returns error for incorrect login code" do
      user = %User{id: 1}
      with_mock Repo, [get_by: fn _, _ -> %AuthMethod{value: "123456"} end] do
        assert {:error, :invalid_code} = UserHelper.validate_login_code_for_user("654321", user)
      end
    end
  end
end
