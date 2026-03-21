defmodule MessngrWeb.TeamReactionControllerTest do
  use MessngrWeb.ConnCase, async: false

  setup %{conn: conn} do
    ctx = setup_team(conn)

    # Create a channel and a message for reaction tests
    create_ch =
      post(ctx.conn, "/api/teams/#{ctx.slug}/channels", %{
        name: "Reactions",
        channel_slug: "reactions-#{System.unique_integer([:positive])}"
      })

    %{"data" => %{"id" => channel_id}} = json_response(create_ch, 201)

    create_msg =
      post(ctx.conn, "/api/teams/#{ctx.slug}/channels/#{channel_id}/messages", %{
        content: %{text: "React to this"}
      })

    %{"data" => %{"id" => message_id}} = json_response(create_msg, 201)

    %{
      conn: ctx.conn,
      slug: ctx.slug,
      channel_id: channel_id,
      message_id: message_id
    }
  end

  describe "POST /api/teams/:slug/channels/:channel_id/messages/:message_id/reactions" do
    test "adds a reaction", %{conn: conn, slug: slug, channel_id: channel_id, message_id: message_id} do
      conn =
        post(
          conn,
          "/api/teams/#{slug}/channels/#{channel_id}/messages/#{message_id}/reactions",
          %{emoji: "👍"}
        )

      resp = json_response(conn, 201)
      assert resp["data"]["action"] == "added"
      assert resp["data"]["emoji"] == "👍"
      assert resp["data"]["message_id"] == message_id
    end

    test "toggles reaction off when called twice", %{
      conn: conn,
      slug: slug,
      channel_id: channel_id,
      message_id: message_id
    } do
      path = "/api/teams/#{slug}/channels/#{channel_id}/messages/#{message_id}/reactions"

      # First toggle: add
      add_conn = post(conn, path, %{emoji: "🔥"})
      assert json_response(add_conn, 201)["data"]["action"] == "added"

      # Second toggle: remove
      remove_conn = post(conn, path, %{emoji: "🔥"})
      resp = json_response(remove_conn, 200)
      assert resp["data"]["action"] == "removed"
      assert resp["data"]["emoji"] == "🔥"
    end

    test "returns 401 without auth", %{slug: slug, channel_id: channel_id, message_id: message_id} do
      conn = build_conn()

      conn =
        post(
          conn,
          "/api/teams/#{slug}/channels/#{channel_id}/messages/#{message_id}/reactions",
          %{emoji: "👍"}
        )

      assert json_response(conn, 401)
    end

    test "returns 400 without emoji param", %{
      conn: conn,
      slug: slug,
      channel_id: channel_id,
      message_id: message_id
    } do
      conn =
        post(
          conn,
          "/api/teams/#{slug}/channels/#{channel_id}/messages/#{message_id}/reactions",
          %{}
        )

      assert json_response(conn, 400)
    end
  end
end
