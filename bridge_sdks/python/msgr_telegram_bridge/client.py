"""Telegram MTProto client abstractions used by the bridge daemon."""

from __future__ import annotations

import base64
from dataclasses import dataclass
from pathlib import Path
from typing import (
    Awaitable,
    Callable,
    Dict,
    Iterable,
    Mapping,
    Optional,
    Protocol,
    Sequence,
    Tuple,
)

UpdateHandler = Callable[[Mapping[str, object]], Awaitable[None]]


@dataclass(frozen=True)
class SentCode:
    """Result returned when Telegram sends a login code."""

    phone_code_hash: str


@dataclass(frozen=True)
class UserProfile:
    """Subset of Telegram user profile fields exposed to Msgr."""

    id: int
    username: Optional[str]
    first_name: Optional[str]
    last_name: Optional[str]

    def to_dict(self) -> Dict[str, Optional[str]]:
        return {
            "id": str(self.id),
            "username": self.username,
            "first_name": self.first_name,
            "last_name": self.last_name,
        }


@dataclass(frozen=True)
class DeviceInfo:
    """Device fingerprint used when emulating a Telegram client."""

    device_model: str = "MsgrBridge"
    system_version: str = "Linux"
    app_version: str = "1.0"
    lang_code: str = "en"
    system_lang_code: str = "en"


class PasswordRequiredError(Exception):
    """Raised when Telegram requests a 2FA password."""

    def __init__(self, phone_code_hash: str) -> None:
        super().__init__("Two-factor password required")
        self.phone_code_hash = phone_code_hash


class SignInError(Exception):
    """Raised when Telegram refuses the provided login code."""


@dataclass
class _AckContext:
    """Internal container for read acknowledgement metadata."""

    peer: object
    message_id: int


class TelegramClientProtocol(Protocol):
    """Protocol describing the Telegram functionality the daemon relies on."""

    async def connect(self) -> None:
        ...

    async def disconnect(self) -> None:
        ...

    async def is_authorized(self) -> bool:
        ...

    async def send_login_code(self, phone_number: str) -> SentCode:
        ...

    async def sign_in(
        self, phone_number: str, code: str, *, password: Optional[str] = None
    ) -> UserProfile:
        ...

    async def get_me(self) -> UserProfile:
        ...

    async def send_text_message(
        self,
        chat_id: int,
        message: str,
        *,
        entities: Optional[list] = None,
        reply_to: Optional[int] = None,
        media: Optional[Mapping[str, object]] = None,
    ) -> Mapping[str, object]:
        ...

    async def edit_text_message(
        self,
        chat_id: int,
        message_id: int,
        message: str,
        *,
        entities: Optional[list] = None,
    ) -> Mapping[str, object]:
        ...

    async def delete_messages(
        self,
        chat_id: int,
        message_ids: Sequence[int],
        *,
        revoke: bool = True,
    ) -> None:
        ...

    def add_update_handler(self, handler: UpdateHandler) -> None:
        ...

    def remove_update_handler(self, handler: UpdateHandler) -> None:
        ...

    async def acknowledge_update(self, update_id: int) -> None:
        ...

    async def send_read_acknowledge(self, peer: object, *, max_id: int) -> None:
        ...

    async def describe_capabilities(self) -> Mapping[str, object]:
        ...

    async def list_contacts(self) -> Sequence[Mapping[str, object]]:
        ...

    async def list_dialogs(self) -> Sequence[Mapping[str, object]]:
        ...


class TelethonClientFactory:
    """Factory producing Telethon-backed client instances."""

    def __init__(self, api_id: int, api_hash: str, *, device: Optional[DeviceInfo] = None) -> None:
        self._api_id = api_id
        self._api_hash = api_hash
        self._device = device or DeviceInfo()

    def create(self, session_path: Path) -> TelegramClientProtocol:
        return _TelethonClient(session_path, self._api_id, self._api_hash, self._device)


try:  # pragma: no cover - exercised in integration tests
    from telethon import TelegramClient, events, errors, types  # type: ignore
except ImportError:  # pragma: no cover - telethon not available during unit tests
    TelegramClient = None  # type: ignore
    events = None  # type: ignore
    errors = None  # type: ignore
    types = None  # type: ignore


