import asyncio
import logging

from msgr_slack_bridge.client import (
    SlackFileReference,
    SlackFileUpload,
    SlackRTMClient,
    SlackToken,
    _normalise_event,
)


class DummySlackClient(SlackRTMClient):
    def __init__(self) -> None:
        super().__init__(logger=logging.getLogger("dummy-slack"))
        self.responses: dict[str, list[dict[str, object]]] = {}
        self.calls: list[tuple[str, dict[str, object] | None, dict[str, object] | None]] = []
        self.upload_requests: list[tuple[str, SlackFileUpload]] = []
        self.completed_uploads: list[dict[str, object]] = []
        self.upload_counter = 0

    async def _ensure_session(self) -> None:  # type: ignore[override]
        return None

    async def _api_call(  # type: ignore[override]
        self,
        method: str,
        *,
        params: dict[str, object] | None = None,
        payload: dict[str, object] | None = None,
        http_method: str = "GET",
    ) -> dict[str, object]:
        self.calls.append((method, params, payload))
        if method == "auth.test":
            return {"ok": True, "user_id": "U1", "team_id": "T1", "scope": "chat:write"}
        if method == "users.info":
            return {
                "ok": True,
                "user": {
                    "id": "U1",
                    "name": "alice",
                    "profile": {
                        "real_name": "Alice Example",
                        "display_name": "alice",
                        "email": "alice@example.com",
                    },
                },
            }
        if method == "team.info":
            return {
                "ok": True,
                "team": {"id": "T1", "name": "Acme", "domain": "acme"},
            }
        if method == "users.list":
            cursor = params.get("cursor") if isinstance(params, dict) else None
            if cursor == "page2":
                return {"ok": True, "members": [{"id": "U3"}], "response_metadata": {"next_cursor": ""}}
            return {
                "ok": True,
                "members": [{"id": "U1"}, {"id": "U2"}],
                "response_metadata": {"next_cursor": "page2"},
            }
        if method == "conversations.list":
            return {
                "ok": True,
                "channels": [{"id": "C1", "name": "general"}],
                "response_metadata": {"next_cursor": ""},
            }
        if method == "files.getUploadURLExternal":
            upload_id = f"F{self.upload_counter}"
            upload_url = f"https://uploads.example/{self.upload_counter}"
            self.upload_counter += 1
            return {"ok": True, "file_id": upload_id, "upload_url": upload_url}
        if method == "files.completeUploadExternal":
            payload_dict = payload or {}
            self.completed_uploads.append(payload_dict)
            files_payload = payload_dict.get("files") if isinstance(payload_dict.get("files"), list) else []
            file_id = files_payload[0]["id"] if files_payload else f"F{self.upload_counter}"
            return {
                "ok": True,
                "files": [
                    {
                        "id": file_id,
                        "permalink": f"https://files.slack.com/{file_id}",
                        "title": files_payload[0].get("title") if files_payload else None,
                    }
                ],
            }
        if method == "chat.postMessage":
            return {"ok": True, "ts": "123.456"}
        return {"ok": True}

    async def _upload_external_file(  # type: ignore[override]
        self, upload_url: str, upload: SlackFileUpload
    ) -> None:
        self.upload_requests.append((upload_url, upload))
        return None


def test_fetch_identity_and_capabilities() -> None:
    async def _run() -> None:
        client = DummySlackClient()
        client._token = SlackToken(value="xoxp-test")  # type: ignore[protected-access]

        identity = await client.fetch_identity()
        assert identity.workspace.id == "T1"
        assert identity.user.display_name == "alice"

        capabilities = await client.describe_capabilities()
        assert capabilities["messaging"]["text"] is True
        assert capabilities["scope"] == "chat:write"

    asyncio.run(_run())


def test_list_members_and_channels() -> None:
    async def _run() -> None:
        client = DummySlackClient()
        client._token = SlackToken(value="xoxp-test")  # type: ignore[protected-access]

        members = await client.list_members()
        assert [m["id"] for m in members] == ["U1", "U2", "U3"]

        channels = await client.list_conversations()
        assert channels[0]["id"] == "C1"

    asyncio.run(_run())


def test_post_message_invokes_web_api() -> None:
    async def _run() -> None:
        client = DummySlackClient()
        client._token = SlackToken(value="xoxp-test")  # type: ignore[protected-access]

        response = await client.post_message("C1", "Hello", thread_ts="123", reply_broadcast=True)
        assert response["ts"] == "123.456"

        method, params, payload = client.calls[-1]
        assert method == "chat.postMessage"
        assert params is None
        assert payload == {
            "channel": "C1",
            "text": "Hello",
            "reply_broadcast": True,
            "thread_ts": "123",
        }

    asyncio.run(_run())


