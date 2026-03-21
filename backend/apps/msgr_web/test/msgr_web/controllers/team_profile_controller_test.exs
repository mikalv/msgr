defmodule MessngrWeb.TeamProfileControllerTest do
  use MessngrWeb.ConnCase, async: false

  setup %{conn: conn} do
    ctx = setup_team(conn)

    %{
      conn: ctx.conn,
      slug: ctx.slug,
      prefix: ctx.prefix,
      team_profile: ctx.team_profile,
      account: ctx.account,
      profile: ctx.profile
    }
  end

  describe "GET /api/teams/:slug/profiles" do
    test "lists team members", %{conn: conn, slug: slug, team_profile: team_profile} do
      conn = get(conn, "/api/teams/#{slug}/profiles")
      resp = json_response(conn, 200)

      assert is_list(resp["data"])
      assert Enum.any?(resp["data"], &(&1["id"] == team_profile.id))
    end

    test "includes profile fields", %{conn: conn, slug: slug} do
      conn = get(conn, "/api/teams/#{slug}/profiles")
      [profile | _] = json_response(conn, 200)["data"]

      assert Map.has_key?(profile, "id")
      assert Map.has_key?(profile, "display_name")
      assert Map.has_key?(profile, "role")
      assert Map.has_key?(profile, "account_id")
      assert Map.has_key?(profile, "inserted_at")
    end

    test "returns 401 without auth", %{slug: slug} do
      conn = build_conn()
      conn = get(conn, "/api/teams/#{slug}/profiles")
      assert json_response(conn, 401)
    end

    test "returns 404 with wrong slug", %{conn: conn} do
      conn = get(conn, "/api/teams/nonexistent-slug-999/profiles")
      assert json_response(conn, 404)
    end
  end

  describe "GET /api/teams/:slug/profiles/:id" do
    test "returns a single profile", %{conn: conn, slug: slug, team_profile: team_profile} do
      conn = get(conn, "/api/teams/#{slug}/profiles/#{team_profile.id}")
      resp = json_response(conn, 200)

      assert resp["data"]["id"] == team_profile.id
      assert resp["data"]["display_name"] == team_profile.display_name
    end

    test "returns 404 for nonexistent profile id", %{conn: conn, slug: slug} do
      fake_id = Ecto.UUID.generate()
      conn = get(conn, "/api/teams/#{slug}/profiles/#{fake_id}")
      assert json_response(conn, 404)
    end
  end

  describe "PUT /api/teams/:slug/profiles/me" do
    test "updates own profile display_name", %{conn: conn, slug: slug} do
      conn =
        put(conn, "/api/teams/#{slug}/profiles/me", %{
          display_name: "New Display Name"
        })

      resp = json_response(conn, 200)
      assert resp["data"]["display_name"] == "New Display Name"
    end

    test "updates avatar_url", %{conn: conn, slug: slug} do
      conn =
        put(conn, "/api/teams/#{slug}/profiles/me", %{
          avatar_url: "https://example.com/avatar.png"
        })

      resp = json_response(conn, 200)
      assert resp["data"]["avatar_url"] == "https://example.com/avatar.png"
    end

    test "updates email and phone", %{conn: conn, slug: slug} do
      conn =
        put(conn, "/api/teams/#{slug}/profiles/me", %{
          email: "test@example.com",
          phone: "+4712345678"
        })

      resp = json_response(conn, 200)
      assert resp["data"]["email"] == "test@example.com"
      assert resp["data"]["phone"] == "+4712345678"
    end

    test "returns 401 without auth", %{slug: slug} do
      conn = build_conn()
      conn = put(conn, "/api/teams/#{slug}/profiles/me", %{display_name: "Nope"})
      assert json_response(conn, 401)
    end
  end
end
