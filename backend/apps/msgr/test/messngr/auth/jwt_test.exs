defmodule Messngr.Auth.JwtTest do
  use Messngr.DataCase, async: true

  alias Messngr.Accounts
  alias Messngr.Auth

  setup do
    {:ok, account} = Accounts.create_account(%{"display_name" => "JWT Test"})
    profile = hd(account.profiles)
    %{account: account, profile: profile}
  end

  describe "issue_jwt_tokens/2" do
    test "returns an access and a refresh token", %{account: account, profile: profile} do
      {access_token, refresh_token} = Auth.issue_jwt_tokens(account, profile.id)

      assert is_binary(access_token)
      assert is_binary(refresh_token)
      refute access_token == refresh_token
    end

    test "access token decodes with correct claims", %{account: account, profile: profile} do
      {access_token, _refresh} = Auth.issue_jwt_tokens(account, profile.id)

      {:ok, claims} = AuthProvider.Guardian.decode_and_verify(access_token, %{"typ" => "access"})

      assert claims["sub"] == account.id
      assert claims["pid"] == profile.id
      assert claims["typ"] == "access"
      assert is_map(claims["ten"])
      assert claims["hdl"] == account.handle || account.display_name
    end

    test "refresh token decodes with correct claims", %{account: account, profile: profile} do
      {_access, refresh_token} = Auth.issue_jwt_tokens(account, profile.id)

      {:ok, claims} = AuthProvider.Guardian.decode_and_verify(refresh_token, %{"typ" => "refresh"})

      assert claims["sub"] == account.id
      assert claims["pid"] == profile.id
      assert claims["typ"] == "refresh"
      assert is_map(claims["ten"])
    end

    test "access token cannot be verified as refresh", %{account: account, profile: profile} do
      {access_token, _refresh} = Auth.issue_jwt_tokens(account, profile.id)

      assert {:error, _reason} =
               AuthProvider.Guardian.decode_and_verify(access_token, %{"typ" => "refresh"})
    end
  end

  describe "refresh_access_token/1" do
    test "returns a new access token from a valid refresh token", %{
      account: account,
      profile: profile
    } do
      {_access, refresh_token} = Auth.issue_jwt_tokens(account, profile.id)

      assert {:ok, new_access} = Auth.refresh_access_token(refresh_token)
      assert is_binary(new_access)

      {:ok, claims} = AuthProvider.Guardian.decode_and_verify(new_access, %{"typ" => "access"})
      assert claims["sub"] == account.id
      assert claims["pid"] == profile.id
    end

    test "returns error for an invalid token" do
      assert {:error, _reason} = Auth.refresh_access_token("totally.invalid.token")
    end

    test "returns error when using an access token as refresh", %{
      account: account,
      profile: profile
    } do
      {access_token, _refresh} = Auth.issue_jwt_tokens(account, profile.id)

      assert {:error, _reason} = Auth.refresh_access_token(access_token)
    end
  end

  describe "build_team_memberships_map (via issue_jwt_tokens)" do
    test "returns empty map for account with no teams", %{account: account, profile: profile} do
      {access_token, _refresh} = Auth.issue_jwt_tokens(account, profile.id)

      {:ok, claims} = AuthProvider.Guardian.decode_and_verify(access_token, %{"typ" => "access"})
      assert claims["ten"] == %{}
    end
  end
end
