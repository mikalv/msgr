"""Tests for the Signal bridge daemon."""

from __future__ import annotations

import asyncio
import json
from pathlib import Path
from typing import Awaitable, Callable, Dict, Mapping, Optional, Sequence

from msgr_bridge_sdk import StoneMQClient, build_envelope
from msgr_signal_bridge import (
    LinkingCode,
    SessionManager,
    SessionStore,
    SignalBridgeDaemon,
    SignalProfile,
)


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


class FakeSignalClient:
    def __init__(self, *, linked: bool = True) -> None:
        self.linked = linked
        self.profile = SignalProfile(uuid="uuid-123", phone_number="+4712345678", display_name="Alice")
        self.connected = False
        self.sent_messages: list[Mapping[str, object]] = []
        self.handlers: list[Callable[[Mapping[str, object]], Awaitable[None]]] = []
        self.linking_requests: list[Optional[str]] = []
        self.acked: list[str] = []
        self.capabilities: Mapping[str, object] = {
            "messaging": {"text": True, "attachments": ["image"]},
            "presence": {"typing": True},
        }
        self.contacts_snapshot: list[Mapping[str, object]] = []
        self.conversations_snapshot: list[Mapping[str, object]] = []

    async def connect(self) -> None:
        self.connected = True

    async def disconnect(self) -> None:
        self.connected = False

    async def is_linked(self) -> bool:
        return self.linked

    async def request_linking_code(self, *, device_name: Optional[str] = None) -> LinkingCode:
        self.linking_requests.append(device_name)
        return LinkingCode(
            verification_uri="https://signal.org/link",
            code="ABC-123",
            expires_at=456.0,
            device_name=device_name,
        )

    async def get_profile(self) -> SignalProfile:
        return self.profile

    async def send_text_message(
        self,
        chat_id: str,
        message: str,
        *,
        attachments: Optional[list[Mapping[str, object]]] = None,
        metadata: Optional[Mapping[str, object]] = None,
    ) -> Mapping[str, object]:
        payload = {
            "chat_id": chat_id,
            "message": message,
            "attachments": attachments,
            "metadata": metadata,
        }
        self.sent_messages.append(payload)
        return {"chat_id": chat_id, "message_id": len(self.sent_messages)}

    def add_event_handler(self, handler: Callable[[Mapping[str, object]], Awaitable[None]]) -> None:
        self.handlers.append(handler)

    def remove_event_handler(self, handler: Callable[[Mapping[str, object]], Awaitable[None]]) -> None:
        if handler in self.handlers:
            self.handlers.remove(handler)

    async def acknowledge_event(self, event_id: str) -> None:
        self.acked.append(event_id)

    async def dispatch_event(self, event: Mapping[str, object]) -> None:
        for handler in list(self.handlers):
            await handler(event)

    async def list_contacts(self) -> Sequence[Mapping[str, object]]:
        return list(self.contacts_snapshot)

    async def list_conversations(self) -> Sequence[Mapping[str, object]]:
        return list(self.conversations_snapshot)

    async def describe_capabilities(self) -> Mapping[str, object]:
        return self.capabilities


class FakeClientFactory:
    def __init__(self) -> None:
        self._registry: Dict[str, FakeSignalClient] = {}

    def register(self, key: str, client: FakeSignalClient) -> None:
        self._registry[key] = client

    def create(self, session_path: Path) -> FakeSignalClient:
        key = session_path.stem
        client = self._registry.get(key)
        if client is None:
            client = FakeSignalClient()
            self._registry[key] = client
        return client


def _build_daemon(
    tmp_path: Path, client: FakeSignalClient, *, linked: bool = True
) -> tuple[SignalBridgeDaemon, MemoryTransport, FakeClientFactory, SessionManager]:
    transport = MemoryTransport()
    queue_client = StoneMQClient("signal", transport)
    store = SessionStore(tmp_path / "signal_sessions")
    factory = FakeClientFactory()
    key = store.path_for("42").stem
    client.linked = linked
    factory.register(key, client)
    sessions = SessionManager(store, factory.create)
    daemon = SignalBridgeDaemon(queue_client, sessions, default_user_id="42")
    return daemon, transport, factory, sessions


