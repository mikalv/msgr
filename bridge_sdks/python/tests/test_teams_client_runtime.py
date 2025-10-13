import asyncio
import logging
import time
from typing import Dict, Mapping, Optional, Tuple

import pytest

from msgr_teams_bridge.client import (
    TeamsGraphClient,
    TeamsIdentity,
    TeamsOAuthClient,
    TeamsTenant,
    TeamsToken,
    TeamsUser,
)


class DummyTask:
    def __init__(self) -> None:
        self._cancelled = False
        self._done = False

    def cancel(self) -> None:
        self._cancelled = True
        self._done = True

    def done(self) -> bool:
        return self._done

    def __await__(self):  # pragma: no cover - simple awaitable shim
        self._done = True
        async def _noop() -> None:
            return None

        return _noop().__await__()


class DummyTeamsClient(TeamsGraphClient):
    def __init__(self) -> None:
        super().__init__(logger=logging.getLogger("dummy-teams"))
        self._responses: Dict[Tuple[str, Optional[Tuple[Tuple[str, object], ...]]], Mapping[str, object]] = {}
        self.posts: list[Tuple[str, Mapping[str, object]]] = []

    def queue_response(
        self,
        path: str,
        response: Mapping[str, object],
        *,
        params: Optional[Mapping[str, object]] = None,
    ) -> None:
        key = (path, tuple(sorted((params or {}).items())) if params else None)
        self._responses[key] = response

    async def _ensure_session(self) -> None:  # type: ignore[override]
        return None

    async def _poll_loop(self) -> None:  # type: ignore[override]
        return None

    async def connect(self, tenant: TeamsTenant, token: TeamsToken) -> None:  # type: ignore[override]
        self._tenant = tenant
        self._token = token
        me = await self._get("/me")
        user = TeamsUser(
            id=str(me.get("id")),
            display_name=me.get("displayName"),
            user_principal_name=me.get("userPrincipalName"),
            mail=me.get("mail"),
        )
        self._identity = TeamsIdentity(tenant=tenant, user=user)
        self._poll_task = DummyTask()

    async def _get(  # type: ignore[override]
        self,
        path: str,
        params: Optional[Mapping[str, object]] = None,
    ) -> Mapping[str, object]:
        key = (path, tuple(sorted((params or {}).items())) if params else None)
        return self._responses.get(key, {"value": []})

    async def _post(  # type: ignore[override]
        self,
        path: str,
        payload: Mapping[str, object],
    ) -> Mapping[str, object]:
        self.posts.append((path, payload))
        return {"id": "m1"}


def test_connect_fetches_identity(monkeypatch) -> None:
    async def _run() -> None:
        tenant = TeamsTenant(id="tenant", display_name="Acme")
        token = TeamsToken(access_token="token")
        client = DummyTeamsClient()
        client.queue_response("/me", {"id": "user1", "displayName": "Alice"})

        await client.connect(tenant, token)
        identity = await client.fetch_identity()

        assert identity.user.id == "user1"
        assert identity.tenant.id == "tenant"

    asyncio.run(_run())


def test_list_conversations_and_members() -> None:
    async def _run() -> None:
        client = DummyTeamsClient()
        client._tenant = TeamsTenant(id="tenant")  # type: ignore[protected-access]
        client._token = TeamsToken(access_token="token")  # type: ignore[protected-access]

        client.queue_response("/me/chats", {"value": [{"id": "chat1"}]})
        client.queue_response("/me/people", {"value": [{"id": "user2"}]})

        conversations = await client.list_conversations()
        members = await client.list_members()

        assert conversations[0]["id"] == "chat1"
        assert members[0]["id"] == "user2"

    asyncio.run(_run())


def test_send_message_and_poll_event(monkeypatch) -> None:
    async def _run() -> None:
        tenant = TeamsTenant(id="tenant")
        token = TeamsToken(access_token="token")
        client = DummyTeamsClient()
        client.queue_response("/me", {"id": "user1"})

        await client.connect(tenant, token)

        client.queue_response(
            f"/chats/chat1/messages",
            {
                "value": [
                    {
                        "id": "msg1",
                        "createdDateTime": "2024-01-01T00:00:00Z",
                        "lastModifiedDateTime": "2024-01-01T00:00:10Z",
                        "body": {"content": "<p>hi</p>", "contentType": "html"},
                        "summary": "hi",
                        "replyToId": "parent1",
                        "from": {"user": {"id": "user2", "displayName": "Bob"}},
                        "attachments": [
                            {
                                "id": "att1",
                                "contentType": "image/png",
                                "contentUrl": "https://cdn.example/img.png",
                                "name": "img.png",
                                "size": 123,
                            }
                        ],
                        "mentions": [
                            {
                                "id": 0,
                                "mentionText": "@Alice",
                                "mentioned": {"user": {"id": "user1", "displayName": "Alice"}},
                            }
                        ],
                        "reactions": [
                            {
                                "reactionType": "like",
                                "createdDateTime": "2024-01-01T00:00:05Z",
                                "user": {"user": {"id": "user3", "displayName": "Charlie"}},
                            }
                        ],
                    }
                ]
            },
            params={"$top": 20, "$orderby": "lastModifiedDateTime asc"},
        )

        events: list[Mapping[str, object]] = []

        async def recorder(payload: Mapping[str, object]) -> None:
            events.append(payload)

        client.add_event_handler(recorder)
        await client._poll_chat("chat1")

        await client.send_message("chat1", {"body": {"contentType": "text", "content": "reply"}})

        assert events[0]["event_id"] == "msg1"
        assert events[0]["event_type"] == "message"
        assert events[0]["message"]["body"]["content_type"] == "html"
        assert events[0]["message"]["attachments"][0]["name"] == "img.png"
        assert events[0]["message"]["mentions"][0]["text"] == "@Alice"
        assert client.posts[-1][0] == "/chats/chat1/messages"

    asyncio.run(_run())


