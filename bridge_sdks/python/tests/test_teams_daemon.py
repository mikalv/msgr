from __future__ import annotations

import asyncio
import copy
import json
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
    ) -> Mapping[str, object]:
        payload = {
            "conversation_id": conversation_id,
            "message": dict(message),
            "reply_to_id": reply_to_id,
            "metadata": metadata,
        }
        self.sent_messages.append(payload)
        return {"id": "msg-1"}

    async def acknowledge_event(self, event_id: str) -> None:
        self.acked.append(event_id)

    def add_event_handler(self, handler: Callable[[Mapping[str, object]], Awaitable[None]]) -> None:
        self.handlers.append(handler)

    def remove_event_handler(self, handler: Callable[[Mapping[str, object]], Awaitable[None]]) -> None:
        if handler in self.handlers:
            self.handlers.remove(handler)

    async def dispatch_event(self, event: Mapping[str, object]) -> None:
        for handler in list(self.handlers):
            await handler(event)


class FakeClientFactory:
    def __init__(self, client: FakeTeamsClient) -> None:
        self._client = client

    def create(self, tenant: TeamsTenant) -> FakeTeamsClient:
        # Update tenant metadata so the client reflects the requested tenant.
        self._client.identity = TeamsIdentity(tenant=tenant, user=self._client.identity.user)
        return self._client


def _build_daemon(tmp_path: Path, client: FakeTeamsClient) -> tuple[TeamsBridgeDaemon, MemoryTransport]:
    transport = MemoryTransport()
    queue_client = StoneMQClient("teams", transport, instance="tenant-1")
    store = SessionStore(tmp_path / "teams_sessions")
    factory = FakeClientFactory(client)
    sessions = SessionManager(store, factory.create)
    daemon = TeamsBridgeDaemon(queue_client, sessions, default_user_id="acct-1", instance="tenant-1")
    return daemon, transport


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
    daemon, transport = _build_daemon(tmp_path, client)

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
    daemon, transport = _build_daemon(tmp_path, client)

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
        assert response["flow"]["kind"] == "embedded_browser_consent"

        await daemon.shutdown()

    _run(scenario)


def test_outbound_message_dispatch(tmp_path: Path) -> None:
    client = FakeTeamsClient()
    daemon, transport = _build_daemon(tmp_path, client)

    async def scenario() -> None:
        await _link_account(daemon, transport)
        envelope = build_envelope(
            "teams",
            "outbound_message",
            {
                "conversation_id": "chat-1",
                "message": {"body": {"contentType": "text", "content": "Hei"}},
            },
            metadata={"user_id": "acct-1", "tenant_id": "tenant-1"},
        )
        topic = "bridge/teams/tenant-1/outbound_message"
        await transport.publish(topic, envelope.to_json().encode("utf-8"))

        assert client.sent_messages[0]["message"]["body"]["content"] == "Hei"
        await daemon.shutdown()

    _run(scenario)


def test_ack_event_invokes_client(tmp_path: Path) -> None:
    client = FakeTeamsClient()
    daemon, transport = _build_daemon(tmp_path, client)

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
