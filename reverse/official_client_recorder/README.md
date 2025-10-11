# Official Client Traffic Recorder

This toolset launches Chrome (headless or full UI) against the official chat client and records every HTTP(S) request, response, and WebSocket frame to newline-delimited JSON. The output can be inspected later with any log processor or a simple text editor.

## Features
- Toggleable **headless** and **interactive** modes for automated or user-driven sessions.
- Optional injection of a custom JavaScript automation script to reproduce deterministic flows.
- Lossless capture of request/response metadata, payloads (when enabled), and WebSocket events.
- Session files saved under `captures/` with timestamped filenames for easy cataloguing.

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
- `--slowmo <ms>`: Slow down Puppeteer’s actions for debugging.

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

Run with `--help` to see the full option set.

### Rules & Noise Filtering
- Analyzer defaults to `config/rules.json` for event categorisation, scoring, and noise suppression.
- Asset noise (images, fonts, CSS) and telemetry endpoints flagged in the rules file are counted but hidden from the match list; pass `--include-assets` to view everything.
- Edit `config/rules.json` to tailor categories (auth, messaging-send/sync, attachments, telemetry, etc.) or add new matchers. Regex strings follow standard JavaScript `RegExp` syntax.
- Adjust the auto-highlight threshold (`--highlight-threshold`) to raise/lower the minimum score for the “High-value events” section.

## Next Steps
- Add helpers that convert captured logs into invitational HAR files.
- Plug the recorder into the broader reverse-engineering toolkit under `reverse/`.
