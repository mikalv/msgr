defmodule MessngrWeb.TeamControllerTest do
  use MessngrWeb.ConnCase, async: true

  alias Messngr.Accounts

  setup %{conn: conn} do
    {:ok, account} = Accounts.create_account(%{"display_name" => "Team Tester"})
    profile = hd(account.profiles)
    conn = attach_jwt_session(conn, account, profile)

    %{conn: conn, account: account, profile: profile}
  end

  describe "POST /api/teams" do
    test "creates a team with JWT auth", %{conn: conn} do
      slug = "team-#{System.unique_integer([:positive])}"

      conn =
        post(conn, "/api/teams", %{
          name: "My Team",
          slug: slug
        })

      resp = json_response(conn, 201)
      assert resp["data"]["name"] == "My Team"
      assert resp["data"]["slug"] == slug
      assert is_binary(resp["data"]["id"])
    end

    test "returns 401 without JWT" do
      conn = build_conn()

      conn =
        post(conn, "/api/teams", %{
          name: "No Auth Team",
          slug: "no-auth-#{System.unique_integer([:positive])}"
        })

      assert json_response(conn, 401)
    end
  end

  describe "GET /api/teams" do
    test "lists teams for authenticated user", %{conn: conn} do
      slug = "list-team-#{System.unique_integer([:positive])}"
      post(conn, "/api/teams", %{name: "Listed Team", slug: slug})

      conn = get(conn, "/api/teams")
      resp = json_response(conn, 200)

      assert is_list(resp["data"])
      assert Enum.any?(resp["data"], &(&1["slug"] == slug))
    end

    test "returns 401 without JWT" do
      conn = build_conn()
      conn = get(conn, "/api/teams")
      assert json_response(conn, 401)
    end
  end

  describe "POST /api/teams/:slug/join" do
    test "joins a team", %{conn: conn} do
      slug = "join-team-#{System.unique_integer([:positive])}"
      post(conn, "/api/teams", %{name: "Joinable Team", slug: slug})

      # Create a second account and join as that account
      {:ok, other_account} = Accounts.create_account(%{"display_name" => "Joiner"})
      other_profile = hd(other_account.profiles)

      other_conn =
        build_conn()
        |> attach_jwt_session(other_account, other_profile)

      join_conn = post(other_conn, "/api/teams/#{slug}/join")
      resp = json_response(join_conn, 201)

      assert resp["data"]["team"]["slug"] == slug
      assert is_binary(resp["data"]["profile_id"])
    end

    test "returns 401 without JWT" do
      conn = build_conn()
      conn = post(conn, "/api/teams/some-slug/join")
      assert json_response(conn, 401)
    end
  end
end
