defmodule MessngrWeb.TeamChannelControllerTest do
  use MessngrWeb.ConnCase, async: false

  setup %{conn: conn} do
    ctx = setup_team(conn)
    %{conn: ctx.conn, slug: ctx.slug, prefix: ctx.prefix, team_profile: ctx.team_profile}
  end

  describe "GET /api/teams/:slug/channels" do
    test "lists channels for the team", %{conn: conn, slug: slug} do
      conn = get(conn, "/api/teams/#{slug}/channels")
      resp = json_response(conn, 200)

      assert is_list(resp["data"])
      # The team is seeded with a #general channel
      assert Enum.any?(resp["data"], &(&1["slug"] == "general"))
    end

    test "returns channel fields", %{conn: conn, slug: slug} do
      conn = get(conn, "/api/teams/#{slug}/channels")
      [channel | _] = json_response(conn, 200)["data"]

      assert Map.has_key?(channel, "id")
      assert Map.has_key?(channel, "name")
      assert Map.has_key?(channel, "slug")
      assert Map.has_key?(channel, "visibility")
      assert Map.has_key?(channel, "inserted_at")
    end

    test "returns 401 without auth", %{slug: slug} do
      conn = build_conn()
      conn = get(conn, "/api/teams/#{slug}/channels")
      assert json_response(conn, 401)
    end

    test "returns 404 with wrong team slug", %{conn: conn} do
      conn = get(conn, "/api/teams/nonexistent-slug-999/channels")
      assert json_response(conn, 404)
    end
  end

  describe "POST /api/teams/:slug/channels" do
    test "creates a channel with name and visibility", %{conn: conn, slug: slug} do
      channel_slug = "dev-#{System.unique_integer([:positive])}"

      conn =
        post(conn, "/api/teams/#{slug}/channels", %{
          name: "Development",
          channel_slug: channel_slug,
          visibility: "private"
        })

      resp = json_response(conn, 201)
      assert resp["data"]["name"] == "Development"
      assert resp["data"]["slug"] == channel_slug
      assert resp["data"]["visibility"] == "private"
    end

    test "auto-generates slug from name when channel_slug is omitted", %{conn: conn, slug: slug} do
      conn =
        post(conn, "/api/teams/#{slug}/channels", %{
          name: "My Channel"
        })

      resp = json_response(conn, 201)
      assert resp["data"]["name"] == "My Channel"
      assert resp["data"]["slug"] == "my-channel"
    end

    test "creates a channel with icon", %{conn: conn, slug: slug} do
      conn =
        post(conn, "/api/teams/#{slug}/channels", %{
          name: "Random",
          channel_slug: "random-#{System.unique_integer([:positive])}",
          icon: "🎲"
        })

      resp = json_response(conn, 201)
      assert resp["data"]["icon"] == "🎲"
    end

    test "creates a channel with topic", %{conn: conn, slug: slug} do
      conn =
        post(conn, "/api/teams/#{slug}/channels", %{
          name: "Announcements",
          channel_slug: "announce-#{System.unique_integer([:positive])}",
          topic: "Team announcements only"
        })

      resp = json_response(conn, 201)
      assert resp["data"]["topic"] == "Team announcements only"
    end

    test "returns 401 without auth", %{slug: slug} do
      conn = build_conn()

      conn =
        post(conn, "/api/teams/#{slug}/channels", %{
          name: "Nope",
          channel_slug: "nope"
        })

      assert json_response(conn, 401)
    end
  end

  describe "POST /api/teams/:slug/channels/:id/members" do
    test "adds members to a channel", %{conn: conn, slug: slug, prefix: prefix} do
      # Create a channel
      create_conn =
        post(conn, "/api/teams/#{slug}/channels", %{
          name: "Members Test",
          channel_slug: "members-test-#{System.unique_integer([:positive])}"
        })

      %{"data" => %{"id" => channel_id}} = json_response(create_conn, 201)

      # Create a second account and join the team
      {:ok, other_account} = Messngr.Accounts.create_account(%{"display_name" => "Other User"})
      other_profile = hd(other_account.profiles)
      other_conn = build_conn() |> attach_jwt_session(other_account, other_profile)
      post(other_conn, "/api/teams/#{slug}/join")

      other_team_profile = Teams.TeamManagement.get_profile_for_account(prefix, other_account.id)

      conn =
        post(conn, "/api/teams/#{slug}/channels/#{channel_id}/members", %{
          profile_ids: [other_team_profile.id]
        })

      resp = json_response(conn, 201)
      assert resp["data"]["added"] == 1
    end

    test "returns 422 when profile_ids is empty", %{conn: conn, slug: slug} do
      create_conn =
        post(conn, "/api/teams/#{slug}/channels", %{
          name: "Empty Members",
          channel_slug: "empty-members-#{System.unique_integer([:positive])}"
        })

      %{"data" => %{"id" => channel_id}} = json_response(create_conn, 201)

      conn =
        post(conn, "/api/teams/#{slug}/channels/#{channel_id}/members", %{
          profile_ids: []
        })

      assert json_response(conn, 422)
    end
  end
end
