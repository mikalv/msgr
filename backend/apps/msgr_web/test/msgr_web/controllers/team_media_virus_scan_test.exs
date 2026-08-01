defmodule MessngrWeb.TeamMediaVirusScanTest do
  use MessngrWeb.ConnCase, async: false

  alias Messngr.Media.VirusScan
  alias Teams.TenantModels.MediaUpload

  setup %{conn: conn} do
    ctx = setup_team(conn)

    on_exit(fn ->
      Application.put_env(:msgr, VirusScan,
        enabled: true,
        scanner: Messngr.Media.VirusScan.Passthrough,
        fetch_object: fn _b, _k -> {:ok, "test-bytes"} end,
        quarantine_object: fn _b, _k, _q -> :ok end,
        quarantine_prefix: "quarantine/"
      )
    end)

    %{
      conn: ctx.conn,
      slug: ctx.slug,
      prefix: ctx.prefix,
      team: ctx.team,
      profile: ctx.team_profile
    }
  end

  test "download blocked until scan is clean", %{
    conn: conn,
    slug: slug,
    prefix: prefix,
    team: team,
    profile: profile
  } do
    object_key = "teams/#{team.id}/#{Ecto.UUID.generate()}/pending.pdf"

    {:ok, upload} =
      MediaUpload.create(prefix, %{
        profile_id: profile.id,
        object_key: object_key,
        content_type: "application/pdf",
        filename: "pending.pdf",
        size: 10,
        scan_status: :awaiting_upload
      })

    encoded = URI.encode(object_key, &URI.char_unreserved?/1)
    pending = get(conn, "/api/teams/#{slug}/media/#{encoded}/url")
    assert json_response(pending, 423)["error"] == "scan_pending"

    {:ok, _} = MediaUpload.update(prefix, upload, %{scan_status: :clean})
    allowed = get(conn, "/api/teams/#{slug}/media/#{encoded}/url")
    assert json_response(allowed, 200)["data"]["download_url"]
  end

  test "download forbidden for infected media", %{
    conn: conn,
    slug: slug,
    prefix: prefix,
    team: team,
    profile: profile
  } do
    object_key = "teams/#{team.id}/#{Ecto.UUID.generate()}/bad.pdf"

    {:ok, _} =
      MediaUpload.create(prefix, %{
        profile_id: profile.id,
        object_key: object_key,
        content_type: "application/pdf",
        filename: "bad.pdf",
        size: 10,
        scan_status: :infected,
        threat_name: "Eicar-Test-Signature"
      })

    encoded = URI.encode(object_key, &URI.char_unreserved?/1)
    conn = get(conn, "/api/teams/#{slug}/media/#{encoded}/url")
    assert json_response(conn, 403)["error"] == "infected"
  end

  test "complete marks upload scanning then clean via passthrough", %{
    conn: conn,
    slug: slug,
    prefix: prefix,
    team: team,
    profile: profile
  } do
    object_key = "teams/#{team.id}/#{Ecto.UUID.generate()}/doc.pdf"

    {:ok, upload} =
      MediaUpload.create(prefix, %{
        profile_id: profile.id,
        object_key: object_key,
        content_type: "application/pdf",
        filename: "doc.pdf",
        size: 10,
        scan_status: :awaiting_upload
      })

    complete = post(conn, "/api/teams/#{slug}/media/#{upload.id}/complete")
    resp = json_response(complete, 200)
    assert resp["data"]["scan_status"] in ["scanning", "clean"]

    Process.sleep(150)
    reloaded = MediaUpload.get_by_id(prefix, upload.id)
    assert reloaded.scan_status == :clean
  end

  test "scan_upload quarantines infected files", %{prefix: prefix, team: team, profile: profile} do
    Application.put_env(:msgr, VirusScan,
      enabled: true,
      scanner: Messngr.Media.VirusScan.InfectedStub,
      fetch_object: fn _b, _k -> {:ok, "eicar"} end,
      quarantine_object: fn _b, _k, _q -> :ok end,
      quarantine_prefix: "quarantine/"
    )

    {:ok, upload} =
      MediaUpload.create(prefix, %{
        profile_id: profile.id,
        object_key: "teams/#{team.id}/#{Ecto.UUID.generate()}/eicar.bin",
        content_type: "application/octet-stream",
        filename: "eicar.bin",
        size: 68,
        scan_status: :scanning
      })

    assert {:ok, updated} = VirusScan.scan_upload(prefix, upload.id)
    assert updated.scan_status == :infected
    assert updated.threat_name == "Eicar-Test-Signature"
    assert String.starts_with?(updated.quarantine_key, "quarantine/")
  end

  test "authorize_download gates statuses", %{profile: profile, prefix: prefix, team: team} do
    {:ok, upload} =
      MediaUpload.create(prefix, %{
        profile_id: profile.id,
        object_key: "teams/#{team.id}/#{Ecto.UUID.generate()}/x.bin",
        content_type: "application/octet-stream",
        filename: "x.bin",
        size: 1,
        scan_status: :awaiting_upload
      })

    assert {:error, :scan_pending} = VirusScan.authorize_download(upload)
    assert :ok = VirusScan.authorize_download(%{upload | scan_status: :clean})
    assert {:error, :infected} = VirusScan.authorize_download(%{upload | scan_status: :infected})
  end
end
