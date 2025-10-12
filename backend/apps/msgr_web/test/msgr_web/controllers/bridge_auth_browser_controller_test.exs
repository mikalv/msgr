defmodule MessngrWeb.BridgeAuthBrowserControllerTest do
  use MessngrWeb.ConnCase, async: true

  alias Messngr.Accounts
  alias Messngr.Bridges.Auth
  alias Messngr.Bridges.AuthSession
  alias Messngr.Repo

  setup do
    {:ok, account} = Accounts.create_account(%{"display_name" => "Browser Owner"})
    {:ok, session} = Auth.start_session(account, "telegram", %{})

    %{session: session}
  end

  test "start redirects to callback with pkce metadata", %{session: session} do
    conn = build_conn()
    conn = get(conn, ~p"/auth/bridge/#{session.id}/start")

    redirect_url = redirected_to(conn)
    assert redirect_url =~ "/auth/bridge/#{session.id}/callback"

    reloaded = Repo.get!(AuthSession, session.id)
    assert reloaded.metadata["oauth"]["state"]
    assert reloaded.metadata["oauth"]["code_verifier"]
  end

  test "callback completes flow and renders success", %{session: session} do
    conn = build_conn()
    conn = get(conn, ~p"/auth/bridge/#{session.id}/start")
    redirect_url = redirected_to(conn)

    conn = build_conn()
    conn = get(conn, redirect_url)

    assert html_response(conn, 200) =~ "Authentication complete"

    reloaded = Repo.get!(AuthSession, session.id)
    assert reloaded.state == "completing"
    assert reloaded.metadata["oauth"]["credential_ref"]
  end

  test "callback rejects invalid state", %{session: session} do
    {:ok, session, _redirect_url} = Auth.initiate_oauth_redirect(session)

    params = %{"code" => "fake", "state" => "invalid"}
    conn = build_conn()
    conn = get(conn, ~p"/auth/bridge/#{session.id}/callback", params)

    assert response(conn, 400)
  end
end
