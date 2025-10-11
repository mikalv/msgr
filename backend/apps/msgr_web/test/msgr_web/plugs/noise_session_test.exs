defmodule MessngrWeb.Plugs.NoiseSessionTest do
  use MessngrWeb.ConnCase, async: true

  alias Messngr.Accounts
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

  test "responds unauthorized when token is missing", %{conn: conn} do
    conn = NoiseSession.call(conn, %{})

    assert conn.halted
    assert conn.status == 401
    assert %{"error" => "missing or invalid noise session"} = Jason.decode!(conn.resp_body)
  end

  test "falls back to legacy headers when feature is enabled", %{conn: conn, account: account, profile: profile} do
    original = Application.get_env(:msgr_web, :legacy_actor_headers, false)
    Application.put_env(:msgr_web, :legacy_actor_headers, true)

    on_exit(fn -> Application.put_env(:msgr_web, :legacy_actor_headers, original) end)

    conn =
      conn
      |> put_req_header("x-account-id", account.id)
      |> put_req_header("x-profile-id", profile.id)
      |> NoiseSession.call(%{})

    refute conn.halted
    assert conn.assigns.current_profile.id == profile.id
  end
end