def _run(async_fn: Callable[[], Awaitable[None]]) -> None:
    asyncio.run(async_fn())


def test_link_account_with_existing_session(tmp_path: Path) -> None:
    client = FakeSignalClient()
    client.contacts_snapshot = [{"uuid": "uuid-200", "name": "Bob"}]
    client.conversations_snapshot = [{"id": "chat-1", "type": "group", "title": "Friends"}]
    client.capabilities = {
        "messaging": {"text": True, "attachments": ["image", "video"]},
        "presence": {"typing": True},
    }
    daemon, transport, _, _ = _build_daemon(tmp_path, client)

    async def scenario() -> None:
        await daemon.start()
        request = build_envelope(
            "signal",
            "link_account",
            {
                "user_id": "42",
                "session": {},
            },
        )
        topic = "bridge/signal/link_account"
        response_raw = await transport.request(topic, request.to_json().encode("utf-8"))
        response = json.loads(response_raw.decode("utf-8"))

        assert response["status"] == "linked"
        assert response["user"]["uuid"] == "uuid-123"
        assert response["capabilities"]["messaging"]["attachments"] == ["image", "video"]
        assert response["contacts"][0]["uuid"] == "uuid-200"
        assert response["conversations"][0]["id"] == "chat-1"

        await client.dispatch_event({"event_id": "evt-1", "chat_id": "6789", "message": "hei"})
        update_topic = "bridge/signal/inbound_event"
        assert update_topic in transport.published
        envelope = json.loads(transport.published[update_topic].decode("utf-8"))
        assert envelope["payload"]["message"] == "hei"

    _run(scenario)


def test_link_account_requests_code_when_not_linked(tmp_path: Path) -> None:
    client = FakeSignalClient(linked=False)
    daemon, transport, _, _ = _build_daemon(tmp_path, client, linked=False)

    async def scenario() -> None:
        await daemon.start()
        request = build_envelope(
            "signal",
            "link_account",
            {
                "user_id": "42",
                "session": {},
                "linking": {"device_name": "Msgr Signal"},
            },
        )
        topic = "bridge/signal/link_account"
        response_raw = await transport.request(topic, request.to_json().encode("utf-8"))
        response = json.loads(response_raw.decode("utf-8"))

        assert response["status"] == "link_required"
        assert response["linking"]["verification_uri"] == "https://signal.org/link"
        assert client.linking_requests == ["Msgr Signal"]

    _run(scenario)


def test_outbound_message_sends_via_client(tmp_path: Path) -> None:
    client = FakeSignalClient()
    daemon, transport, _, _ = _build_daemon(tmp_path, client)

    async def scenario() -> None:
        await daemon.start()
        envelope = build_envelope(
            "signal",
            "outbound_message",
            {
                "chat_id": "+4798765432",
                "message": "hei",
                "attachments": [{"id": "file-1"}],
                "metadata": {"preview": False},
            },
            metadata={"user_id": "42"},
        )
        topic = "bridge/signal/outbound_message"
        await transport.publish(topic, envelope.to_json().encode("utf-8"))

        assert client.sent_messages == [
            {
                "chat_id": "+4798765432",
                "message": "hei",
                "attachments": [{"id": "file-1"}],
                "metadata": {"preview": False},
            }
        ]

    _run(scenario)


def test_ack_event_tracks_ack_state(tmp_path: Path) -> None:
    client = FakeSignalClient()
    daemon, transport, _, sessions = _build_daemon(tmp_path, client)

    async def scenario() -> None:
        await daemon.start()
        await sessions.ensure_client("42")
        envelope = build_envelope(
            "signal",
            "ack_event",
            {
                "event_id": "evt-99",
            },
            metadata={"user_id": "42"},
        )
        topic = "bridge/signal/ack_event"
        await transport.publish(topic, envelope.to_json().encode("utf-8"))

        assert client.acked == ["evt-99"]
        assert daemon.acked_events["evt-99"]["event_id"] == "evt-99"

    _run(scenario)
