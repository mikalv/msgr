from __future__ import annotations

import asyncio
import copy
import json
import time
from pathlib import Path
from typing import Awaitable, Callable, Dict, Mapping, Optional

from msgr_bridge_sdk import StoneMQClient, build_envelope
from msgr_teams_bridge import SessionManager, SessionStore, TeamsBridgeDaemon
from msgr_teams_bridge.client import TeamsIdentity, TeamsTenant, TeamsToken, TeamsUser


class MemoryTransport:
    def __init__(self) -> None:
        self.subscriptions: Dict[str, Callable[[bytes], Awaitable[None]]] = {}
        self.request_handlers: Dict[str, Callable[[bytes], Awaitable[bytes]]] = {}
        self.published: Dict[str, bytes] = {}

    async def subscribe(self, topic: str, handler: Callable[[bytes], Awaitable[None]]) -> None:
        self.subscriptions[topic] = handler

    async def publish(self, topic: str, body: bytes) -> None:
        self.published[topic] = body
        handler = self.subscriptions.get(topic)
        if handler is not None:
            await handler(body)

    async def subscribe_request(self, topic: str, handler: Callable[[bytes], Awaitable[bytes]]) -> None:
        self.request_handlers[topic] = handler

    async def request(self, topic: str, body: bytes) -> bytes:
        handler = self.request_handlers[topic]
        return await handler(body)


class FakeTeamsClient:
    def __init__(self) -> None:
        tenant = TeamsTenant(id="tenant-1", display_name="Acme Corp")
        user = TeamsUser(id="user-1", display_name="Alice Example", user_principal_name="alice@acme.com")
        self.identity = TeamsIdentity(tenant=tenant, user=user)
        self.connected = False
        self.token: Optional[TeamsToken] = None
        self.capabilities: Mapping[str, object] = {
            "messaging": {"text": True, "mentions": True},
            "presence": {"typing": True},
        }
        self.members: list[Mapping[str, object]] = [
            {"id": "user-1", "display_name": "Alice Example"},
            {"id": "user-2", "display_name": "Bob"},
        ]
        self.conversations: list[Mapping[str, object]] = [
            {"id": "chat-1", "topic": "General"},
        ]
        self.sent_messages: list[Mapping[str, object]] = []
        self.handlers: list[Callable[[Mapping[str, object]], Awaitable[None]]] = []
        self.acked: list[str] = []
        self.pending_events = 0
        self.health_calls = 0
        self.refresh_callback: Optional[Callable[[TeamsToken], Awaitable[TeamsToken]]] = None
        self.update_callback: Optional[Callable[[TeamsToken], Awaitable[None]]] = None
        self.refresh_margin: Optional[float] = None

    async def connect(self, tenant: TeamsTenant, token: TeamsToken) -> None:
        self.connected = True
        self.token = token
        self.identity = TeamsIdentity(tenant=tenant, user=self.identity.user)

    async def disconnect(self) -> None:
        self.connected = False

    async def is_connected(self) -> bool:
        return self.connected

    async def fetch_identity(self) -> TeamsIdentity:
        return self.identity

    async def describe_capabilities(self) -> Mapping[str, object]:
        return copy.deepcopy(self.capabilities)

    async def list_members(self) -> list[Mapping[str, object]]:
        return copy.deepcopy(self.members)

    async def list_conversations(self) -> list[Mapping[str, object]]:
        return copy.deepcopy(self.conversations)

    async def send_message(
        self,
        conversation_id: str,
        message: Mapping[str, object],
        *,
        reply_to_id: Optional[str] = None,
        metadata: Optional[Mapping[str, object]] = None,
        file_uploads: Optional[list[Mapping[str, object]]] = None,
    ) -> Mapping[str, object]:
        payload = {
            "conversation_id": conversation_id,
            "message": dict(message),
            "reply_to_id": reply_to_id,
            "metadata": metadata,
            "file_uploads": list(file_uploads) if file_uploads is not None else None,
        }
        self.sent_messages.append(payload)
        return {"id": "msg-1"}

    async def acknowledge_event(self, event_id: str) -> None:
        self.acked.append(event_id)
        if self.pending_events > 0:
            self.pending_events -= 1

    def add_event_handler(self, handler: Callable[[Mapping[str, object]], Awaitable[None]]) -> None:
        self.handlers.append(handler)

    def remove_event_handler(self, handler: Callable[[Mapping[str, object]], Awaitable[None]]) -> None:
        if handler in self.handlers:
            self.handlers.remove(handler)

    def configure_token_refresh(
        self,
        refresher: Callable[[TeamsToken], Awaitable[TeamsToken]],
        on_update: Callable[[TeamsToken], Awaitable[None]],
        *,
        margin: Optional[float] = None,
    ) -> None:
        self.refresh_callback = refresher
        self.update_callback = on_update
        self.refresh_margin = margin

    async def dispatch_event(self, event: Mapping[str, object]) -> None:
        for handler in list(self.handlers):
            await handler(event)
        self.pending_events += 1

    async def health(self) -> Mapping[str, object]:
        self.health_calls += 1
        return {
            "connected": self.connected,
            "pending_events": self.pending_events,
            "last_event_id": self.acked[-1] if self.acked else None,
        }