class _TelethonClient(TelegramClientProtocol):  # pragma: no cover - requires telethon runtime
    """Adapter that translates Telethon's API into the bridge protocol."""

    def __init__(
        self, session_path: Path, api_id: int, api_hash: str, device: DeviceInfo
    ) -> None:
        if TelegramClient is None:
            raise RuntimeError(
                "telethon is not installed - install telethon to enable the Telegram bridge"
            )

        self._session_path = Path(session_path)
        self._session_path.parent.mkdir(parents=True, exist_ok=True)
        self._client = TelegramClient(
            str(self._session_path),
            api_id,
            api_hash,
            device_model=device.device_model,
            system_version=device.system_version,
            app_version=device.app_version,
            lang_code=device.lang_code,
            system_lang_code=device.system_lang_code,
        )
        self._handlers: Dict[UpdateHandler, Callable] = {}
        self._pending_acks: Dict[int, _AckContext] = {}

    async def connect(self) -> None:
        await self._client.connect()

    async def disconnect(self) -> None:
        await self._client.disconnect()

    async def is_authorized(self) -> bool:
        return await self._client.is_user_authorized()

    async def send_login_code(self, phone_number: str) -> SentCode:
        result = await self._client.send_code_request(phone_number)
        return SentCode(phone_code_hash=result.phone_code_hash)

    async def sign_in(
        self, phone_number: str, code: str, *, password: Optional[str] = None
    ) -> UserProfile:
        try:
            user = await self._client.sign_in(phone=phone_number, code=code, password=password)
        except errors.SessionPasswordNeededError as exc:  # type: ignore[attr-defined]
            raise PasswordRequiredError(getattr(exc, "phone_code_hash", "")) from exc
        except errors.PhoneCodeInvalidError as exc:  # type: ignore[attr-defined]
            raise SignInError(str(exc)) from exc
        return _normalise_user(user)

    async def get_me(self) -> UserProfile:
        user = await self._client.get_me()
        return _normalise_user(user)

    async def send_text_message(
        self,
        chat_id: int,
        message: str,
        *,
        entities: Optional[list] = None,
        reply_to: Optional[int] = None,
        media: Optional[Mapping[str, object]] = None,
    ) -> Mapping[str, object]:
        kwargs: Dict[str, object] = {"message": message}
        if entities is not None:
            kwargs["entities"] = entities
        if reply_to is not None:
            kwargs["reply_to"] = reply_to
        if media is not None:
            # Media handling will be implemented in a follow-up iteration.
            kwargs["file"] = media.get("file")
        message_obj = await self._client.send_message(chat_id, **kwargs)
        return {
            "message_id": getattr(message_obj, "id", None),
            "chat_id": chat_id,
        }

    async def edit_text_message(
        self,
        chat_id: int,
        message_id: int,
        message: str,
        *,
        entities: Optional[list] = None,
    ) -> Mapping[str, object]:
        kwargs: Dict[str, object] = {"message": message}
        if entities is not None:
            kwargs["entities"] = entities
        message_obj = await self._client.edit_message(chat_id, message_id, **kwargs)
        return {
            "message_id": getattr(message_obj, "id", message_id),
            "chat_id": chat_id,
        }

    async def delete_messages(
        self,
        chat_id: int,
        message_ids: Sequence[int],
        *,
        revoke: bool = True,
    ) -> None:
        await self._client.delete_messages(chat_id, list(message_ids), revoke=revoke)

    def add_update_handler(self, handler: UpdateHandler) -> None:
        async def _wrapped(event) -> None:
            payload, ack_context = await _normalise_update(self._client, event)
            if payload is not None:
                update_id = payload.get("update_id")
                if (
                    update_id is not None
                    and ack_context is not None
                    and isinstance(update_id, int)
                ):
                    self._pending_acks[int(update_id)] = ack_context
                await handler(payload)

        self._client.add_event_handler(_wrapped, events.Raw())
        self._handlers[handler] = _wrapped

    def remove_update_handler(self, handler: UpdateHandler) -> None:
        wrapped = self._handlers.pop(handler, None)
        if wrapped is not None:
            self._client.remove_event_handler(wrapped)

    async def acknowledge_update(self, update_id: int) -> None:
        context = self._pending_acks.pop(int(update_id), None)
        if context is None:
            return
        await self._client.send_read_acknowledge(
            context.peer, max_id=context.message_id
        )

    async def send_read_acknowledge(self, peer: object, *, max_id: int) -> None:
        await self._client.send_read_acknowledge(peer, max_id=max_id)

    async def describe_capabilities(self) -> Mapping[str, object]:
        return {
            "messaging": {
                "text": True,
                "replies": True,
                "edits": True,
                "deletes": True,
                "entities": True,
                "media_types": ["photo", "video", "audio", "voice", "file", "sticker"],
            },
            "presence": {"typing": True, "read_receipts": True},
            "threads": {"supported": False},
        }

    async def list_contacts(self) -> Sequence[Mapping[str, object]]:
        return []

    async def list_dialogs(self) -> Sequence[Mapping[str, object]]:
        return []


def _normalise_user(user) -> UserProfile:
    return UserProfile(
        id=getattr(user, "id", 0),
        username=getattr(user, "username", None),
        first_name=getattr(user, "first_name", None),
        last_name=getattr(user, "last_name", None),
    )