def test_send_message_sanitises_html_content() -> None:
    async def _run() -> None:
        client = DummyTeamsClient()
        client._tenant = TeamsTenant(id="tenant")  # type: ignore[protected-access]
        client._token = TeamsToken(access_token="token")  # type: ignore[protected-access]

        await client.send_message(
            "chat1",
            {
                "body": {
                    "contentType": "html",
                    "content": (
                        "<script>alert(1)</script><p>Hello <b>World</b></p>"
                        '<a href="javascript:bad">bad</a><a href="https://ok">ok</a>'
                    ),
                }
            },
        )

        _, payload = client.posts[-1]
        assert payload["body"]["contentType"] == "html"
        assert payload["body"]["content"] == '<p>Hello <b>World</b></p>bad<a href="https://ok">ok</a>'

    asyncio.run(_run())


def test_token_refresh_invoked_when_expiring() -> None:
    async def _run() -> None:
        client = TeamsGraphClient(logger=logging.getLogger("refresh"), token_refresh_margin=45.0)
        client._token = TeamsToken(  # type: ignore[protected-access]
            access_token="old",
            refresh_token="refresh",
            expires_at=time.time() + 10,
        )

        refreshed_tokens: list[TeamsToken] = []
        updated_tokens: list[TeamsToken] = []

        async def refresher(current: TeamsToken) -> TeamsToken:
            refreshed_tokens.append(current)
            return TeamsToken(
                access_token="new",
                refresh_token="refresh-2",
                expires_at=time.time() + 3600,
            )

        async def on_update(updated: TeamsToken) -> None:
            updated_tokens.append(updated)

        client.configure_token_refresh(refresher, on_update, margin=30.0)
        await client._ensure_valid_token()  # type: ignore[attr-defined]

        assert client._token is not None  # type: ignore[truthy-bool]
        assert client._token.access_token == "new"  # type: ignore[union-attr]
        assert refreshed_tokens and refreshed_tokens[0].access_token == "old"
        assert updated_tokens and updated_tokens[0].access_token == "new"

    asyncio.run(_run())


def test_token_refresh_skipped_when_not_needed() -> None:
    async def _run() -> None:
        client = TeamsGraphClient(logger=logging.getLogger("refresh-skip"), token_refresh_margin=45.0)
        client._token = TeamsToken(  # type: ignore[protected-access]
            access_token="token",
            refresh_token="refresh",
            expires_at=time.time() + 3600,
        )

        refreshed: list[TeamsToken] = []

        async def refresher(current: TeamsToken) -> TeamsToken:
            refreshed.append(current)
            return current

        async def on_update(updated: TeamsToken) -> None:
            raise AssertionError("token should not be updated when not expiring")

        client.configure_token_refresh(refresher, on_update, margin=30.0)
        await client._ensure_valid_token()  # type: ignore[attr-defined]

        assert client._token is not None  # type: ignore[truthy-bool]
        assert client._token.access_token == "token"  # type: ignore[union-attr]
        assert refreshed == []

    asyncio.run(_run())


def test_send_message_renders_plain_text_as_html() -> None:
    async def _run() -> None:
        client = DummyTeamsClient()
        client._tenant = TeamsTenant(id="tenant")  # type: ignore[protected-access]
        client._token = TeamsToken(access_token="token")  # type: ignore[protected-access]

        await client.send_message(
            "chat1",
            {"body": {"contentType": "text", "content": "Line1\nLine2"}},
        )

        _, payload = client.posts[-1]
        assert payload["body"]["content"] == "<p>Line1<br />Line2</p>"
        assert payload["body"]["contentType"] == "html"

    asyncio.run(_run())


def test_teams_oauth_payload(monkeypatch: pytest.MonkeyPatch) -> None:
    captured: dict[str, object] = {}

    class DummyResponse:
        def __init__(self) -> None:
            self._payload = {"access_token": "token", "refresh_token": "refresh"}

        async def __aenter__(self) -> "DummyResponse":
            return self

        async def __aexit__(self, exc_type, exc, tb) -> None:  # pragma: no cover - no cleanup required
            return None

        async def json(self) -> Mapping[str, object]:
            return self._payload

        def raise_for_status(self) -> None:
            return None

    class DummySession:
        def post(self, url: str, data: Mapping[str, object]) -> DummyResponse:
            captured.update({"url": url, "data": dict(data)})
            return DummyResponse()

    session = DummySession()
    client = TeamsOAuthClient("client-id", client_secret="secret", session=session)  # type: ignore[arg-type]

    result = asyncio.run(client.exchange_code("code", redirect_uri="https://callback"))

    assert result["access_token"] == "token"
    assert captured["url"].startswith("https://login.microsoftonline.com")
    assert captured["data"]["client_secret"] == "secret"


def test_health_reports_teams_runtime_state() -> None:
    async def _run() -> None:
        tenant = TeamsTenant(id="tenant")
        token = TeamsToken(access_token="token")
        client = DummyTeamsClient()
        client.queue_response("/me", {"id": "user1"})

        await client.connect(tenant, token)

        await client._dispatch_event("chat1", {"id": "msg-1"})  # type: ignore[arg-type]

        snapshot = await client.health()
        assert snapshot["connected"] is True
        assert snapshot["pending_events"] == 1
        assert snapshot["last_event_id"] == "msg-1"

        await client.acknowledge_event("msg-1")

        snapshot_after = await client.health()
        assert snapshot_after["pending_events"] == 0
        assert snapshot_after["last_ack_latency"] >= 0.0
        assert snapshot_after["consecutive_errors"] == 0

    asyncio.run(_run())
