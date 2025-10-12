"""Tests for the Telegram bridge daemon."""

from __future__ import annotations

import asyncio
import json
from pathlib import Path
from typing import Awaitable, Callable, Dict, Mapping, Optional

from msgr_bridge_sdk import StoneMQClient, build_envelope
from msgr_telegram_bridge import SessionManager, SessionStore, TelegramBridgeDaemon
from msgr_telegram_bridge.client import PasswordRequiredError, SentCode, UserProfile, encode_session_blob


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


class FakeTelegramClient:
    def __init__(self, *, authorized: bool = True) -> None:
        self.authorized = authorized
        self.profile = UserProfile(id=100, username="alice", first_name="Alice", last_name=None)
        self.connected = False
        self.sent_messages: list[Mapping[str, object]] = []
        self.handlers: list[Callable[[Mapping[str, object]], Awaitable[None]]] = []
        self.login_requests: list[str] = []
        self.sign_in_attempts: list[tuple[str, str, Optional[str]]] = []
        self.sign_in_error: Optional[Exception] = None
        self.require_password: Optional[PasswordRequiredError] = None
        self.acked: list[int] = []
        self.pending_ack: Dict[int, Dict[str, object]] = {}
        self.read_receipts: list[tuple[object, int]] = []

    async def connect(self) -> None:
        self.connected = True

    async def disconnect(self) -> None:
        self.connected = False

    async def is_authorized(self) -> bool:
        return self.authorized

    async def send_login_code(self, phone_number: str) -> SentCode:
        self.login_requests.append(phone_number)
        return SentCode(phone_code_hash="hash-123")

    async def sign_in(self, phone_number: str, code: str, *, password: Optional[str] = None) -> UserProfile:
        self.sign_in_attempts.append((phone_number, code, password))
        if self.require_password is not None:
            raise self.require_password
        if self.sign_in_error is not None:
            raise self.sign_in_error
        self.authorized = True
        return self.profile

    async def get_me(self) -> UserProfile:
        return self.profile

    async def send_text_message(
        self,
        chat_id: int,
        message: str,
        *,
        entities: Optional[list] = None,
        reply_to: Optional[int] = None,
        media: Optional[Mapping[str, object]] = None,
    ) -> Mapping[str, object]:
        payload = {
            "chat_id": chat_id,
            "message": message,
            "entities": entities,
            "reply_to": reply_to,
            "media": media,
        }
        self.sent_messages.append(payload)
        return {"chat_id": chat_id, "message_id": len(self.sent_messages)}

    def add_update_handler(self, handler: Callable[[Mapping[str, object]], Awaitable[None]]) -> None:
        self.handlers.append(handler)

    def remove_update_handler(self, handler: Callable[[Mapping[str, object]], Awaitable[None]]) -> None:
        if handler in self.handlers:
            self.handlers.remove(handler)

    async def acknowledge_update(self, update_id: int) -> None:
        info = self.pending_ack.pop(int(update_id), None)
        if info is None:
            return
        await self.send_read_acknowledge(info["peer"], max_id=int(info["message_id"]))
        self.acked.append(int(update_id))

    async def get_input_entity(self, peer: object) -> object:
        return peer

    async def send_read_acknowledge(self, peer: object, *, max_id: int) -> None:
        self.read_receipts.append((peer, max_id))

    async def dispatch_update(self, update: Mapping[str, object]) -> None:
        update_id = int(update.get("update_id", 0))
        message_id = int(update.get("message_id", update_id))
        peer = update.get("peer", update.get("chat_id"))
        self.pending_ack[update_id] = {"peer": peer, "message_id": message_id}
        for handler in list(self.handlers):
            await handler(update)


class FakeClientFactory:
    def __init__(self) -> None:
        self._registry: Dict[str, FakeTelegramClient] = {}

    def register(self, key: str, client: FakeTelegramClient) -> None:
        self._registry[key] = client

    def create(self, session_path: Path) -> FakeTelegramClient:
        key = session_path.stem
        client = self._registry.get(key)
        if client is None:
            client = FakeTelegramClient()
            self._registry[key] = client
        return client


def _build_daemon(tmp_path: Path, client: FakeTelegramClient, *, authorized: bool = True) -> tuple[TelegramBridgeDaemon, MemoryTransport, FakeClientFactory, SessionManager]:
    transport = MemoryTransport()
    queue_client = StoneMQClient("telegram", transport)
    store = SessionStore(tmp_path / "sessions")
    factory = FakeClientFactory()
    key = store.path_for("42").stem
    client.authorized = authorized
    factory.register(key, client)
    sessions = SessionManager(store, factory.create)
    daemon = TelegramBridgeDaemon(queue_client, sessions, default_user_id="42")
    return daemon, transport, factory, sessions


def _link_payload(session_blob: bytes, *, include_code: bool = False) -> Envelope:
    payload = {
        "user_id": "42",
        "session": {"blob": encode_session_blob(session_blob)},
        "phone_number": "+4712345678",
    }
    if include_code:
        payload["session"]["code"] = "12345"
    return build_envelope("telegram", "link_account", payload)


def _run(async_fn: Callable[[], Awaitable[None]]) -> None:
    asyncio.run(async_fn())


