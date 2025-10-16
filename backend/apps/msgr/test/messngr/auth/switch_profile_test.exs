defmodule Messngr.Auth.SwitchProfileTest do
  use Messngr.DataCase

  alias Messngr.{Accounts, Auth}
  alias Messngr.Noise.SessionFixtures
  alias Messngr.Noise.SessionStore
  alias Messngr.Transport.Noise.Session

  setup do
    {:ok, account} = Accounts.create_account(%{"display_name" => "Kari"})
    profile = List.first(account.profiles)
    {:ok, other} = Accounts.create_profile(%{"name" => "Jobb", "mode" => :work, "account_id" => account.id})

    %{account: account, profile: profile, other: other}
  end

  test "switches active profile and updates device", %{account: account, profile: profile, other: other} do
    %{token: token, device: device, session: session} =
      SessionFixtures.noise_session_fixture(account, profile)

    assert {:ok, result} = Auth.switch_profile(token, account.id, other.id)
    assert result.profile.id == other.id
    assert result.device.id == device.id
    assert result.token == token

    updated_device = Accounts.get_device!(device.id)
    assert updated_device.profile_id == other.id

    {:ok, _session, actor} = SessionStore.fetch(Session.token(session))
    assert actor.profile_id == other.id
  end

  test "rejects mismatched account", %{account: account, profile: profile, other: other} do
    %{token: token} = SessionFixtures.noise_session_fixture(account, profile)

    assert {:error, :account_mismatch} = Auth.switch_profile(token, Ecto.UUID.generate(), other.id)
  end

  test "rejects unknown profile", %{account: account, profile: profile} do
    %{token: token} = SessionFixtures.noise_session_fixture(account, profile)

    assert {:error, :profile_not_found} = Auth.switch_profile(token, account.id, Ecto.UUID.generate())
  end

  test "rejects invalid token", %{account: account, other: other} do
    assert {:error, :invalid_token} = Auth.switch_profile("invalid", account.id, other.id)
  end
end
