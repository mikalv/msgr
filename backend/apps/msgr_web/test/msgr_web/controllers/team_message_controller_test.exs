defmodule MessngrWeb.TeamMessageControllerTest do
  use MessngrWeb.ConnCase, async: false

  setup %{conn: conn} do
    ctx = setup_team(conn)

    # Create a channel for message tests
    create_conn =
      post(ctx.conn, "/api/teams/#{ctx.slug}/channels", %{
        name: "Messages",
        channel_slug: "messages-#{System.unique_integer([:positive])}"
      })

    %{"data" => %{"id" => channel_id}} = json_response(create_conn, 201)

    %{
      conn: ctx.conn,
      slug: ctx.slug,
      prefix: ctx.prefix,
      team_profile: ctx.team_profile,
      channel_id: channel_id,
      account: ctx.account,
      profile: ctx.profile
    }
  end

  describe "GET /api/teams/:slug/channels/:channel_id/messages" do
    test "returns empty list for channel with no messages", %{
      conn: conn,
      slug: slug,
      channel_id: channel_id
    } do
      conn = get(conn, "/api/teams/#{slug}/channels/#{channel_id}/messages")
      resp = json_response(conn, 200)

      assert resp["data"] == []
      assert is_map(resp["meta"])
    end

    test "returns messages with sender_profile", %{
      conn: conn,
      slug: slug,
      channel_id: channel_id
    } do
      # Send a message first
      post(conn, "/api/teams/#{slug}/channels/#{channel_id}/messages", %{
        content: %{text: "Hello team!"}
      })

      conn = get(conn, "/api/teams/#{slug}/channels/#{channel_id}/messages")
      resp = json_response(conn, 200)

      assert [msg | _] = resp["data"]
      assert msg["content"]["text"] == "Hello team!"
      assert is_map(msg["sender_profile"])
      assert msg["sender_profile"]["display_name"]
    end

    test "returns has_more metadata", %{conn: conn, slug: slug, channel_id: channel_id} do
      conn = get(conn, "/api/teams/#{slug}/channels/#{channel_id}/messages")
      resp = json_response(conn, 200)

      assert Map.has_key?(resp["meta"], "has_more")
    end

    test "supports limit parameter", %{conn: conn, slug: slug, channel_id: channel_id} do
      # Create two messages
      post(conn, "/api/teams/#{slug}/channels/#{channel_id}/messages", %{
        content: %{text: "Message 1"}
      })

      post(conn, "/api/teams/#{slug}/channels/#{channel_id}/messages", %{
        content: %{text: "Message 2"}
      })

      conn = get(conn, "/api/teams/#{slug}/channels/#{channel_id}/messages?limit=1")
      resp = json_response(conn, 200)

      assert length(resp["data"]) == 1
    end

    test "returns 401 without auth", %{slug: slug, channel_id: channel_id} do
      conn = build_conn()
      conn = get(conn, "/api/teams/#{slug}/channels/#{channel_id}/messages")
      assert json_response(conn, 401)
    end
  end

  describe "POST /api/teams/:slug/channels/:channel_id/messages" do
    test "creates a message with content map", %{conn: conn, slug: slug, channel_id: channel_id} do
      conn =
        post(conn, "/api/teams/#{slug}/channels/#{channel_id}/messages", %{
          content: %{text: "Hello!"}
        })

      resp = json_response(conn, 201)
      assert resp["data"]["content"]["text"] == "Hello!"
      assert resp["data"]["channel_id"] == channel_id
      assert is_binary(resp["data"]["id"])
      assert is_binary(resp["data"]["inserted_at"])
    end

    test "message includes sender_profile", %{conn: conn, slug: slug, channel_id: channel_id} do
      conn =
        post(conn, "/api/teams/#{slug}/channels/#{channel_id}/messages", %{
          content: %{text: "With profile"}
        })

      resp = json_response(conn, 201)
      assert resp["data"]["sender_profile"]["display_name"]
    end

    test "creates a thread reply", %{conn: conn, slug: slug, channel_id: channel_id} do
      # Create parent message
      parent_conn =
        post(conn, "/api/teams/#{slug}/channels/#{channel_id}/messages", %{
          content: %{text: "Parent message"}
        })

      %{"data" => %{"id" => parent_id}} = json_response(parent_conn, 201)

      # Create reply
      reply_conn =
        post(conn, "/api/teams/#{slug}/channels/#{channel_id}/messages", %{
          content: %{text: "Thread reply"},
          thread_parent_id: parent_id
        })

      resp = json_response(reply_conn, 201)
      assert resp["data"]["thread_parent_id"] == parent_id
    end

    test "returns 401 without auth", %{slug: slug, channel_id: channel_id} do
      conn = build_conn()

      conn =
        post(conn, "/api/teams/#{slug}/channels/#{channel_id}/messages", %{
          content: %{text: "Nope"}
        })

      assert json_response(conn, 401)
    end
  end

  describe "GET /api/teams/:slug/channels/:channel_id/threads/:message_id" do
    test "returns parent and replies", %{conn: conn, slug: slug, channel_id: channel_id} do
      # Create parent
      parent_conn =
        post(conn, "/api/teams/#{slug}/channels/#{channel_id}/messages", %{
          content: %{text: "Thread parent"}
        })

      %{"data" => %{"id" => parent_id}} = json_response(parent_conn, 201)

      # Create replies
      post(conn, "/api/teams/#{slug}/channels/#{channel_id}/messages", %{
        content: %{text: "Reply 1"},
        thread_parent_id: parent_id
      })

      post(conn, "/api/teams/#{slug}/channels/#{channel_id}/messages", %{
        content: %{text: "Reply 2"},
        thread_parent_id: parent_id
      })

      conn = get(conn, "/api/teams/#{slug}/channels/#{channel_id}/threads/#{parent_id}")
      resp = json_response(conn, 200)

      assert resp["data"]["parent"]["id"] == parent_id
      assert resp["data"]["parent"]["content"]["text"] == "Thread parent"
      assert length(resp["data"]["replies"]) == 2
    end

    test "returns 404 for nonexistent message", %{conn: conn, slug: slug, channel_id: channel_id} do
      fake_id = Ecto.UUID.generate()
      conn = get(conn, "/api/teams/#{slug}/channels/#{channel_id}/threads/#{fake_id}")
      assert json_response(conn, 404)
    end
  end
end