def test_link_account_with_existing_session(tmp_path: Path) -> None:
    client = FakeTelegramClient()
    daemon, transport, _, _ = _build_daemon(tmp_path, client)

    async def scenario() -> None:
        await daemon.start()
        request = _link_payload(b"seed-session")
        topic = "bridge/telegram/link_account"
        response_raw = await transport.request(topic, request.to_json().encode("utf-8"))
        response = json.loads(response_raw.decode("utf-8"))

        assert response["status"] == "linked"
        assert response["user"]["username"] == "alice"
        assert "session" in response

        await client.dispatch_update(
            {
                "update_id": 1,
                "message_id": 1,
                "chat_id": 99,
                "message": "hi",
                "peer": "peer-99",
            }
        )
        update_topic = "bridge/telegram/inbound_update"
        assert update_topic in transport.published
        envelope = json.loads(transport.published[update_topic].decode("utf-8"))
        assert envelope["payload"]["message"] == "hi"

    _run(scenario)


def test_link_account_requests_code_when_not_authorized(tmp_path: Path) -> None:
    client = FakeTelegramClient(authorized=False)
    daemon, transport, _, _ = _build_daemon(tmp_path, client, authorized=False)

    async def scenario() -> None:
        await daemon.start()
        request = _link_payload(b"seed-session")
        topic = "bridge/telegram/link_account"
        response_raw = await transport.request(topic, request.to_json().encode("utf-8"))
        response = json.loads(response_raw.decode("utf-8"))

        assert response == {"status": "code_required", "phone_code_hash": "hash-123"}
        assert client.login_requests == ["+4712345678"]

    _run(scenario)


def test_link_account_requires_password(tmp_path: Path) -> None:
    client = FakeTelegramClient(authorized=False)
    client.require_password = PasswordRequiredError("hash-abc")
    daemon, transport, _, _ = _build_daemon(tmp_path, client, authorized=False)

    async def scenario() -> None:
        await daemon.start()
        request = _link_payload(b"seed-session", include_code=True)
        topic = "bridge/telegram/link_account"
        response_raw = await transport.request(topic, request.to_json().encode("utf-8"))
        response = json.loads(response_raw.decode("utf-8"))

        assert response == {"status": "password_required", "phone_code_hash": "hash-abc"}
        assert client.sign_in_attempts == [("+4712345678", "12345", None)]

    _run(scenario)


def test_outbound_message_routes_to_client(tmp_path: Path) -> None:
    client = FakeTelegramClient()
    daemon, transport, _, _ = _build_daemon(tmp_path, client)

    async def scenario() -> None:
        await daemon.start()
        request = _link_payload(b"seed-session")
        topic = "bridge/telegram/link_account"
        await transport.request(topic, request.to_json().encode("utf-8"))

        outbound = build_envelope(
            "telegram",
            "outbound_message",
            {"chat_id": 200, "message": "Hello"},
            metadata={"user_id": "42"},
        )
        outbound_topic = "bridge/telegram/outbound_message"
        await transport.publish(outbound_topic, outbound.to_json().encode("utf-8"))

        assert client.sent_messages == [
            {
                "chat_id": 200,
                "message": "Hello",
                "entities": None,
                "reply_to": None,
                "media": None,
            }
        ]

    _run(scenario)


def test_ack_update_marks_state(tmp_path: Path) -> None:
    client = FakeTelegramClient()
    daemon, transport, _, _ = _build_daemon(tmp_path, client)

    async def scenario() -> None:
        await daemon.start()
        request = _link_payload(b"seed-session")
        topic = "bridge/telegram/link_account"
        await transport.request(topic, request.to_json().encode("utf-8"))

        await client.dispatch_update(
            {
                "update_id": 77,
                "message_id": 77,
                "chat_id": 200,
                "message": "stored",  # message content irrelevant
                "peer": "peer-200",
            }
        )
        ack = build_envelope(
            "telegram",
            "ack_update",
            {"update_id": 77, "status": "stored"},
            metadata={"user_id": "42"},
        )
        ack_topic = "bridge/telegram/ack_update"
        await transport.publish(ack_topic, ack.to_json().encode("utf-8"))

        assert daemon.acked_updates[77] == {"update_id": 77, "status": "stored"}
        assert client.acked == [77]
        assert client.read_receipts == [("peer-200", 77)]

    _run(scenario)


def test_ack_update_ignores_unknown_updates(tmp_path: Path) -> None:
    client = FakeTelegramClient()
    daemon, transport, _, _ = _build_daemon(tmp_path, client)

    async def scenario() -> None:
        await daemon.start()
        request = _link_payload(b"seed-session")
        topic = "bridge/telegram/link_account"
        await transport.request(topic, request.to_json().encode("utf-8"))

        ack = build_envelope(
            "telegram",
            "ack_update",
            {"update_id": 55, "status": "stored"},
            metadata={"user_id": "42"},
        )
        ack_topic = "bridge/telegram/ack_update"
        await transport.publish(ack_topic, ack.to_json().encode("utf-8"))

        assert daemon.acked_updates[55]["status"] == "stored"
        assert client.acked == []
        assert client.read_receipts == []

    _run(scenario)
