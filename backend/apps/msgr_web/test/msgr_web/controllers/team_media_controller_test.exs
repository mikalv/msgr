defmodule MessngrWeb.TeamMediaControllerTest do
  use MessngrWeb.ConnCase, async: false

  setup %{conn: conn} do
    ctx = setup_team(conn)
    %{conn: ctx.conn, slug: ctx.slug, prefix: ctx.prefix}
  end

  describe "POST /api/teams/:slug/media/presign" do
    test "returns upload_url and object_key", %{conn: conn, slug: slug} do
      conn =
        post(conn, "/api/teams/#{slug}/media/presign", %{
          filename: "photo.jpg",
          content_type: "image/jpeg",
          size: 1024
        })

      resp = json_response(conn, 201)
      assert resp["data"]["upload_url"]
      assert resp["data"]["object_key"]
      assert resp["data"]["upload_method"] == "PUT"
      assert resp["data"]["upload_id"]
      assert resp["data"]["expires_at"]
    end

    test "validates file size <= 50 MB", %{conn: conn, slug: slug} do
      over_limit = 50 * 1024 * 1024 + 1

      conn =
        post(conn, "/api/teams/#{slug}/media/presign", %{
          filename: "huge.bin",
          content_type: "application/octet-stream",
          size: over_limit
        })

      resp = json_response(conn, 413)
      assert resp["error"] == "file_too_large"
      assert resp["max_size"] == 50 * 1024 * 1024
    end

    test "accepts file at exactly 50 MB", %{conn: conn, slug: slug} do
      exactly_limit = 50 * 1024 * 1024

      conn =
        post(conn, "/api/teams/#{slug}/media/presign", %{
          filename: "exact.bin",
          content_type: "application/octet-stream",
          size: exactly_limit
        })

      resp = json_response(conn, 201)
      assert resp["data"]["upload_url"]
    end

    test "rejects file with size 0", %{conn: conn, slug: slug} do
      conn =
        post(conn, "/api/teams/#{slug}/media/presign", %{
          filename: "empty.txt",
          content_type: "text/plain",
          size: 0
        })

      resp = json_response(conn, 400)
      assert resp["error"] == "invalid_size"
    end

    test "rejects file with negative size", %{conn: conn, slug: slug} do
      conn =
        post(conn, "/api/teams/#{slug}/media/presign", %{
          filename: "negative.txt",
          content_type: "text/plain",
          size: -100
        })

      resp = json_response(conn, 400)
      assert resp["error"] == "invalid_size"
    end

    test "returns 401 without auth", %{slug: slug} do
      conn = build_conn()

      conn =
        post(conn, "/api/teams/#{slug}/media/presign", %{
          filename: "nope.txt",
          size: 100
        })

      assert json_response(conn, 401)
    end

    test "works without explicit size param", %{conn: conn, slug: slug} do
      conn =
        post(conn, "/api/teams/#{slug}/media/presign", %{
          filename: "no-size.txt",
          content_type: "text/plain"
        })

      resp = json_response(conn, 201)
      assert resp["data"]["object_key"]
    end
  end
end
