"""Tests for the Matrix bridge daemon."""

from __future__ import annotations

import asyncio
import json
from pathlib import Path
from typing import Awaitable, Callable, Dict, Mapping, Optional

from msgr_bridge_sdk import StoneMQClient, build_envelope
from msgr_matrix_bridge import MatrixBridgeDaemon, MatrixSessionManager, MatrixSessionStore
from msgr_matrix_bridge.client import AuthenticationError, MatrixEvent, MatrixProfile, MatrixSession


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


class FakeMatrixClient:
    def __init__(self, *, session: MatrixSession, profile: Optional[MatrixProfile] = None) -> None:
        self.session = session
        self.profile = profile or MatrixProfile(user_id=session.user_id, display_name="Alice", avatar_url=None)
        self.ensure_calls: list[tuple[Optional[str], Optional[str], Optional[str]]] = []
        self.sent_messages: list[tuple[str, str, Optional[str]]] = []
        self.acks: list[str] = []
        self.handlers: list[Callable[[MatrixEvent], Awaitable[None]]] = []
        self.closed = False
        self.raise_on_login: Optional[Exception] = None

    async def ensure_logged_in(
        self,
        *,
        access_token: Optional[str],
        username: Optional[str],
        password: Optional[str],
    ) -> MatrixSession:
        self.ensure_calls.append((access_token, username, password))
        if self.raise_on_login:
            raise self.raise_on_login
        return self.session

    async def get_profile(self) -> MatrixProfile:
        return self.profile

    def add_update_handler(self, handler: Callable[[MatrixEvent], Awaitable[None]]) -> None:
        if handler not in self.handlers:
            self.handlers.append(handler)

    def remove_update_handler(self, handler: Callable[[MatrixEvent], Awaitable[None]]) -> None:
        if handler in self.handlers:
            self.handlers.remove(handler)

    async def send_text(self, room_id: str, message: str, *, txn_id: Optional[str] = None) -> Mapping[str, object]:
        self.sent_messages.append((room_id, message, txn_id))
        return {"event_id": "$event"}

    async def acknowledge(self, event_id: str) -> None:
        self.acks.append(event_id)

    async def close(self) -> None:
        self.closed = True

    async def emit(self, event: MatrixEvent) -> None:
        for handler in list(self.handlers):
            await handler(event)


class FakeFactory:
    def __init__(self, client: FakeMatrixClient) -> None:
        self.client = client
        self.calls: list[tuple[str, Optional[MatrixSession]]] = []

    def __call__(self, homeserver: str, session: Optional[MatrixSession]) -> FakeMatrixClient:
        self.calls.append((homeserver, session))
        return self.client

def test_link_account_with_password(tmp_path: Path) -> None:
    async def scenario() -> None:
        transport = MemoryTransport()
        store = MatrixSessionStore(tmp_path)
        session = MatrixSession(
            user_id="@alice:example.org",
            access_token="token123",
            device_id="device",
            homeserver="https://example.org",
        )
        client = FakeMatrixClient(session=session)
        manager = MatrixSessionManager(store, FakeFactory(client))
        mq_client = StoneMQClient("matrix", transport)
        daemon = MatrixBridgeDaemon(
            mq_client,
            manager,
            default_homeserver="https://example.org",
        )

        await daemon.start()

        envelope = build_envelope(
            "matrix",
            "link_account",
            {"credentials": {"username": "@alice:example.org", "password": "secret"}},
            metadata={"user_id": "@alice:example.org"},
        )

        topic = "bridge/matrix/link_account"
        response_raw = await transport.request(topic, envelope.to_json().encode("utf-8"))
        response = json.loads(response_raw.decode("utf-8"))

        assert response["status"] == "linked"
        assert response["session"]["access_token"] == "token123"
        assert client.ensure_calls[-1] == (None, "@alice:example.org", "secret")

        exported = await manager.export_session("@alice:example.org", "https://example.org")
        assert exported is not None
        assert exported["access_token"] == "token123"

    asyncio.run(scenario())


def test_link_account_auth_failure(tmp_path: Path) -> None:
    async def scenario() -> None:
        transport = MemoryTransport()
        store = MatrixSessionStore(tmp_path)
        session = MatrixSession(
            user_id="@alice:example.org",
            access_token="token123",
            device_id="device",
            homeserver="https://example.org",
        )
        client = FakeMatrixClient(session=session)
        client.raise_on_login = AuthenticationError("invalid")
        manager = MatrixSessionManager(store, FakeFactory(client))
        mq_client = StoneMQClient("matrix", transport)
        daemon = MatrixBridgeDaemon(
            mq_client,
            manager,
            default_homeserver="https://example.org",
        )

        await daemon.start()

        envelope = build_envelope(
            "matrix",
            "link_account",
            {"credentials": {"username": "@alice:example.org", "password": "wrong"}},
            metadata={"user_id": "@alice:example.org"},
        )

        topic = "bridge/matrix/link_account"
        response_raw = await transport.request(topic, envelope.to_json().encode("utf-8"))
        response = json.loads(response_raw.decode("utf-8"))

        assert response["status"] == "auth_failed"
        exported = await manager.export_session("@alice:example.org", "https://example.org")
        assert exported is None

    asyncio.run(scenario())


def test_outbound_message_and_inbound_event(tmp_path: Path) -> None:
    async def scenario() -> None:
        transport = MemoryTransport()
        store = MatrixSessionStore(tmp_path)
        session = MatrixSession(
            user_id="@alice:example.org",
            access_token="token123",
            device_id="device",
            homeserver="https://example.org",
        )
        client = FakeMatrixClient(session=session)
        manager = MatrixSessionManager(store, FakeFactory(client))
        mq_client = StoneMQClient("matrix", transport)
        daemon = MatrixBridgeDaemon(
            mq_client,
            manager,
            default_homeserver="https://example.org",
        )

        await daemon.start()

        link_envelope = build_envelope(
            "matrix",
            "link_account",
            {"credentials": {"username": "@alice:example.org", "password": "secret"}},
            metadata={"user_id": "@alice:example.org"},
        )
        await transport.request("bridge/matrix/link_account", link_envelope.to_json().encode("utf-8"))

        outbound = build_envelope(
            "matrix",
            "outbound_message",
            {"room_id": "!room:example.org", "message": "Hello"},
            metadata={"user_id": "@alice:example.org", "homeserver": "https://example.org"},
        )
        await transport.publish("bridge/matrix/outbound_message", outbound.to_json().encode("utf-8"))
        assert client.sent_messages == [("!room:example.org", "Hello", None)]

        event = MatrixEvent(
            event_id="$event",
            room_id="!room:example.org",
            sender="@bob:example.org",
            body={"body": "hi", "msgtype": "m.text"},
        )
        await client.emit(event)

        published = transport.published.get("bridge/matrix/inbound_event")
        assert published is not None
        payload = json.loads(published.decode("utf-8"))
        assert payload["payload"]["event_id"] == "$event"

        ack = build_envelope(
            "matrix",
            "ack_update",
            {"event_id": "$event"},
            metadata={"user_id": "@alice:example.org", "homeserver": "https://example.org"},
        )
        await transport.publish("bridge/matrix/ack_update", ack.to_json().encode("utf-8"))
        assert client.acks == ["$event"]

        await daemon.shutdown()
        assert client.closed is True

    asyncio.run(scenario())
