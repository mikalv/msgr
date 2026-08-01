defmodule MessngrWeb.TeamMediaVirusScanTest do
  use MessngrWeb.ConnCase, async: false

  alias Messngr.Media.VirusScan
  alias Teams.TenantModels.MediaUpload

  setup %{conn: conn} do
    ctx = setup_team(conn)

    put_scan_env(
      scanner: Messngr.Media.VirusScan.Passthrough,
      quarantine_object: fn _b, _k, _q -> :ok end
    )

    on_exit(fn ->
      put_scan_env(
        scanner: Messngr.Media.VirusScan.Passthrough,
        quarantine_object: fn _b, _k, _q -> :ok end
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
        scan_status: :awaiting_upload,
        scanned_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    complete = post(conn, "/api/teams/#{slug}/media/#{upload.id}/complete")
    resp = json_response(complete, 200)
    assert resp["data"]["scan_status"] in ["scanning", "clean"]

    # Retries clear stale scanned_at while scanning is in progress.
    if resp["data"]["scan_status"] == "scanning" do
      assert is_nil(resp["data"]["scanned_at"])
    end

    assert_scan_status(prefix, upload.id, :clean)
  end

  test "scan_upload quarantines infected files", %{prefix: prefix, team: team, profile: profile} do
    put_scan_env(
      scanner: Messngr.Media.VirusScan.InfectedStub,
      quarantine_object: fn _b, _k, _q -> :ok end
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

  test "scan_upload omits quarantine_key when quarantine copy fails", %{
    prefix: prefix,
    team: team,
    profile: profile
  } do
    put_scan_env(
      scanner: Messngr.Media.VirusScan.InfectedStub,
      quarantine_object: fn _b, _k, _q -> {:error, :copy_failed} end
    )

    {:ok, upload} =
      MediaUpload.create(prefix, %{
        profile_id: profile.id,
        object_key: "teams/#{team.id}/#{Ecto.UUID.generate()}/eicar2.bin",
        content_type: "application/octet-stream",
        filename: "eicar2.bin",
        size: 68,
        scan_status: :scanning
      })

    assert {:ok, updated} = VirusScan.scan_upload(prefix, upload.id)
    assert updated.scan_status == :infected
    assert is_nil(updated.quarantine_key)
  end

  test "scan_upload rejects oversized objects before loading body", %{
    prefix: prefix,
    team: team,
    profile: profile
  } do
    put_scan_env(
      scanner: Messngr.Media.VirusScan.Passthrough,
      head_object: fn _b, _k -> {:ok, %{content_length: 51 * 1024 * 1024}} end,
      fetch_object: fn _b, _k -> flunk("must not fetch oversized object") end
    )

    {:ok, upload} =
      MediaUpload.create(prefix, %{
        profile_id: profile.id,
        object_key: "teams/#{team.id}/#{Ecto.UUID.generate()}/huge.bin",
        content_type: "application/octet-stream",
        filename: "huge.bin",
        size: 10,
        scan_status: :scanning
      })

    assert {:error, :object_too_large} = VirusScan.scan_upload(prefix, upload.id)
    reloaded = MediaUpload.get_by_id(prefix, upload.id)
    assert reloaded.scan_status == :error
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

  test "complete rejects when scan queue is saturated", %{
    conn: conn,
    slug: slug,
    prefix: prefix,
    team: team,
    profile: profile
  } do
    put_scan_env(
      scanner: Messngr.Media.VirusScan.BlockingStub,
      max_concurrency: 1,
      max_queue: 0
    )

    {:ok, first} =
      MediaUpload.create(prefix, %{
        profile_id: profile.id,
        object_key: "teams/#{team.id}/#{Ecto.UUID.generate()}/a.bin",
        content_type: "application/octet-stream",
        filename: "a.bin",
        size: 1,
        scan_status: :awaiting_upload
      })

    {:ok, second} =
      MediaUpload.create(prefix, %{
        profile_id: profile.id,
        object_key: "teams/#{team.id}/#{Ecto.UUID.generate()}/b.bin",
        content_type: "application/octet-stream",
        filename: "b.bin",
        size: 1,
        scan_status: :awaiting_upload
      })

    first_resp = post(conn, "/api/teams/#{slug}/media/#{first.id}/complete")
    assert json_response(first_resp, 200)["data"]["scan_status"] == "scanning"

    # Give the worker a moment to start the blocking scan so capacity is consumed.
    Process.sleep(50)

    second_resp = post(conn, "/api/teams/#{slug}/media/#{second.id}/complete")
    assert json_response(second_resp, 503)["error"] == "scan_queue_full"

    reloaded = MediaUpload.get_by_id(prefix, second.id)
    assert reloaded.scan_status == :awaiting_upload
  end

  defp put_scan_env(overrides) do
    Application.put_env(
      :msgr,
      VirusScan,
      Keyword.merge(
        [
          enabled: true,
          scanner: Messngr.Media.VirusScan.Passthrough,
          head_object: fn _b, _k -> {:ok, %{content_length: 10}} end,
          fetch_object: fn _b, _k -> {:ok, "test-bytes"} end,
          quarantine_object: fn _b, _k, _q -> :ok end,
          delete_object: fn _b, _k -> :ok end,
          quarantine_prefix: "quarantine/",
          max_scan_bytes: 50 * 1024 * 1024,
          max_concurrency: 2,
          max_queue: 100
        ],
        overrides
      )
    )
  end

  defp assert_scan_status(prefix, upload_id, expected, attempts \\ 50) do
    Enum.reduce_while(1..attempts, nil, fn _, _ ->
      case MediaUpload.get_by_id(prefix, upload_id) do
        %{scan_status: ^expected} = upload ->
          {:halt, upload}

        _ ->
          Process.sleep(20)
          {:cont, nil}
      end
    end)
    |> case do
      %{scan_status: ^expected} = upload -> upload
      _ -> flunk("expected scan_status #{inspect(expected)} for #{upload_id}")
    end
  end
end
