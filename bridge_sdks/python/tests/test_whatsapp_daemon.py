"""Tests for the WhatsApp bridge daemon."""

from __future__ import annotations

import asyncio
import json
from pathlib import Path
from typing import Awaitable, Callable, Dict, Mapping, Optional

from msgr_bridge_sdk import StoneMQClient, build_envelope
from msgr_whatsapp_bridge import (
    PairingCode,
    SessionManager,
    SessionStore,
    UserProfile,
    WhatsAppBridgeDaemon,
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


class FakeWhatsAppClient:
    def __init__(self, *, paired: bool = True) -> None:
        self.paired = paired
        self.profile = UserProfile(jid="12345@s.whatsapp.net", display_name="Alice", phone_number="+4712345678")
        self.connected = False
        self.sent_messages: list[Mapping[str, object]] = []
        self.handlers: list[Callable[[Mapping[str, object]], Awaitable[None]]] = []
        self.pairing_requests: list[Optional[str]] = []
        self.acked: list[str] = []

    async def connect(self) -> None:
        self.connected = True

    async def disconnect(self) -> None:
        self.connected = False

    async def is_paired(self) -> bool:
        return self.paired

    async def request_pairing(self, *, client_name: Optional[str] = None) -> PairingCode:
        self.pairing_requests.append(client_name)
        return PairingCode(qr_data="qr-blob", expires_at=123.0, client_name=client_name)

    async def get_profile(self) -> UserProfile:
        return self.profile

    async def send_text_message(
        self,
        chat_id: str,
        message: str,
        *,
        metadata: Optional[Mapping[str, object]] = None,
    ) -> Mapping[str, object]:
        payload = {
            "chat_id": chat_id,
            "message": message,
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


class FakeClientFactory:
    def __init__(self) -> None:
        self._registry: Dict[str, FakeWhatsAppClient] = {}

    def register(self, key: str, client: FakeWhatsAppClient) -> None:
        self._registry[key] = client

    def create(self, session_path: Path) -> FakeWhatsAppClient:
        key = session_path.stem
        client = self._registry.get(key)
        if client is None:
            client = FakeWhatsAppClient()
            self._registry[key] = client
        return client


def _build_daemon(
    tmp_path: Path, client: FakeWhatsAppClient, *, paired: bool = True
) -> tuple[WhatsAppBridgeDaemon, MemoryTransport, FakeClientFactory, SessionManager]:
    transport = MemoryTransport()
    queue_client = StoneMQClient("whatsapp", transport)
    store = SessionStore(tmp_path / "sessions")
    factory = FakeClientFactory()
    key = store.path_for("42").stem
    client.paired = paired
    factory.register(key, client)
    sessions = SessionManager(store, factory.create)
    daemon = WhatsAppBridgeDaemon(queue_client, sessions, default_user_id="42")
    return daemon, transport, factory, sessions


def _run(async_fn: Callable[[], Awaitable[None]]) -> None:
    asyncio.run(async_fn())


def test_link_account_with_existing_session(tmp_path: Path) -> None:
    client = FakeWhatsAppClient()
    daemon, transport, _, _ = _build_daemon(tmp_path, client)

    async def scenario() -> None:
        await daemon.start()
        request = build_envelope(
            "whatsapp",
            "link_account",
            {
                "user_id": "42",
                "session": {},
            },
        )
        topic = "bridge/whatsapp/link_account"
        response_raw = await transport.request(topic, request.to_json().encode("utf-8"))
        response = json.loads(response_raw.decode("utf-8"))

        assert response["status"] == "linked"
        assert response["user"]["jid"] == "12345@s.whatsapp.net"

        await client.dispatch_event({"event_id": "evt-1", "chat_id": "6789", "message": "hei"})
        update_topic = "bridge/whatsapp/inbound_event"
        assert update_topic in transport.published
        envelope = json.loads(transport.published[update_topic].decode("utf-8"))
        assert envelope["payload"]["message"] == "hei"

    _run(scenario)


def test_link_account_requests_qr_when_not_paired(tmp_path: Path) -> None:
    client = FakeWhatsAppClient(paired=False)
    daemon, transport, _, _ = _build_daemon(tmp_path, client, paired=False)

    async def scenario() -> None:
        await daemon.start()
        request = build_envelope(
            "whatsapp",
            "link_account",
            {
                "user_id": "42",
                "session": {},
                "pairing": {"client_name": "Msgr Bridge"},
            },
        )
        topic = "bridge/whatsapp/link_account"
        response_raw = await transport.request(topic, request.to_json().encode("utf-8"))
        response = json.loads(response_raw.decode("utf-8"))

        assert response["status"] == "qr_required"
        assert response["pairing"]["qr_data"] == "qr-blob"
        assert client.pairing_requests == ["Msgr Bridge"]

    _run(scenario)


def test_outbound_message_sends_via_client(tmp_path: Path) -> None:
    client = FakeWhatsAppClient()
    daemon, transport, _, _ = _build_daemon(tmp_path, client)

    async def scenario() -> None:
        await daemon.start()
        envelope = build_envelope(
            "whatsapp",
            "outbound_message",
            {
                "chat_id": "6789@s.whatsapp.net",
                "message": "hei",
                "metadata": {"preview": False},
            },
            metadata={"user_id": "42"},
        )
        topic = "bridge/whatsapp/outbound_message"
        await transport.publish(topic, envelope.to_json().encode("utf-8"))

        assert client.sent_messages == [
            {"chat_id": "6789@s.whatsapp.net", "message": "hei", "metadata": {"preview": False}}
        ]

    _run(scenario)


def test_ack_event_tracks_ack_state(tmp_path: Path) -> None:
    client = FakeWhatsAppClient()
    daemon, transport, _, sessions = _build_daemon(tmp_path, client)

    async def scenario() -> None:
        await daemon.start()
        await sessions.ensure_client("42")
        envelope = build_envelope(
            "whatsapp",
            "ack_event",
            {
                "event_id": "evt-99",
            },
            metadata={"user_id": "42"},
        )
        topic = "bridge/whatsapp/ack_event"
        await transport.publish(topic, envelope.to_json().encode("utf-8"))

        assert client.acked == ["evt-99"]
        assert daemon.acked_events["evt-99"]["event_id"] == "evt-99"

    _run(scenario)
