defmodule Messngr.Media.VirusScan do
  @moduledoc """
  Orchestrates asynchronous virus scanning for team media uploads.

  Flow:
  1. Client finishes PUT → `complete_upload/2`
  2. Status set to `:scanning` and a Task is enqueued
  3. Object bytes are fetched from MinIO and scanned
  4. Clean → `:clean`; infected → quarantine + `:infected`
  """

  require Logger

  alias Messngr.Media.Storage
  alias Messngr.Metrics.Pipeline

  @doc """
  Marks upload as scanning and enqueues an async scan job.

  When scanning is disabled, the upload is marked `:clean` immediately.
  """
  def complete_upload(prefix, upload) when is_map(upload) do
    if enabled?() do
      with {:ok, upload} <-
             media_upload().update(prefix, upload, %{
               scan_status: :scanning,
               threat_name: nil,
               quarantine_key: nil
             }) do
        enqueue(prefix, upload.id)
        {:ok, upload}
      end
    else
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      media_upload().update(prefix, upload, %{
        scan_status: :clean,
        scanned_at: now,
        threat_name: nil
      })
    end
  end

  @doc "Enqueue scan for an existing upload id (idempotent enough for retries)."
  def enqueue(prefix, upload_id) do
    Task.Supervisor.start_child(Messngr.TaskSupervisor, fn ->
      scan_upload(prefix, upload_id)
    end)

    :ok
  end

  @doc "Synchronously scan an upload (used by tests and the async worker)."
  def scan_upload(prefix, upload_id) do
    case media_upload().get_by_id(prefix, upload_id) do
      nil ->
        {:error, :not_found}

      upload ->
        do_scan(prefix, upload)
    end
  end

  @doc """
  Authorize download based on scan status.

  Returns `:ok`, `{:error, :scan_pending}`, or `{:error, :infected}`.
  When scanning is disabled, any non-infected upload is allowed.
  """
  def authorize_download(upload) when is_map(upload) do
    status = Map.get(upload, :scan_status)

    cond do
      status == :clean ->
        :ok

      status == :infected ->
        {:error, :infected}

      not enabled?() ->
        :ok

      status in [:awaiting_upload, :scanning, :error] ->
        {:error, :scan_pending}

      true ->
        {:error, :scan_pending}
    end
  end

  defp do_scan(prefix, upload) do
    started = System.monotonic_time(:millisecond)
    bucket = Storage.bucket()

    result =
      case fetch_object(bucket, upload.object_key) do
        {:ok, body} ->
          scanner().scan_bytes(body, scanner_opts())

        {:error, reason} ->
          {:error, reason}
      end

    duration = System.monotonic_time(:millisecond) - started
    finish(prefix, upload, bucket, result, duration)
  end

  defp finish(prefix, upload, bucket, :clean, duration) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, updated} =
      media_upload().update(prefix, upload, %{
        scan_status: :clean,
        scanned_at: now,
        threat_name: nil
      })

    emit_metric(duration, :clean, upload)
    broadcast(prefix, updated)
    {:ok, updated}
  end

  defp finish(prefix, upload, bucket, {:infected, threat}, duration) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    quarantine_key = quarantine_key(upload.object_key)

    _ = quarantine_object(bucket, upload.object_key, quarantine_key)

    {:ok, updated} =
      media_upload().update(prefix, upload, %{
        scan_status: :infected,
        scanned_at: now,
        threat_name: threat,
        quarantine_key: quarantine_key
      })

    emit_metric(duration, :infected, upload, threat)
    notify_detection(prefix, updated)
    broadcast(prefix, updated)
    {:ok, updated}
  end

  defp finish(prefix, upload, _bucket, {:error, reason}, duration) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Logger.warning("media virus scan failed",
      upload_id: upload.id,
      object_key: upload.object_key,
      reason: inspect(reason)
    )

    {:ok, updated} =
      media_upload().update(prefix, upload, %{
        scan_status: :error,
        scanned_at: now
      })

    emit_metric(duration, :error, upload)
    broadcast(prefix, updated)
    {:error, reason}
  end

  # Runtime lookup avoids compile-time dependency on the Teams app.
  defp media_upload, do: Teams.TenantModels.MediaUpload

  defp fetch_object(bucket, object_key) do
    case config(:fetch_object, nil) do
      fun when is_function(fun, 2) -> fun.(bucket, object_key)
      _ -> Storage.get_object(bucket, object_key)
    end
  end

  defp quarantine_object(bucket, object_key, quarantine_key) do
    case config(:quarantine_object, nil) do
      fun when is_function(fun, 3) -> fun.(bucket, object_key, quarantine_key)
      _ -> Storage.quarantine_object(bucket, object_key, quarantine_key)
    end
  end

  defp quarantine_key(object_key) do
    prefix = config(:quarantine_prefix, "quarantine/")
    prefix = if String.ends_with?(prefix, "/"), do: prefix, else: prefix <> "/"
    prefix <> object_key
  end

  defp notify_detection(prefix, upload) do
    Logger.error("malware detected in media upload",
      tenant_prefix: prefix,
      upload_id: upload.id,
      object_key: upload.object_key,
      threat_name: upload.threat_name,
      profile_id: upload.profile_id
    )
  end

  defp broadcast(prefix, upload) do
    # Best-effort realtime status for the uploader / team UIs.
    # Topic is intentionally tenant-scoped via prefix in the payload.
    if Process.whereis(MessngrWeb.Endpoint) do
      MessngrWeb.Endpoint.broadcast("media:#{prefix}", "media:scan_complete", %{
        upload_id: upload.id,
        object_key: upload.object_key,
        scan_status: upload.scan_status,
        threat_name: upload.threat_name
      })
    end

    :ok
  rescue
    _ -> :ok
  end

  defp emit_metric(duration_ms, result, upload, threat \\ nil) do
    Pipeline.emit_media_scan(duration_ms, %{
      result: result,
      upload_id: upload.id,
      content_type: upload.content_type,
      threat_name: threat
    })
  rescue
    _ -> :ok
  end

  defp scanner do
    config(:scanner, Messngr.Media.VirusScan.Clamd)
  end

  defp scanner_opts do
    [
      host: config(:host, "127.0.0.1"),
      port: config(:port, 3310),
      timeout: config(:timeout, 60_000)
    ]
  end

  defp enabled? do
    config(:enabled, false)
  end

  defp config(key, default) do
    Application.get_env(:msgr, __MODULE__, [])
    |> Keyword.get(key, default)
  end
end
