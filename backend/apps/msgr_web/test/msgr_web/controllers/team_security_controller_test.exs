defmodule MessngrWeb.TeamSecurityControllerTest do
  use MessngrWeb.ConnCase, async: false

  alias Teams.Channels
  alias Teams.TeamManagement
  alias Teams.TenantModels.MediaUpload

  setup %{conn: conn} do
    owner_ctx = setup_team(conn)

    # Second authenticated user who is NOT a member of the owner's team
    {:ok, outsider_account} =
      Ecto.Adapters.SQL.Sandbox.unboxed_run(Messngr.Repo, fn ->
        Messngr.Accounts.create_account(%{
          "display_name" => "Outsider #{Ecto.UUID.generate()}"
        })
      end)

    outsider_profile = hd(outsider_account.profiles)
    outsider_conn = attach_jwt_session(build_conn(), outsider_account, outsider_profile)

    # Member of the team (non-admin)
    {:ok, member_account} =
      Ecto.Adapters.SQL.Sandbox.unboxed_run(Messngr.Repo, fn ->
        Messngr.Accounts.create_account(%{
          "display_name" => "Member #{Ecto.UUID.generate()}"
        })
      end)

    member_profile = hd(member_account.profiles)

    {:ok, %{profile: member_team_profile}} =
      TeamManagement.join_team(owner_ctx.team, member_account.id, %{
        display_name: "Member",
        role: "member"
      })

    member_conn = attach_jwt_session(build_conn(), member_account, member_profile)

    # Public channel (created by owner; creator auto-joined)
    create_public =
      post(owner_ctx.conn, "/api/teams/#{owner_ctx.slug}/channels", %{
        name: "Public Sec",
        channel_slug: "public-sec-#{System.unique_integer([:positive])}",
        visibility: "public"
      })

    %{"data" => %{"id" => public_channel_id}} = json_response(create_public, 201)

    # Private channel — only owner is a member
    create_private =
      post(owner_ctx.conn, "/api/teams/#{owner_ctx.slug}/channels", %{
        name: "Private Sec",
        channel_slug: "private-sec-#{System.unique_integer([:positive])}",
        visibility: "private"
      })

    %{"data" => %{"id" => private_channel_id}} = json_response(create_private, 201)

    %{
      owner: owner_ctx,
      outsider_conn: outsider_conn,
      member_conn: member_conn,
      member_team_profile: member_team_profile,
      public_channel_id: public_channel_id,
      private_channel_id: private_channel_id
    }
  end

  describe "RequireTeamMembership (SEC-2)" do
    test "non-member cannot list messages", %{
      outsider_conn: outsider_conn,
      owner: owner,
      public_channel_id: channel_id
    } do
      conn =
        get(outsider_conn, "/api/teams/#{owner.slug}/channels/#{channel_id}/messages")

      assert json_response(conn, 403)["error"] == "forbidden"
    end

    test "non-member cannot list channel members", %{
      outsider_conn: outsider_conn,
      owner: owner,
      public_channel_id: channel_id
    } do
      conn =
        get(outsider_conn, "/api/teams/#{owner.slug}/channels/#{channel_id}/members")

      assert json_response(conn, 403)["error"] == "forbidden"
    end

    test "non-member cannot request media download", %{
      outsider_conn: outsider_conn,
      owner: owner
    } do
      object_key = "teams/#{owner.team.id}/#{Ecto.UUID.generate()}/secret.pdf"
      encoded = URI.encode(object_key, &URI.char_unreserved?/1)

      conn = get(outsider_conn, "/api/teams/#{owner.slug}/media/#{encoded}/url")
      assert json_response(conn, 403)["error"] == "forbidden"
    end

    test "non-admin cannot add channel members", %{
      member_conn: member_conn,
      owner: owner,
      public_channel_id: channel_id,
      member_team_profile: member_team_profile
    } do
      conn =
        post(member_conn, "/api/teams/#{owner.slug}/channels/#{channel_id}/members", %{
          profile_ids: [member_team_profile.id]
        })

      assert json_response(conn, 403)["error"] == "forbidden"
    end

    test "non-admin cannot delete webhooks", %{
      member_conn: member_conn,
      owner: owner
    } do
      # Admin check happens before webhook lookup, so a random id is enough
      conn =
        delete(
          member_conn,
          "/api/teams/#{owner.slug}/webhooks/#{Ecto.UUID.generate()}"
        )

      assert json_response(conn, 403)["error"] == "forbidden"
    end
  end

  describe "channel authorization (SEC-5)" do
    test "team member who is not in private channel cannot read messages", %{
      member_conn: member_conn,
      member_team_profile: member_team_profile,
      owner: owner,
      private_channel_id: channel_id
    } do
      refute Channels.member?(owner.prefix, channel_id, member_team_profile.id)

      conn =
        get(member_conn, "/api/teams/#{owner.slug}/channels/#{channel_id}/messages")

      assert json_response(conn, 403)["error"] == "forbidden"
    end

    test "team member can read public channel messages", %{
      member_conn: member_conn,
      owner: owner,
      public_channel_id: channel_id
    } do
      conn =
        get(member_conn, "/api/teams/#{owner.slug}/channels/#{channel_id}/messages")

      assert json_response(conn, 200)
    end

    test "cannot access private message via authorized public channel_id", %{
      member_conn: member_conn,
      owner: owner,
      public_channel_id: public_channel_id,
      private_channel_id: private_channel_id
    } do
      create_msg =
        post(owner.conn, "/api/teams/#{owner.slug}/channels/#{private_channel_id}/messages", %{
          content: %{"text" => "secret private message"}
        })

      %{"data" => %{"id" => private_message_id}} = json_response(create_msg, 201)

      base = "/api/teams/#{owner.slug}/channels/#{public_channel_id}/messages/#{private_message_id}"

      # Cross-channel message_id must not leak via an authorized channel path
      assert json_response(get(member_conn, "/api/teams/#{owner.slug}/channels/#{public_channel_id}/threads/#{private_message_id}"), 404)[
               "error"
             ] == "not_found"

      assert json_response(
               patch(member_conn, base, %{content: %{"text" => "hijack"}}),
               404
             )["error"] == "not_found"

      assert json_response(delete(member_conn, base), 404)["error"] == "not_found"
      assert json_response(post(member_conn, "#{base}/pin"), 404)["error"] == "not_found"
      assert json_response(delete(member_conn, "#{base}/pin"), 404)["error"] == "not_found"

      assert json_response(
               post(member_conn, "#{base}/reactions", %{emoji: "👍"}),
               404
             )["error"] == "not_found"
    end
  end

  describe "media object_key validation (SEC-3)" do
    test "rejects object_key for another team", %{owner: owner} do
      # No MediaUpload row needed — prefix mismatch alone must forbid access
      other_team_id = Ecto.UUID.generate()
      foreign_key = "teams/#{other_team_id}/#{Ecto.UUID.generate()}/leak.pdf"
      encoded = URI.encode(foreign_key, &URI.char_unreserved?/1)

      conn = get(owner.conn, "/api/teams/#{owner.slug}/media/#{encoded}/url")
      assert json_response(conn, 403)["error"] == "forbidden"
    end

    test "rejects unknown object_key even with correct team prefix", %{owner: owner} do
      missing = "teams/#{owner.team.id}/#{Ecto.UUID.generate()}/missing.pdf"
      encoded = URI.encode(missing, &URI.char_unreserved?/1)

      conn = get(owner.conn, "/api/teams/#{owner.slug}/media/#{encoded}/url")
      assert json_response(conn, 404)["error"] == "not_found"
    end

    test "allows download for registered object_key in team", %{owner: owner} do
      object_key = "teams/#{owner.team.id}/#{Ecto.UUID.generate()}/ok.pdf"

      {:ok, _} =
        MediaUpload.create(owner.prefix, %{
          profile_id: owner.team_profile.id,
          object_key: object_key,
          content_type: "application/pdf",
          filename: "ok.pdf",
          size: 100,
          scan_status: :clean
        })

      encoded = URI.encode(object_key, &URI.char_unreserved?/1)
      conn = get(owner.conn, "/api/teams/#{owner.slug}/media/#{encoded}/url")
      resp = json_response(conn, 200)

      assert is_binary(resp["data"]["download_url"])
    end
  end
end
