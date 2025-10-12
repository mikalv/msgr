"""Matrix client abstractions for the Msgr bridge."""

from __future__ import annotations

import asyncio
import contextlib
from dataclasses import dataclass
from typing import Awaitable, Callable, Dict, Mapping, Optional, Protocol


class AuthenticationError(Exception):
    """Raised when the homeserver rejects our credentials."""


class SessionRevokedError(Exception):
    """Raised when a stored session can no longer be used."""


@dataclass
class MatrixSession:
    """Session information required to resume a Matrix login."""

    user_id: str
    access_token: str
    device_id: str
    homeserver: str

    def to_dict(self) -> Dict[str, str]:
        return {
            "user_id": self.user_id,
            "access_token": self.access_token,
            "device_id": self.device_id,
            "homeserver": self.homeserver,
        }

    @classmethod
    def from_mapping(cls, data: Mapping[str, object]) -> "MatrixSession":
        try:
            user_id = str(data["user_id"])
            access_token = str(data["access_token"])
            device_id = str(data["device_id"])
        except KeyError as exc:  # pragma: no cover - defensive
            raise ValueError("session mapping missing keys") from exc
        homeserver = str(data.get("homeserver", ""))
        if not homeserver:
            raise ValueError("homeserver is required in the session mapping")
        return cls(user_id=user_id, access_token=access_token, device_id=device_id, homeserver=homeserver)


@dataclass
class MatrixProfile:
    """Basic profile information for the linked Matrix account."""

    user_id: str
    display_name: Optional[str]
    avatar_url: Optional[str]

    def to_dict(self) -> Dict[str, Optional[str]]:
        return {
            "user_id": self.user_id,
            "display_name": self.display_name,
            "avatar_url": self.avatar_url,
        }


@dataclass
class MatrixEvent:
    """Inbound Matrix event delivered to Msgr."""

    event_id: str
    room_id: str
    sender: str
    body: Mapping[str, object]

    def to_payload(self) -> Dict[str, object]:
        return {
            "event_id": self.event_id,
            "room_id": self.room_id,
            "sender": self.sender,
            "body": dict(self.body),
        }


class MatrixClientProtocol(Protocol):
    """Interface implemented by Matrix client adapters."""

    def add_update_handler(self, handler: Callable[[MatrixEvent], Awaitable[None]]) -> None:
        ...

    def remove_update_handler(self, handler: Callable[[MatrixEvent], Awaitable[None]]) -> None:
        ...

    async def ensure_logged_in(
        self,
        *,
        access_token: Optional[str],
        username: Optional[str],
        password: Optional[str],
    ) -> MatrixSession:
        ...

    async def get_profile(self) -> MatrixProfile:
        ...

    async def send_text(
        self,
        room_id: str,
        message: str,
        *,
        txn_id: Optional[str] = None,
    ) -> Mapping[str, object]:
        ...

    async def acknowledge(self, event_id: str) -> None:
        ...

    async def close(self) -> None:
        ...


