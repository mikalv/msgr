defmodule Messngr.AuthTest do
  use Messngr.DataCase

  alias Messngr.Auth.Challenge
  alias Swoosh.Adapters.Local.Storage.Memory

  setup do
    Memory.clear()
    :ok
  end

  describe "start_auth_challenge/1" do
    test "creates and returns code" do
      assert {:ok, %Challenge{} = challenge, code} =
               Messngr.start_auth_challenge(%{"channel" => "email", "identifier" => "otp@example.com"})

      assert challenge.target == "otp@example.com"
      assert challenge.channel == :email
      assert String.length(code) == 6
      assert challenge.code_hash != code
    end

    test "delivers email challenge" do
      identifier = "deliver-#{System.unique_integer([:positive])}@example.com"

      assert {:ok, %Challenge{}, code} =
               Messngr.start_auth_challenge(%{"channel" => "email", "identifier" => identifier})

      assert [email] = Memory.all()
      assert email.to == [{nil, identifier}]
      assert email.subject =~ "login code"
      assert String.contains?(email.text_body, code)
    end

    test "rate limits repeated requests" do
      identifier = "limit-#{System.unique_integer([:positive])}@example.com"
      limit =
        Application.get_env(:msgr, :rate_limits)
        |> Keyword.fetch!(:auth_challenge)
        |> Keyword.fetch!(:limit)

      for _ <- 1..limit do
        assert {:ok, %Challenge{}, _code} =
                 Messngr.start_auth_challenge(%{"channel" => "email", "identifier" => identifier})
      end

      assert {:error, :too_many_requests} =
               Messngr.start_auth_challenge(%{"channel" => "email", "identifier" => identifier})
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