def test_post_message_uploads_files_and_references_blocks() -> None:
    async def _run() -> None:
        client = DummySlackClient()
        client._token = SlackToken(value="xoxp-test")  # type: ignore[protected-access]

        upload = SlackFileUpload(
            filename="report.pdf",
            content=b"%PDF-1.4",
            content_type="application/pdf",
            title="Quarterly Report",
        )

        response = await client.post_message(
            "C1",
            "Here is the latest report",
            thread_ts="THREAD1",
            file_uploads=[upload],
            file_references=[SlackFileReference(external_id="F999")],
        )

        assert "uploaded_files" in response
        uploaded = response["uploaded_files"][0]
        assert uploaded["id"] == "F0"
        assert uploaded["permalink"] == "https://files.slack.com/F0"

        assert client.upload_requests[0][0] == "https://uploads.example/0"
        assert client.completed_uploads[0]["channel_id"] == "C1"
        assert client.completed_uploads[0]["thread_ts"] == "THREAD1"

        method, params, payload = client.calls[-1]
        assert method == "chat.postMessage"
        assert payload["channel"] == "C1"
        assert payload["blocks"] == [
            {"type": "file", "source": "remote", "external_id": "F999"},
            {"type": "file", "source": "remote", "external_id": "F0"},
        ]

    asyncio.run(_run())


def test_normalise_event_extracts_event_id() -> None:
    event = _normalise_event(
        {
            "type": "event_callback",
            "team": "T1",
            "event": {
                "type": "message",
                "text": "hi",
                "event_ts": "123.0001",
                "channel": "C1",
            },
        }
    )
    assert event is not None
    assert event["event_id"] == "123.0001"
    assert event["team_id"] == "T1"
    assert event["conversation"]["id"] == "C1"
    assert event["message"]["text"] == "hi"


def test_normalise_message_event_includes_files_and_reactions() -> None:
    event = _normalise_event(
        {
            "event": {
                "type": "message",
                "event_ts": "456.0002",
                "channel": "C2",
                "channel_type": "channel",
                "thread_ts": "456.0001",
                "text": "Hello",
                "attachments": [{"id": 1, "fallback": "image", "text": "caption"}],
                "files": [
                    {
                        "id": "F1",
                        "name": "report.pdf",
                        "mimetype": "application/pdf",
                        "size": 42,
                        "permalink": "https://files.slack.com/F1",
                    }
                ],
                "reactions": [{"name": "thumbsup", "count": 2, "users": ["U1", "U2"]}],
            }
        }
    )
    assert event is not None
    assert event["event_type"] == "message"
    assert event["conversation"]["thread_ts"] == "456.0001"
    assert event["message"]["attachments"][0]["fallback"] == "image"
    assert event["message"]["files"][0]["name"] == "report.pdf"
    assert event["message"]["reactions"][0]["count"] == 2


def test_normalise_message_change_event_captures_previous_message() -> None:
    event = _normalise_event(
        {
            "event": {
                "type": "message",
                "subtype": "message_changed",
                "channel": "C3",
                "message": {"ts": "789.1", "text": "updated", "user": "U1"},
                "previous_message": {"ts": "789.1", "text": "old", "user": "U1"},
            }
        }
    )
    assert event is not None
    assert event["change_type"] == "edited"
    assert event["previous_message"]["text"] == "old"


def test_normalise_reaction_event_maps_action() -> None:
    event = _normalise_event(
        {
            "event": {
                "type": "reaction_added",
                "user": "U2",
                "reaction": "eyes",
                "event_ts": "999.0",
                "item_user": "U1",
                "item": {"type": "message", "channel": "C4", "ts": "999.0"},
            }
        }
    )
    assert event is not None
    assert event["event_type"] == "reaction"
    assert event["action"] == "added"
    assert event["item"]["channel"] == "C4"
    assert event["user_id"] == "U2"


def test_health_reports_slack_runtime_state() -> None:
    class StubWebSocket:
        def __init__(self) -> None:
            self.closed = False
            self.sent: list[dict[str, object]] = []

        async def send_json(self, payload: dict[str, object]) -> None:
            self.sent.append(dict(payload))

    async def _run() -> None:
        client = DummySlackClient()
        stub_ws = StubWebSocket()
        client._websocket = stub_ws  # type: ignore[assignment]

        await client._dispatch_event({"event_id": "evt-1"})  # type: ignore[arg-type]

        snapshot = await client.health()
        assert snapshot["connected"] is True
        assert snapshot["pending_events"] == 1
        assert snapshot["last_event_id"] == "evt-1"

        await client.acknowledge_event("evt-1")

        assert stub_ws.sent[0]["event_id"] == "evt-1"

        snapshot_after = await client.health()
        assert snapshot_after["pending_events"] == 0
        assert snapshot_after["last_ack_event_id"] == "evt-1"
        assert snapshot_after["last_ack_latency"] >= 0.0

    asyncio.run(_run())
