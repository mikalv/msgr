"""Tests for the Telegram bridge daemon."""

from __future__ import annotations

import asyncio
import copy
import json
from pathlib import Path
from types import SimpleNamespace
from typing import Awaitable, Callable, Dict, Mapping, Optional, Sequence

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
        self.edited_messages: list[Mapping[str, object]] = []
        self.deleted_messages: list[Mapping[str, object]] = []
        self.handlers: list[Callable[[Mapping[str, object]], Awaitable[None]]] = []
        self.login_requests: list[str] = []
        self.sign_in_attempts: list[tuple[str, str, Optional[str]]] = []
        self.sign_in_error: Optional[Exception] = None
        self.require_password: Optional[PasswordRequiredError] = None
        self.acked: list[int] = []
        self.pending_ack: Dict[int, Dict[str, object]] = {}
        self.read_receipts: list[tuple[object, int]] = []
        self.capabilities: Mapping[str, object] = {
            "messaging": {"text": True, "media_types": ["image", "video"]},
            "presence": {"typing": True},
        }
        self.contacts_snapshot: list[Mapping[str, object]] = []
        self.dialogs_snapshot: list[Mapping[str, object]] = []

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

    async def edit_text_message(
        self,
        chat_id: int,
        message_id: int,
        message: str,
        *,
        entities: Optional[list] = None,
    ) -> Mapping[str, object]:
        payload = {
            "chat_id": chat_id,
            "message_id": message_id,
            "message": message,
            "entities": entities,
        }
        self.edited_messages.append(payload)
        return payload

    async def delete_messages(
        self,
        chat_id: int,
        message_ids: Sequence[int],
        *,
        revoke: bool = True,
    ) -> None:
        self.deleted_messages.append(
            {
                "chat_id": chat_id,
                "message_ids": list(message_ids),
                "revoke": revoke,
            }
        )

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

    async def describe_capabilities(self) -> Mapping[str, object]:
        return copy.deepcopy(self.capabilities)

    async def list_contacts(self) -> Sequence[Mapping[str, object]]:
        return list(self.contacts_snapshot)

    async def list_dialogs(self) -> Sequence[Mapping[str, object]]:
        return list(self.dialogs_snapshot)

    async def dispatch_update(self, update) -> None:
        peer_obj = None
        if isinstance(update, Mapping):
            payload = dict(update)
        else:
            message = getattr(update, "message", None)
            peer = getattr(message, "peer_id", None)
            peer_obj = peer
            chat_id = None
            if isinstance(peer, Mapping):
                chat_id = peer.get("chat_id") or peer.get("channel_id") or peer.get("user_id")
            else:
                for attr in ("channel_id", "chat_id", "user_id"):
                    value = getattr(peer, attr, None)
                    if value is not None:
                        chat_id = value
                        break
            payload = {
                "update_id": getattr(update, "pts", getattr(message, "id", 0)),
                "chat_id": chat_id,
                "message": getattr(message, "message", ""),
                "sender": getattr(message, "from_id", None),
                "message_id": getattr(message, "id", None),
                "update_type": update.__class__.__name__,
            }
            reply = getattr(message, "reply_to_msg_id", None)
            if reply is not None:
                payload["reply_to"] = reply
            entities = getattr(message, "entities", None)
            if entities is not None:
                payload["entities"] = [
                    getattr(entity, "__dict__", dict(entity)) if isinstance(entity, Mapping) else {
                        "type": entity.__class__.__name__,
                        "offset": getattr(entity, "offset", None),
                        "length": getattr(entity, "length", None),
                    }
                    for entity in entities
                ]
            media = getattr(message, "media", None)
            if media is not None:
                if hasattr(media, "to_dict"):
                    payload["media"] = media.to_dict()
                elif isinstance(media, Mapping):
                    payload["media"] = dict(media)
                else:
                    payload["media"] = {"type": media.__class__.__name__}

        update_id = int(payload.get("update_id", 0) or 0)
        message_id = int(payload.get("message_id", update_id) or 0)
        peer = peer_obj if peer_obj is not None else payload.get("peer", payload.get("chat_id"))
        self.pending_ack[update_id] = {"peer": peer, "message_id": message_id}
        for handler in list(self.handlers):
            await handler({k: v for k, v in payload.items() if k != "peer"})


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
    client.contacts_snapshot = [
        {"id": "200", "username": "bob", "first_name": "Bob", "last_name": "Builder"}
    ]
    client.dialogs_snapshot = [
        {"id": 99, "name": "Team Chat", "type": "supergroup"}
    ]
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
        assert response["capabilities"]["messaging"]["text"]
        assert response["contacts"][0]["id"] == "200"
        assert response["chats"][0]["id"] == 99

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


