defmodule Messngr.AuthTest do
  use Messngr.DataCase

  alias Messngr.Auth.Challenge

  describe "start_auth_challenge/1" do
    test "creates and returns code" do
      assert {:ok, %Challenge{} = challenge, code} =
               Messngr.start_auth_challenge(%{"channel" => "email", "identifier" => "otp@example.com"})

      assert challenge.target == "otp@example.com"
      assert challenge.channel == :email
      assert String.length(code) == 6
      assert challenge.code_hash != code
    end
  end

  describe "verify_auth_challenge/3" do
    test "creates account and verifies identity" do
      {:ok, challenge, code} =
        Messngr.start_auth_challenge(%{"channel" => "phone", "identifier" => "+4798765432"})

      assert {:ok, %{account: account, identity: identity}} =
               Messngr.verify_auth_challenge(challenge.id, code, %{"display_name" => "Telefon"})

      assert identity.kind == :phone
      assert identity.verified_at != nil
      assert account.phone_number == "+4798765432"
    end
  end

  describe "complete_oidc/1" do
    test "ensures federated identity" do
      assert {:ok, %{account: account, identity: identity}} =
               Messngr.complete_oidc(%{
                 "provider" => "example",
                 "subject" => "abc-123",
                 "email" => "oidc@example.com",
                 "name" => "OIDC Bruker"
               })

      assert identity.kind == :oidc
      assert identity.provider == "example"
      assert account.display_name == "OIDC Bruker"
    end
  end
end

