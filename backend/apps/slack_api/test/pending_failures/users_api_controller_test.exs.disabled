defmodule SlackApiWeb.UsersApiControllerTest do
  use SlackApiWeb.ConnCase, async: true

  alias Messngr.Accounts
  alias SlackApi.SlackId

  setup %{conn: conn} do
    {:ok, account} =
      Accounts.create_account(%{"display_name" => "Acme", "profile_name" => "Alice"})

    current_profile = hd(account.profiles)

    authed_conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("x-account-id", account.id)
      |> put_req_header("x-profile-id", current_profile.id)

    {:ok, conn: authed_conn, account: account, current_profile: current_profile}
  end

  test "users.list returns all workspace members", %{conn: conn, account: account} do
    {:ok, _profile} = Accounts.create_profile(%{"account_id" => account.id, "name" => "Per"})

    response =
      conn
      |> get(~p"/api/users.list")
      |> json_response(200)

    ids = Enum.map(response["members"], & &1["id"])
    assert SlackId.profile(hd(account.profiles)) in ids
  end

  test "users.info returns a single member", %{
    conn: conn,
    current_profile: profile,
    account: account
  } do
    response =
      conn
      |> get(~p"/api/users.info", %{user: SlackId.profile(profile)})
      |> json_response(200)

    assert response["ok"]
    assert response["user"]["id"] == SlackId.profile(profile)
    assert response["user"]["team_id"] == SlackId.team(account)
  end
end