class FakeClientFactory:
    def __init__(self, client: FakeTeamsClient) -> None:
        self._client = client

    def create(self, tenant: TeamsTenant) -> FakeTeamsClient:
        # Update tenant metadata so the client reflects the requested tenant.
        self._client.identity = TeamsIdentity(tenant=tenant, user=self._client.identity.user)
        return self._client


class FakeOAuthClient:
    def __init__(self) -> None:
        self.refresh_calls: list[str] = []
        self.next_response: Mapping[str, object] = {
            "access_token": "token-2",
            "refresh_token": "refresh-2",
            "expires_in": 3600,
        }

    async def exchange_code(self, code: str, *, redirect_uri: Optional[str] = None, code_verifier: Optional[str] = None) -> Mapping[str, object]:
        return {
            "token": self.next_response,
            "tenant": {"id": "tenant-1", "display_name": "Acme Corp"},
        }

    async def refresh_token(self, refresh_token: str, *, redirect_uri: Optional[str] = None) -> Mapping[str, object]:
        self.refresh_calls.append(refresh_token)
        return self.next_response


def _build_daemon(
    tmp_path: Path,
    client: FakeTeamsClient,
    *,
    oauth: Optional[FakeOAuthClient] = None,
) -> tuple[TeamsBridgeDaemon, MemoryTransport, SessionManager]:
    transport = MemoryTransport()
    queue_client = StoneMQClient("teams", transport, instance="tenant-1")
    store = SessionStore(tmp_path / "teams_sessions")
    factory = FakeClientFactory(client)
    sessions = SessionManager(store, factory.create)
    daemon = TeamsBridgeDaemon(
        queue_client,
        sessions,
        default_user_id="acct-1",
        oauth=oauth,
        instance="tenant-1",
    )
    return daemon, transport, sessions


def _run(async_fn: Callable[[], Awaitable[None]]) -> None:
    asyncio.run(async_fn())


async def _link_account(daemon: TeamsBridgeDaemon, transport: MemoryTransport) -> Mapping[str, object]:
    await daemon.start()
    envelope = build_envelope(
        "teams",
        "link_account",
        {
            "user_id": "acct-1",
            "session": {"access_token": "token-1", "refresh_token": "refresh"},
            "tenant": {"id": "tenant-1", "display_name": "Acme Corp"},
        },
    )
    topic = "bridge/teams/tenant-1/link_account"
    response_raw = await transport.request(topic, envelope.to_json().encode("utf-8"))
    return json.loads(response_raw.decode("utf-8"))


def test_link_account_returns_snapshot(tmp_path: Path) -> None:
    client = FakeTeamsClient()
    daemon, transport, _sessions = _build_daemon(tmp_path, client)

    async def scenario() -> None:
        response = await _link_account(daemon, transport)
        assert response["status"] == "linked"
        assert response["tenant"]["id"] == "tenant-1"
        assert response["user"]["id"] == "user-1"
        assert response["session"]["access_token"] == "token-1"
        assert response["capabilities"]["messaging"]["mentions"] is True
        assert response["members"][1]["display_name"] == "Bob"

        await client.dispatch_event({"event_id": "evt-1", "conversation_id": "chat-1"})
        topic = "bridge/teams/tenant-1/inbound_event"
        assert topic in transport.published
        envelope = json.loads(transport.published[topic].decode("utf-8"))
        assert envelope["payload"]["conversation_id"] == "chat-1"
        assert envelope["payload"]["tenant_id"] == "tenant-1"

        await daemon.shutdown()

    _run(scenario)


def test_link_account_without_token_requires_consent(tmp_path: Path) -> None:
    client = FakeTeamsClient()
    daemon, transport, _sessions = _build_daemon(tmp_path, client)

    async def scenario() -> None:
        await daemon.start()
        envelope = build_envelope(
            "teams",
            "link_account",
            {"user_id": "acct-1", "tenant": {"id": "tenant-1"}, "session": {}},
        )
        topic = "bridge/teams/tenant-1/link_account"
        response_raw = await transport.request(topic, envelope.to_json().encode("utf-8"))
        response = json.loads(response_raw.decode("utf-8"))

        assert response["status"] == "consent_required"
        flow = response["flow"]
        assert flow["kind"] == "embedded_browser_consent"
        assert flow["tenant"]["id"] == "tenant-1"
        assert any(step["action"] == "open_webview" for step in flow["steps"])
        assert not flow.get("resource_specific_consent")

        await daemon.shutdown()

    _run(scenario)