class MatrixClient(MatrixClientProtocol):
    """Async client built on top of matrix-nio."""

    def __init__(self, homeserver: str, session: Optional[MatrixSession] = None) -> None:
        self._homeserver = homeserver.rstrip("/")
        try:
            from nio import AsyncClient, AsyncClientConfig  # type: ignore
        except ImportError as exc:  # pragma: no cover - exercised in production
            raise RuntimeError(
                "matrix-nio must be installed to use MatrixClient"
            ) from exc

        config = AsyncClientConfig(encryption_enabled=False, store_sync_tokens=True)
        self._client = AsyncClient(self._homeserver, config=config)
        self._handlers: list[Callable[[MatrixEvent], Awaitable[None]]] = []
        self._sync_task: Optional[asyncio.Task[None]] = None
        if session is not None:
            self._apply_session(session)

    async def ensure_logged_in(
        self,
        *,
        access_token: Optional[str],
        username: Optional[str],
        password: Optional[str],
    ) -> MatrixSession:
        if access_token:
            self._apply_session(
                MatrixSession(
                    user_id=username or self._client.user_id or "",
                    access_token=access_token,
                    device_id=self._client.device_id or "",
                    homeserver=self._homeserver,
                )
            )

        if self._client.access_token and self._client.user_id:
            return MatrixSession(
                user_id=self._client.user_id,
                access_token=self._client.access_token,
                device_id=self._client.device_id or "",  # type: ignore[arg-type]
                homeserver=self._homeserver,
            )

        if not username or not password:
            raise AuthenticationError("username and password required for first login")

        login_response = await self._client.login(password=password, username=username)
        if getattr(login_response, "access_token", None) is None:
            raise AuthenticationError("homeserver did not return an access token")
        session = MatrixSession(
            user_id=str(login_response.user_id),
            access_token=str(login_response.access_token),
            device_id=str(login_response.device_id),
            homeserver=self._homeserver,
        )
        self._apply_session(session)
        return session

    async def get_profile(self) -> MatrixProfile:
        response = await self._client.get_profile()
        display_name = getattr(response, "displayname", None)
        avatar_url = getattr(response, "avatar_url", None)
        return MatrixProfile(
            user_id=self._client.user_id or "",
            display_name=display_name,
            avatar_url=avatar_url,
        )

    def add_update_handler(self, handler: Callable[[MatrixEvent], Awaitable[None]]) -> None:
        if handler in self._handlers:
            return
        self._handlers.append(handler)
        if self._sync_task is None:
            self._sync_task = asyncio.create_task(self._sync_forever())

    def remove_update_handler(self, handler: Callable[[MatrixEvent], Awaitable[None]]) -> None:
        if handler in self._handlers:
            self._handlers.remove(handler)
        if not self._handlers and self._sync_task is not None:
            self._sync_task.cancel()
            self._sync_task = None

    async def send_text(
        self,
        room_id: str,
        message: str,
        *,
        txn_id: Optional[str] = None,
    ) -> Mapping[str, object]:
        response = await self._client.room_send(
            room_id,
            message_type="m.room.message",
            content={"msgtype": "m.text", "body": message},
            ignore_unverified_devices=True,
            txn_id=txn_id,
        )
        if getattr(response, "transport_response", None) and response.transport_response.ok is False:
            raise SessionRevokedError("homeserver rejected the message")
        return {"event_id": getattr(response, "event_id", None)}

    async def acknowledge(self, event_id: str) -> None:
        await self._client.room_read_markers(event_id)

    async def close(self) -> None:
        if self._sync_task is not None:
            self._sync_task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await self._sync_task
            self._sync_task = None
        await self._client.close()

    async def _sync_forever(self) -> None:
        from nio import RoomMessageText  # type: ignore

        try:
            while self._handlers:
                response = await self._client.sync(timeout=30000, full_state=False)
                rooms = getattr(response, "rooms", None)
                if not rooms:
                    continue
                joined = getattr(rooms, "join", {})
                for room_id, room in joined.items():
                    timeline = getattr(room, "timeline", None)
                    events = getattr(timeline, "events", []) if timeline else []
                    for event in events:
                        if isinstance(event, RoomMessageText):
                            matrix_event = MatrixEvent(
                                event_id=event.event_id,
                                room_id=room_id,
                                sender=event.sender,
                                body={"body": event.body, "msgtype": event.msgtype},
                            )
                            await asyncio.gather(
                                *(handler(matrix_event) for handler in list(self._handlers))
                            )
        except asyncio.CancelledError:  # pragma: no cover - cooperative cancellation
            raise

    def _apply_session(self, session: MatrixSession) -> None:
        self._client.user_id = session.user_id
        self._client.access_token = session.access_token
        self._client.device_id = session.device_id


__all__ = [
    "AuthenticationError",
    "SessionRevokedError",
    "MatrixClient",
    "MatrixClientProtocol",
    "MatrixProfile",
    "MatrixSession",
    "MatrixEvent",
]