async def _normalise_update(client, event) -> Tuple[Optional[Dict[str, object]], Optional[_AckContext]]:
    update = getattr(event, "update", event)

    if isinstance(update, Mapping):
        payload = dict(update)
        payload.setdefault("update_type", "mapping")
        message_id = payload.get("message_id")
        peer = payload.get("peer")
        ack_context = None
        if peer is not None and message_id is not None:
            try:
                ack_context = _AckContext(peer=peer, message_id=int(message_id))
            except (TypeError, ValueError):
                ack_context = None
        return payload, ack_context

    if types is None:
        return None, None

    message_update_classes = [
        getattr(types, "UpdateNewMessage", None),
        getattr(types, "UpdateNewChannelMessage", None),
        getattr(types, "UpdateEditMessage", None),
        getattr(types, "UpdateEditChannelMessage", None),
    ]

    for klass in message_update_classes:
        if klass is not None and isinstance(update, klass):
            return await _normalise_message_update(client, update)

    return None, None


async def _normalise_message_update(client, update) -> Tuple[Optional[Dict[str, object]], Optional[_AckContext]]:
    message = getattr(update, "message", None)
    if message is None:
        return None, None

    update_id = getattr(update, "pts", None) or getattr(message, "id", None)
    peer = getattr(message, "peer_id", None)
    chat_id = _extract_peer_id(peer)
    if chat_id is None:
        return None, None

    text = getattr(message, "message", "") or ""
    message_id = getattr(message, "id", None)
    ack_context = None
    if peer is not None and message_id is not None:
        try:
            input_peer = await client.get_input_entity(peer)
        except Exception:  # pragma: no cover - Telethon raises rich errors
            input_peer = None
        if input_peer is not None:
            ack_context = _AckContext(peer=input_peer, message_id=int(message_id))

    payload: Dict[str, object] = {
        "update_id": int(update_id) if update_id is not None else None,
        "chat_id": chat_id,
        "message": text,
        "sender": getattr(message, "from_id", None),
        "update_type": type(update).__name__,
    }
    if message_id is not None:
        payload["message_id"] = int(message_id)

    reply_to = _extract_reply_to(message)
    if reply_to is not None:
        payload["reply_to"] = reply_to

    entities = getattr(message, "entities", None)
    if isinstance(entities, Iterable):
        serialised = [_serialise_entity(entity) for entity in entities]
        payload["entities"] = [entity for entity in serialised if entity is not None]

    media = getattr(message, "media", None)
    serialised_media = _serialise_media(media)
    if serialised_media is not None:
        payload["media"] = serialised_media

    return payload, ack_context


def _extract_peer_id(peer) -> Optional[int]:
    if peer is None:
        return None

    for attr in ("channel_id", "chat_id", "user_id"):
        value = getattr(peer, attr, None)
        if value is not None:
            return int(value)
    return None


def _extract_reply_to(message) -> Optional[int]:
    reply = getattr(message, "reply_to_msg_id", None)
    if reply is not None:
        try:
            return int(reply)
        except (TypeError, ValueError):
            return None
    reply_obj = getattr(message, "reply_to", None)
    if reply_obj is not None:
        for attr in ("reply_to_msg_id", "reply_to_msgid", "mid"):
            value = getattr(reply_obj, attr, None)
            if value is not None:
                try:
                    return int(value)
                except (TypeError, ValueError):
                    return None
    return None


def _serialise_entity(entity) -> Optional[Dict[str, object]]:
    if entity is None:
        return None
    if isinstance(entity, Mapping):
        return dict(entity)
    if hasattr(entity, "to_dict"):
        try:
            data = entity.to_dict()
            if isinstance(data, dict):
                data.setdefault("type", entity.__class__.__name__)
                return data
        except Exception:  # pragma: no cover - defensive conversion
            pass
    payload: Dict[str, object] = {"type": entity.__class__.__name__}
    for attr in ("offset", "length", "user_id"):
        value = getattr(entity, attr, None)
        if value is not None:
            payload[attr] = value
    return payload


def _serialise_media(media) -> Optional[Dict[str, object]]:
    if media is None:
        return None
    if isinstance(media, Mapping):
        return dict(media)
    if hasattr(media, "to_dict"):
        try:
            data = media.to_dict()
            if isinstance(data, dict):
                data.setdefault("type", media.__class__.__name__)
                return data
        except Exception:  # pragma: no cover - Telethon-specific conversions
            pass
    payload: Dict[str, object] = {"type": media.__class__.__name__}
    document = getattr(media, "document", None)
    if document is not None:
        for attr in ("id", "access_hash", "file_reference"):
            value = getattr(document, attr, None)
            if value is not None:
                payload.setdefault("document", {})[attr] = value
    photo = getattr(media, "photo", None)
    if photo is not None:
        payload.setdefault("photo", {"id": getattr(photo, "id", None)})
    return payload


def decode_session_blob(blob: str) -> bytes:
    """Decode a base64-encoded session blob into raw bytes."""

    return base64.b64decode(blob.encode("utf-8"))


def encode_session_blob(data: bytes) -> str:
    """Encode raw session bytes as URL-safe base64."""

    return base64.b64encode(data).decode("utf-8")
