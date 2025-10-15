defmodule MessngrWeb.Plugs.NoiseSessionTest do
  use MessngrWeb.ConnCase, async: true

  alias Messngr.Accounts
  alias Messngr.Noise.SessionStore
  alias Messngr.Transport.Noise.Session
  alias MessngrWeb.Plugs.NoiseSession

  setup %{conn: conn} do
    {:ok, account} = Accounts.create_account(%{"display_name" => "Tester"})
    profile = hd(account.profiles)
    conn = Plug.Test.init_test_session(conn, %{})

    {:ok, conn: conn, account: account, profile: profile}
  end

  test "assigns current actor from Noise token", %{conn: conn, account: account, profile: profile} do
    %{token: token} = noise_session_fixture(account, profile)

    conn =
      conn
      |> put_req_header("authorization", "Noise #{token}")
      |> NoiseSession.call(%{})

    refute conn.halted
    assert conn.status in [nil, 200]
    assert conn.assigns.current_account.id == account.id
    assert conn.assigns.current_profile.id == profile.id
    assert get_session(conn, :noise_session_token) == token
    assert conn.assigns.current_device
  end

  test "reads Noise token from explicit header", %{conn: conn, account: account, profile: profile} do
    %{token: token} = noise_session_fixture(account, profile)

    conn =
      conn
      |> put_req_header("x-noise-session", token)
      |> NoiseSession.call(%{})

    refute conn.halted
    assert conn.assigns.current_profile.id == profile.id
    assert get_session(conn, :noise_session_token) == token
  end

  test "uses session-stored token when header is missing", %{conn: conn, account: account, profile: profile} do
    %{token: token} = noise_session_fixture(account, profile)

    conn =
      conn
      |> put_session(:noise_session_token, token)
      |> NoiseSession.call(%{})

    refute conn.halted
    assert conn.assigns.current_profile.id == profile.id
  end

  test "does not persist token when assign_session is false", %{conn: conn, account: account, profile: profile} do
    %{token: token} = noise_session_fixture(account, profile)

    conn =
      conn
      |> put_req_header("authorization", "Noise #{token}")
      |> NoiseSession.call(%{assign_session: false})

    assert get_session(conn, :noise_session_token) == nil
  end

  test "responds unauthorized when token is missing", %{conn: conn} do
    conn = NoiseSession.call(conn, %{})

    assert conn.halted
    assert conn.status == 401
    assert %{"error" => "missing or invalid noise session"} = Jason.decode!(conn.resp_body)
  end

  test "responds unauthorized when token is invalid", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Noise invalid-token")
      |> NoiseSession.call(%{})

    assert conn.halted
    assert conn.status == 401
  end

  test "rejects bearer scheme when not allowed", %{conn: conn, account: account, profile: profile} do
    %{token: token} = noise_session_fixture(account, profile)

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> NoiseSession.call(%{authorization_schemes: [:noise]})

    assert conn.halted
    assert conn.status == 401
  end

  describe "verify_token/2" do
    test "returns actor metadata", %{account: account, profile: profile} do
      %{token: token} = noise_session_fixture(account, profile)

      assert {:ok, actor} = NoiseSession.verify_token(token)
      assert actor.account.id == account.id
      assert actor.profile.id == profile.id
      assert actor.session
    end

    test "returns error when device is disabled", %{account: account, profile: profile} do
      %{token: token, device: device} = noise_session_fixture(account, profile)
      {:ok, _} = Accounts.deactivate_device(device)

      assert {:error, :device_disabled} = NoiseSession.verify_token(token)
    end

    test "supports device lookup via public key", %{account: account, profile: profile} do
      {:ok, device} =
        Accounts.create_device(%{account_id: account.id, profile_id: profile.id, device_public_key: "pk-#{System.unique_integer([:positive])}"})

      {:ok, session} =
        SessionStore.issue(%{account_id: account.id, profile_id: profile.id, device_public_key: device.device_public_key})

      token = SessionStore.encode_token(Session.token(session))

      assert {:ok, actor} = NoiseSession.verify_token(token)
      assert actor.device.id == device.id
    end
  end
end
