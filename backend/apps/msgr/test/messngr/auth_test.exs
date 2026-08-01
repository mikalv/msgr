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
               Messngr.start_auth_challenge(%{
                 "channel" => "email",
                 "identifier" => "otp@example.com"
               })

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

    test "rejects after too many invalid attempts" do
      {:ok, challenge, code} =
        Messngr.start_auth_challenge(%{
          "channel" => "email",
          "identifier" => "attempts-#{System.unique_integer([:positive])}@example.com"
        })

      # Avoid accidentally guessing the real code
      wrong = if code == "000000", do: "111111", else: "000000"

      for _ <- 1..4 do
        assert {:error, :invalid_code} =
                 Messngr.verify_auth_challenge(challenge.id, wrong, %{})
      end

      assert {:error, :too_many_attempts} =
               Messngr.verify_auth_challenge(challenge.id, wrong, %{})

      # Even the correct code is rejected once locked out
      assert {:error, :already_consumed} =
               Messngr.verify_auth_challenge(challenge.id, code, %{})
    end

    test "stores HMAC hash rather than raw or plain SHA256" do
      {:ok, challenge, code} =
        Messngr.start_auth_challenge(%{
          "channel" => "email",
          "identifier" => "hmac-#{System.unique_integer([:positive])}@example.com"
        })

      plain_sha =
        :crypto.hash(:sha256, code) |> Base.encode64()

      assert challenge.code_hash != code
      assert challenge.code_hash != plain_sha
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