def test_link_account_requires_rsc_prompts(tmp_path: Path) -> None:
    client = FakeTeamsClient()
    daemon, transport, _sessions = _build_daemon(tmp_path, client)

    async def scenario() -> None:
        await daemon.start()
        envelope = build_envelope(
            "teams",
            "link_account",
            {
                "user_id": "acct-1",
                "tenant": {"id": "tenant-1", "requires_resource_specific_consent": True},
                "session": {},
            },
        )
        topic = "bridge/teams/tenant-1/link_account"
        response_raw = await transport.request(topic, envelope.to_json().encode("utf-8"))
        response = json.loads(response_raw.decode("utf-8"))

        assert response["status"] == "consent_required"
        flow = response["flow"]
        assert flow["resource_specific_consent"]["required"] is True
        assert any(step["action"] == "resource_specific_consent" for step in flow["steps"])

        await daemon.shutdown()

    _run(scenario)


def test_outbound_message_dispatch(tmp_path: Path) -> None:
    client = FakeTeamsClient()
    daemon, transport, _sessions = _build_daemon(tmp_path, client)

    async def scenario() -> None:
        await _link_account(daemon, transport)
        envelope = build_envelope(
            "teams",
            "outbound_message",
            {
                "conversation_id": "chat-1",
                "message": {"body": {"contentType": "text", "content": "Hei"}},
                "attachments": [
                    {
                        "contentType": "application/vnd.microsoft.card.adaptive",
                        "content": {"type": "AdaptiveCard", "body": [{"type": "TextBlock", "text": "<b>hi</b>"}]},
                    }
                ],
                "file_uploads": [
                    {"filename": "hello.txt", "content": "aGk=", "content_type": "text/plain"}
                ],
            },
            metadata={"user_id": "acct-1", "tenant_id": "tenant-1"},
        )
        topic = "bridge/teams/tenant-1/outbound_message"
        await transport.publish(topic, envelope.to_json().encode("utf-8"))

        assert client.sent_messages[0]["message"]["body"]["content"] == "Hei"
        assert client.sent_messages[0]["message"]["attachments"][0]["contentType"] == "application/vnd.microsoft.card.adaptive"
        assert client.sent_messages[0]["file_uploads"][0]["filename"] == "hello.txt"
        await daemon.shutdown()

    _run(scenario)


def test_ack_event_invokes_client(tmp_path: Path) -> None:
    client = FakeTeamsClient()
    daemon, transport, _sessions = _build_daemon(tmp_path, client)

    async def scenario() -> None:
        await _link_account(daemon, transport)
        envelope = build_envelope(
            "teams",
            "ack_event",
            {"event_id": "evt-1"},
            metadata={"tenant_id": "tenant-1", "user_id": "acct-1"},
        )
        topic = "bridge/teams/tenant-1/ack_event"
        await transport.publish(topic, envelope.to_json().encode("utf-8"))

        assert client.acked == ["evt-1"]
        await daemon.shutdown()

    _run(scenario)


def test_health_snapshot_reports_runtime_state(tmp_path: Path) -> None:
    client = FakeTeamsClient()
    daemon, transport, _sessions = _build_daemon(tmp_path, client)

    async def scenario() -> None:
        await _link_account(daemon, transport)

        ack_envelope = build_envelope(
            "teams",
            "ack_event",
            {"event_id": "evt-2", "status": "accepted"},
            metadata={"tenant_id": "tenant-1", "user_id": "acct-1"},
        )
        await transport.publish("bridge/teams/tenant-1/ack_event", ack_envelope.to_json().encode("utf-8"))
        client.pending_events = 2

        health_envelope = build_envelope(
            "teams",
            "health_snapshot",
            {"tenant_id": "tenant-1"},
        )
        response_raw = await transport.request(
            "bridge/teams/tenant-1/health_snapshot",
            health_envelope.to_json().encode("utf-8"),
        )
        snapshot = json.loads(response_raw.decode("utf-8"))

        assert snapshot["summary"]["total_clients"] == 1
        assert snapshot["summary"]["pending_events"] == 2
        assert snapshot["summary"]["acked_events"] == 1
        assert snapshot["clients"][0]["tenant_id"] == "tenant-1"
        assert snapshot["clients"][0]["pending_events"] == 2

        await daemon.shutdown()

    _run(scenario)


def test_token_refresh_updates_session(tmp_path: Path) -> None:
    client = FakeTeamsClient()
    oauth = FakeOAuthClient()
    daemon, transport, sessions = _build_daemon(tmp_path, client, oauth=oauth)

    async def scenario() -> None:
        response = await _link_account(daemon, transport)
        assert response["session"]["refresh_token"] == "refresh"

        assert client.refresh_callback is not None
        assert client.update_callback is not None
        assert client.token is not None

        refreshed = await client.refresh_callback(client.token)  # type: ignore[arg-type]
        assert oauth.refresh_calls == ["refresh"]

        await client.update_callback(refreshed)

        stored = sessions.get_session("tenant-1", "acct-1")
        assert stored is not None
        assert stored.token.access_token == "token-2"
        assert stored.token.refresh_token == "refresh-2"
        assert stored.token.expires_at is not None
        assert stored.token.expires_at - time.time() > 3000

        await daemon.shutdown()

    _run(scenario)
