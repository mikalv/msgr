defmodule MessngrWeb.TeamDmControllerTest do
  use MessngrWeb.ConnCase, async: false

  setup %{conn: conn} do
    ctx = setup_team(conn)

    # Create a second account and join the team so we have someone to DM
    {:ok, other_account} = Messngr.Accounts.create_account(%{"display_name" => "DM Partner"})
    other_profile = hd(other_account.profiles)
    other_conn = build_conn() |> attach_jwt_session(other_account, other_profile)
    Phoenix.ConnTest.post(other_conn, "/api/teams/#{ctx.slug}/join")

    other_team_profile =
      Teams.TeamManagement.get_profile_for_account(ctx.prefix, other_account.id)

    %{
      conn: ctx.conn,
      slug: ctx.slug,
      prefix: ctx.prefix,
      team_profile: ctx.team_profile,
      other_team_profile: other_team_profile
    }
  end

  describe "POST /api/teams/:slug/dms" do
    test "creates DM channel between profiles", %{
      conn: conn,
      slug: slug,
      other_team_profile: other
    } do
      conn =
        post(conn, "/api/teams/#{slug}/dms", %{
          profile_ids: [other.id]
        })

      resp = json_response(conn, 201)
      assert resp["data"]["id"]
      assert resp["data"]["kind"] == "dm"
    end

    test "returns channel with expected fields", %{
      conn: conn,
      slug: slug,
      other_team_profile: other
    } do
      conn =
        post(conn, "/api/teams/#{slug}/dms", %{
          profile_ids: [other.id]
        })

      channel = json_response(conn, 201)["data"]
      assert Map.has_key?(channel, "id")
      assert Map.has_key?(channel, "name")
      assert Map.has_key?(channel, "slug")
      assert Map.has_key?(channel, "kind")
      assert Map.has_key?(channel, "visibility")
      assert Map.has_key?(channel, "inserted_at")
    end

    test "deduplicates — creating same DM twice returns same channel", %{
      conn: conn,
      slug: slug,
      other_team_profile: other
    } do
      conn1 =
        post(conn, "/api/teams/#{slug}/dms", %{
          profile_ids: [other.id]
        })

      %{"data" => %{"id" => id1}} = json_response(conn1, 201)

      conn2 =
        post(conn, "/api/teams/#{slug}/dms", %{
          profile_ids: [other.id]
        })

      %{"data" => %{"id" => id2}} = json_response(conn2, 201)
      assert id1 == id2
    end

    test "returns 401 without auth", %{slug: slug, other_team_profile: other} do
      conn = build_conn()

      conn =
        post(conn, "/api/teams/#{slug}/dms", %{
          profile_ids: [other.id]
        })

      assert json_response(conn, 401)
    end
  end
end