def test_edit_message_routes_to_client(tmp_path: Path) -> None:
    client = FakeTelegramClient()
    daemon, transport, _, _ = _build_daemon(tmp_path, client)

    async def scenario() -> None:
        await daemon.start()
        request = _link_payload(b"seed-session")
        topic = "bridge/telegram/link_account"
        await transport.request(topic, request.to_json().encode("utf-8"))

        outbound = build_envelope(
            "telegram",
            "outbound_edit_message",
            {"chat_id": 200, "message_id": 10, "message": "Hei", "entities": [{"type": "bold"}]},
            metadata={"user_id": "42"},
        )
        outbound_topic = "bridge/telegram/outbound_edit_message"
        await transport.publish(outbound_topic, outbound.to_json().encode("utf-8"))

        assert client.edited_messages == [
            {
                "chat_id": 200,
                "message_id": 10,
                "message": "Hei",
                "entities": [{"type": "bold"}],
            }
        ]

    _run(scenario)


def test_delete_message_routes_to_client(tmp_path: Path) -> None:
    client = FakeTelegramClient()
    daemon, transport, _, _ = _build_daemon(tmp_path, client)

    async def scenario() -> None:
        await daemon.start()
        request = _link_payload(b"seed-session")
        topic = "bridge/telegram/link_account"
        await transport.request(topic, request.to_json().encode("utf-8"))

        outbound = build_envelope(
            "telegram",
            "outbound_delete_message",
            {"chat_id": 200, "message_ids": [10, 11], "revoke": False},
            metadata={"user_id": "42"},
        )
        outbound_topic = "bridge/telegram/outbound_delete_message"
        await transport.publish(outbound_topic, outbound.to_json().encode("utf-8"))

        assert client.deleted_messages == [
            {"chat_id": 200, "message_ids": [10, 11], "revoke": False}
        ]

    _run(scenario)


def test_inbound_update_from_object(tmp_path: Path) -> None:
    client = FakeTelegramClient()
    daemon, transport, _, _ = _build_daemon(tmp_path, client)

    from msgr_telegram_bridge import client as telegram_client_module

    original_types = telegram_client_module.types

    class StubPeer:
        def __init__(self) -> None:
            self.user_id = 321

    class StubEntity:
        def __init__(self) -> None:
            self.offset = 0
            self.length = 4

    class StubMedia:
        def to_dict(self) -> Mapping[str, object]:
            return {"type": "photo", "id": "media-1"}

    class StubMessage:
        def __init__(self) -> None:
            self.id = 12
            self.message = "Ping"
            self.peer_id = StubPeer()
            self.from_id = 777
            self.reply_to_msg_id = 5
            self.entities = [StubEntity()]
            self.media = StubMedia()

    class StubUpdate:
        def __init__(self) -> None:
            self.message = StubMessage()
            self.pts = 200

    telegram_client_module.types = SimpleNamespace(
        UpdateNewMessage=StubUpdate,
        UpdateNewChannelMessage=None,
        UpdateEditMessage=None,
        UpdateEditChannelMessage=None,
    )

    async def scenario() -> None:
        await daemon.start()
        request = _link_payload(b"seed-session")
        topic = "bridge/telegram/link_account"
        await transport.request(topic, request.to_json().encode("utf-8"))

        await client.dispatch_update(StubUpdate())

        update_topic = "bridge/telegram/inbound_update"
        assert update_topic in transport.published
        envelope = json.loads(transport.published[update_topic].decode("utf-8"))
        payload = envelope["payload"]
        assert payload["update_type"] == "StubUpdate"
        assert payload["entities"]
        assert payload["media"]["type"] == "photo"
        assert payload["reply_to"] == 5

    try:
        _run(scenario)
    finally:
        telegram_client_module.types = original_types


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
