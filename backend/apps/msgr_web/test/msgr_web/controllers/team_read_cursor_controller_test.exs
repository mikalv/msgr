defmodule MessngrWeb.TeamReadCursorControllerTest do
  use MessngrWeb.ConnCase, async: false

  setup %{conn: conn} do
    ctx = setup_team(conn)

    # Create a channel and a message so we have a valid last_read_message_id
    create_ch =
      post(ctx.conn, "/api/teams/#{ctx.slug}/channels", %{
        name: "Read Cursors",
        channel_slug: "cursors-#{System.unique_integer([:positive])}"
      })

    %{"data" => %{"id" => channel_id}} = json_response(create_ch, 201)

    create_msg =
      post(ctx.conn, "/api/teams/#{ctx.slug}/channels/#{channel_id}/messages", %{
        content: %{text: "Mark me as read"}
      })

    %{"data" => %{"id" => message_id}} = json_response(create_msg, 201)

    %{
      conn: ctx.conn,
      slug: ctx.slug,
      channel_id: channel_id,
      message_id: message_id
    }
  end

  describe "PUT /api/teams/:slug/channels/:channel_id/read_cursor" do
    test "updates read cursor with last_read_message_id", %{
      conn: conn,
      slug: slug,
      channel_id: channel_id,
      message_id: message_id
    } do
      conn =
        put(
          conn,
          "/api/teams/#{slug}/channels/#{channel_id}/read_cursor",
          %{last_read_message_id: message_id}
        )

      resp = json_response(conn, 200)
      assert resp["data"]["channel_id"] == channel_id
      assert resp["data"]["last_read_message_id"] == message_id
      assert resp["data"]["profile_id"]
    end

    test "returns 401 without auth", %{slug: slug, channel_id: channel_id, message_id: message_id} do
      conn = build_conn()

      conn =
        put(
          conn,
          "/api/teams/#{slug}/channels/#{channel_id}/read_cursor",
          %{last_read_message_id: message_id}
        )

      assert json_response(conn, 401)
    end

    test "is idempotent — setting same cursor twice works", %{
      conn: conn,
      slug: slug,
      channel_id: channel_id,
      message_id: message_id
    } do
      path = "/api/teams/#{slug}/channels/#{channel_id}/read_cursor"
      params = %{last_read_message_id: message_id}

      # First call
      resp1 = put(conn, path, params) |> json_response(200)
      assert resp1["data"]["last_read_message_id"] == message_id

      # Second call with the same cursor — should succeed identically
      resp2 = put(conn, path, params) |> json_response(200)
      assert resp2["data"]["last_read_message_id"] == message_id
      assert resp2["data"]["channel_id"] == resp1["data"]["channel_id"]
      assert resp2["data"]["profile_id"] == resp1["data"]["profile_id"]
    end
  end
end
