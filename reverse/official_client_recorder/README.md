# Official Client Traffic Recorder

This toolset launches Chrome (headless or full UI) against the official chat client and records every HTTP(S) request, response, and WebSocket frame to newline-delimited JSON. The output can be inspected later with any log processor or a simple text editor.

## Features
- Toggleable **headless** and **interactive** modes for automated or user-driven sessions.
- Optional injection of a custom JavaScript automation script to reproduce deterministic flows.
- Lossless capture of request/response metadata, payloads (when enabled), and WebSocket events.
- Session files saved under `captures/` with timestamped filenames for easy cataloguing.
- Optional resource export: persist decoded HTTP responses (JS blobs, protobuf bundles, etc.) to disk for deeper reverse-engineering.
- Auto-generate prettified companions for JSON/JS assets when `prettier` is available, making captures easier to search and diff.

## Prerequisites
- Node.js 18+
- `npm install` inside this directory (installs Puppeteer and helpers)
- Google Chrome or Chromium; point the tool at a custom binary if Puppeteer’s bundled Chromium is unsuitable.

## Quick Start
```bash
cd reverse/official_client_recorder
npm install
# Interactive session, open the official client URL in a visible Chrome window
npm run record -- --url https://official.client.example
```

Captured traffic is written to `captures/session-<timestamp>.jsonl`. Press `Ctrl+C` to end the session and close Chrome.

## Headless Automation
```bash
npm run record -- --url https://official.client.example --headless --script ./scripts/login.js
```

- `--headless` launches Chrome without UI.
- `--script` injects and executes the provided JavaScript file after the page loads. You can use it to drive automated flows (fill forms, click buttons, etc.).

## Additional Flags
- `--output <path>`: Write the log to a custom file instead of the default timestamped name.
- `--executable <path>`: Use a specific Chrome/Chromium binary.
- `--capture-bodies`: Persist response bodies and WebSocket payloads (may generate large files).
- `--save-resources`: Decode HTTP responses and store them under a session-scoped directory (defaults to `<capture>_resources/`).
- `--resources-dir <path>`: Custom directory for exported resources. Combine with `--save-resources`.
- `--no-pretty-resources`: Skip generating prettified text/JSON companions for saved resources.
- `--slowmo <ms>`: Slow down Puppeteer’s actions for debugging.
- `--devtools`: Open DevTools automatically (only in non-headless mode).
- `--no-stealth`: Disable the built-in stealth plugin (enabled by default to reduce automation fingerprints).
- `--no-camouflage`: Skip navigator/user-agent spoofing.
- `--camouflage-profile <id>`: Force a specific fingerprint preset (`macos-sonoma`, `windows-11`, `linux-workstation`).
- `--chrome-arg <value>`: Pass custom launch arguments to Chrome (repeatable).

See `npm run record -- --help` for the full list.

## Analysing Logs
Each line of the JSONL output is a single event with a `type` field:
- `http-request`: outbound HTTP(S) request metadata and body (if available).
- `http-response`: inbound response metadata and optional body.
- `ws-frame`: WebSocket frame payloads (direction annotated).
- `metadata`: session start/end markers.

Example inspection command:
```bash
rg --json --field-matcher type:ws-frame captures/session-*.jsonl
```

### CLI Analyzer
Use the built-in analyzer to surface the interesting pieces of a large capture:

```bash
npm run analyze -- --file captures/session-2024-01-01T12-00-00-000Z.jsonl
```

By default this prints a summary (counts per event type, top endpoints, status distribution) and up to 20 matching events. Add filters to zero in on a conversation flow:

- `--search "sendMessage"`: substring match across URLs/payloads.
- `--type ws-frame --search '"text"'`: focus on WebSocket frames carrying message text.
- `--request-id 1234.56`: show the full lifecycle of a specific network call.
- `--show-bodies`: include payloads/bodies for the matches.
- Built-in summary callouts highlight POST/PUT endpoints, `Set-Cookie` issuers, and interesting headers (auth tokens, cookies, FB-specific headers, etc.).
- The CLI only prints a match list when you provide filters (`--search`, `--type`, `--request-id`, `--regex`); otherwise rely on the summary/highlights.

