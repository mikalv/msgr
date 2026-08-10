# Team media: ClamAV virus scan

Operational notes for the async malware scan pipeline on **team** uploads
(`#197` / `#233`). Personal conversation media (`MediaUploadController`) is out
of scope — it does not run through this scanner today.

## Intent

Keep MinIO objects that team clients can download free of known malware:

1. Client gets a presigned PUT URL.
2. Client uploads bytes to object storage.
3. Client calls `complete`; the API enqueues a bounded scan job.
4. Download URLs are only issued for `scan_status: clean`.

When scanning is disabled (`CLAMAV_ENABLED=false`), `complete` marks the upload
`:clean` immediately so local/dev stacks without ClamAV still work.

## Architecture

| Piece | Role |
|-------|------|
| `MessngrWeb.TeamMediaController` | Presign / complete / download gate |
| `Teams.TenantModels.MediaUpload` | Tenant-scoped metadata + scan fields |
| `Messngr.Media.VirusScan` | Orchestration, size limit, quarantine, metrics |
| `Messngr.Media.VirusScan.Worker` | Bounded queue (`max_concurrency` + `max_queue`) |
| `Messngr.Media.VirusScan.Clamd` | TCP `INSTREAM` client to clamd |
| `Messngr.Media.VirusScan.Passthrough` | Always-clean scanner for tests |
| `Messngr.Media.Storage` | MinIO HEAD/GET/DELETE + quarantine copy |

Flow:

```
presign → awaiting_upload
       → client PUT to MinIO
complete → scanning (or clean if disabled)
       → Worker → scan_bytes
         → clean | infected (+ quarantine) | error
download_url → authorize_download (clean only when enabled)
```

Realtime: on finish, best-effort broadcast on topic `media:<tenant_prefix>` with
event `media:scan_complete` (`upload_id`, `object_key`, `scan_status`,
`threat_name`). Metrics: telemetry `[:msgr, :media, :scan, :stop]` via
`Messngr.Metrics.Pipeline.emit_media_scan/2`.

## HTTP API

All routes are under `/api/teams/:slug` (pipes: `:api`, `:actor`, `:tenant`).

### `POST /media/presign`

Body fields: `filename`, `content_type`, `size` (bytes). Max size **50 MiB**
(`413` + `file_too_large` when exceeded).

**201** (shape):

```json
{
  "data": {
    "upload_id": "…",
    "object_key": "teams/<team_id>/<uuid>/<filename>",
    "upload_url": "https://…",
    "upload_headers": { "content-type": "…" },
    "upload_method": "PUT",
    "scan_status": "awaiting_upload",
    "expires_at": "2026-08-10T12:00:00Z"
  }
}
```

### `POST /media/:upload_id/complete`

Caller must own the upload (`profile_id`). Idempotent once status is
`scanning` / `clean` / `infected`.

**200** (shape):

```json
{
  "data": {
    "upload_id": "…",
    "object_key": "…",
    "scan_status": "scanning",
    "threat_name": null,
    "scanned_at": null
  }
}
```

| Error | HTTP | When |
|-------|------|------|
| `scan_queue_full` | 503 | Worker queue at capacity or worker down; status reverted to `awaiting_upload` |
| `forbidden` | 403 | Upload belongs to another profile |
| `not_found` | 404 | Unknown `upload_id` |

### `GET /media/:object_key/url`

`object_key` is URI-encoded. Must start with `teams/<team_id>/`.

| Result | HTTP | Notes |
|--------|------|-------|
| Presigned GET | 200 | Only when `authorize_download` allows |
| `scan_pending` | 423 | `awaiting_upload`, `scanning`, or `error` while scanning enabled |
| `infected` | 403 | Malware result |
| `forbidden` | 403 | Object key outside team prefix |

## Scan statuses

| Status | Meaning |
|--------|---------|
| `awaiting_upload` | Presigned; client has not completed (or queue rejected complete) |
| `scanning` | Job accepted; download blocked |
| `clean` | Safe to download |
| `infected` | Threat recorded; object moved under quarantine prefix when possible |
| `error` | Scanner/IO failure; download blocked while scanning enabled |

## Configuration

Defaults live in `backend/config/config.exs` (`enabled: false`). Runtime env
(`backend/config/runtime.exs` + `.env.example`):

| Variable | Default | Purpose |
|----------|---------|---------|
| `CLAMAV_ENABLED` | `false` (compose sets `true`) | Master switch |
| `CLAMAV_HOST` | `127.0.0.1` / `clamav` in compose | clamd host |
| `CLAMAV_PORT` | `3310` | clamd TCP |
| `CLAMAV_QUARANTINE_PREFIX` | `quarantine/` | Destination key prefix |
| `CLAMAV_MAX_CONCURRENCY` | `2` | Parallel scans |
| `CLAMAV_MAX_QUEUE` | `100` | Pending jobs beyond in-flight |

Compose service: `clamav/clamav:1.4` in `docker-compose.yml` (backend depends on
it). CI compose (`docker-compose.ci.yml`) puts ClamAV behind profile `clamav`
so integration jobs do not wait on virus DB updates.

Constraints:

- Objects larger than `max_scan_bytes` (50 MiB, same as upload limit) are
  deleted and recorded as scan error `:object_too_large` — HEAD and post-GET
  size checks both apply so a lying client `size` cannot force huge in-memory
  scans.
- Infected objects are copied to `quarantine/<object_key>` then removed from the
  live key; if copy fails, the live object is still deleted.
- Scanner behaviour is pluggable (`:scanner` config); production uses
  `Messngr.Media.VirusScan.Clamd`.

## Local development

```bash
cp .env.example .env   # keep CLAMAV_* if you want real scans
docker compose up -d clamav msgr-minio db   # or full stack
# Wait for clamav healthcheck (signature DB pull can take minutes)
```

Without ClamAV: set `CLAMAV_ENABLED=false` — `complete` short-circuits to
`:clean`.

## Tests

```bash
cd backend
PROMETHEUS_ENABLED=false mix test apps/msgr_web/test/msgr_web/controllers/team_media_virus_scan_test.exs
```

Tests stub the scanner (`Passthrough` / `InfectedStub` / `BlockingStub`) and
optional Storage hooks (`quarantine_object`, `head_object`, …) via Application
env — they do not require a live clamd.

## Pitfalls

- **ClamAV cold start:** first boot downloads virus definitions; healthcheck
  `start_period` is 120s. Backend may be up before clamd accepts INSTREAM.
- **Queue full under load:** clients must retry `complete`; status stays
  `awaiting_upload` until a job is accepted.
- **Do not treat `error` as clean:** downloads stay blocked while scanning is
  enabled — operators need to re-enqueue or investigate clamd/MinIO.
- **Team-only:** personal chat uploads are a separate codepath without this
  gate; do not assume ClamAV covers every media URL in the product.
- **CI:** do not assume ClamAV runs in the default integration compose profile.
