import asyncio
import logging

from msgr_slack_bridge.client import SlackRTMClient, SlackToken, _normalise_event


class DummySlackClient(SlackRTMClient):
    def __init__(self) -> None:
        super().__init__(logger=logging.getLogger("dummy-slack"))
        self.responses: dict[str, list[dict[str, object]]] = {}
        self.calls: list[tuple[str, dict[str, object] | None, dict[str, object] | None]] = []

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
        if method == "chat.postMessage":
            return {"ok": True, "ts": "123.456"}
        return {"ok": True}


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


def test_normalise_event_extracts_event_id() -> None:
    event = _normalise_event({
        "type": "event_callback",
        "team": "T1",
        "event": {"type": "message", "text": "hi", "event_ts": "123.0001"},
    })
    assert event is not None
    assert event["event_id"] == "123.0001"
    assert event["team"] == "T1"
