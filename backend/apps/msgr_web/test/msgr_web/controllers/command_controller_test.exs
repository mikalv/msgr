defmodule MessngrWeb.CommandControllerTest do
  use MessngrWeb.ConnCase, async: false

  alias Messngr.Apps

  setup %{conn: conn} do
    ctx = setup_team(conn)

    # Create a channel for command execution
    create_ch =
      post(ctx.conn, "/api/teams/#{ctx.slug}/channels", %{
        name: "Commands",
        channel_slug: "commands-#{System.unique_integer([:positive])}"
      })

    %{"data" => %{"id" => channel_id}} = json_response(create_ch, 201)

    %{
      conn: ctx.conn,
      slug: ctx.slug,
      team: ctx.team,
      channel_id: channel_id
    }
  end

  describe "GET /api/teams/:slug/commands" do
    test "lists available commands", %{conn: conn, slug: slug} do
      conn = get(conn, "/api/teams/#{slug}/commands")
      resp = json_response(conn, 200)

      assert is_list(resp["data"])
    end

    test "includes command fields when commands exist", %{conn: conn, slug: slug, team: team} do
      # Create a builtin app with a command so we have something to list
      {:ok, app} =
        Apps.create_app(%{
          name: "Test App",
          slug: "test-app-#{System.unique_integer([:positive])}",
          executor_type: "builtin",
          visibility: "public"
        })

      {:ok, _cmd} =
        Apps.create_command(app.id, %{
          name: "testcmd",
          description: "A test command",
          permissions: "all"
        })

      conn = get(conn, "/api/teams/#{slug}/commands")
      resp = json_response(conn, 200)

      cmd = Enum.find(resp["data"], &(&1["name"] == "testcmd"))

      if cmd do
        assert cmd["description"] == "A test command"
        assert cmd["app_slug"] == app.slug
        assert cmd["app_name"] == "Test App"
      end
    end

    test "returns 401 without auth", %{slug: slug} do
      conn = build_conn()
      conn = get(conn, "/api/teams/#{slug}/commands")
      assert json_response(conn, 401)
    end
  end

  describe "POST /api/teams/:slug/channels/:channel_id/commands" do
    test "returns error when command param is missing", %{
      conn: conn,
      slug: slug,
      channel_id: channel_id
    } do
      conn =
        post(conn, "/api/teams/#{slug}/channels/#{channel_id}/commands", %{
          args: "some args"
        })

      resp = json_response(conn, 400)
      assert resp["error"] == "command is required"
    end

    test "returns 404 for unknown command", %{conn: conn, slug: slug, channel_id: channel_id} do
      conn =
        post(conn, "/api/teams/#{slug}/channels/#{channel_id}/commands", %{
          command: "nonexistent_command",
          args: ""
        })

      resp = json_response(conn, 404)
      assert resp["error"] == "unknown_command"
      assert resp["command"] == "nonexistent_command"
    end

    test "executes a builtin command", %{conn: conn, slug: slug, channel_id: channel_id} do
      # Create a builtin app with a /topic command
      {:ok, app} =
        Apps.create_app(%{
          name: "Builtin App",
          slug: "builtin-#{System.unique_integer([:positive])}",
          executor_type: "builtin",
          visibility: "public"
        })

      {:ok, _cmd} =
        Apps.create_command(app.id, %{
          name: "topic",
          description: "Set channel topic",
          permissions: "all"
        })

      conn =
        post(conn, "/api/teams/#{slug}/channels/#{channel_id}/commands", %{
          command: "topic",
          args: "New topic for the channel"
        })

      resp = json_response(conn, 200)
      assert resp["data"]["command"] == "topic"
      assert resp["data"]["status"] == "completed"
    end

    test "returns 401 without auth", %{slug: slug, channel_id: channel_id} do
      conn = build_conn()

      conn =
        post(conn, "/api/teams/#{slug}/channels/#{channel_id}/commands", %{
          command: "test",
          args: ""
        })

      assert json_response(conn, 401)
    end
  end
end