When `--save-resources` is enabled, every `http-response` entry contains a `resourcePath` pointing to the decoded artifact relative to the capture log. The recorder writes these files beneath the session's resource directory so you can inspect heavy JS bundles or protobuf definitions without rehydrating the JSONL payloads.

If you have `prettier` installed (add it with `npm install --save-dev prettier`), the recorder will also emit prettified companions like `*.pretty.json` / `*.pretty.js` beside the raw artifacts. These prettified files are referenced via `resourcePrettyPath` in the capture log; disable this behaviour with `--no-pretty-resources`.

## Retroactive Resource Extraction

Forgot to enable `--save-resources` (or captured before it existed)? Rehydrate assets later with:

```bash
npm run extract -- --file captures/session-2024-01-01T12-00-00-000Z.jsonl --output-dir tmp/resources
```

`client-recorder-extract` reads a JSONL capture, writes decoded responses (and optional prettified companions) under the chosen directory, and emits a manifest with URLs, status codes, and relative file paths. Use `--filter "<substring>"` to narrow by URL, `--limit N` to stop after N matches, and `--no-pretty-resources` if you only want the raw blobs.

## Standalone Beautifier

Already have a directory of resources and want prettified JSON/JS without re-recording? Run:

```bash
npm run pretty -- --dir tmp/resources
```

`client-recorder-pretty` walks the directory, skips existing `*.pretty.*` files (unless `--include-pretty`), and emits formatted companions for anything that looks like JSON or JavaScript. Use `--file <path>` to prettify a single blob, or `--max-bytes` to adjust the size threshold.

## Blob Analysis Toolkit

Once you have a resource directory, surface the interesting payloads—protobuf bundles, giant JS blobs, JSON configs—with:

```bash
npm run blobs -- --dir tmp/resources --top 20 --json tmp/blob-report.json
```

`client-recorder-blobs` scans the directory, classifies files (JSON/JS/protobuf/etc.), reports the largest artefacts, and highlights likely protobuf definitions. The optional `--json` flag persists the full report for further digging.

## WebAssembly Automation

Once the recorder (or extractor) gives you a resource directory, identify and decompile every WASM module:

```bash
npm run wasm -- --dir tmp/resources --out tmp/wasm
```

`client-recorder-wasm`:
- Recursively locates `.wasm`, `.wasm.gz`, `.wasm.br` files.
- Decompresses when needed and writes canonical `<name>.wasm` copies.
- Emits `.wat` text via the embedded `wabt` toolkit.
- Calls `wasm-decompile` / `wasm-objdump` when they’re available on your PATH (override with `--wasm-decompile` / `--wasm-objdump`).
- Produces a JSON manifest listing every artefact.

Use `--map-only` to just enumerate modules, or `--keep-temp` to retain intermediate files.

Run with `--help` to see the full option set.

### Rules & Noise Filtering
- Analyzer defaults to `config/rules.json` for event categorisation, scoring, and noise suppression.
- Asset noise (images, fonts, CSS) and telemetry endpoints flagged in the rules file are counted but hidden from the match list; pass `--include-assets` to view everything.
- Edit `config/rules.json` to tailor categories (auth, messaging-send/sync, attachments, telemetry, etc.) or add new matchers. Regex strings follow standard JavaScript `RegExp` syntax.
- Adjust the auto-highlight threshold (`--highlight-threshold`) to raise/lower the minimum score for the “High-value events” section.
- Straightforward document GETs without query parameters are deprioritised unless a rule marks them as interesting, so focus remains on API-esque calls.

## Next Steps
- Add helpers that convert captured logs into invitational HAR files.
- Plug the recorder into the broader reverse-engineering toolkit under `reverse/`.
