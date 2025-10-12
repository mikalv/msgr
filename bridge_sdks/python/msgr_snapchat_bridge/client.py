"""Client protocol definitions for the Snapchat bridge skeleton."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Awaitable, Callable, Mapping, Optional, Protocol

UpdateHandler = Callable[[Mapping[str, object]], Awaitable[None]]


class SnapchatBridgeNotImplementedError(RuntimeError):
    """Raised when the Snapchat bridge skeleton is invoked for a real operation."""


@dataclass(frozen=True)
class SnapchatProfile:
    """Minimal profile metadata returned by future Snapchat clients."""

    username: str
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None


@dataclass(frozen=True)
class SnapchatLinkTicket:
    """Represents the QR/link payload required to authorise a Snapchat client."""

    verification_uri: str
    code: Optional[str] = None
    expires_at: Optional[float] = None


class SnapchatClientProtocol(Protocol):
    """Protocol describing the Snapchat client surface the daemon will rely on."""

    async def connect(self) -> None:
        ...

    async def disconnect(self) -> None:
        ...

    async def is_linked(self) -> bool:
        ...

    async def request_link_ticket(
        self, *, device_name: Optional[str] = None
    ) -> SnapchatLinkTicket:
        ...

    async def get_profile(self) -> SnapchatProfile:
        ...

    async def send_message(
        self,
        conversation_id: str,
        message: str,
        *,
        metadata: Optional[Mapping[str, object]] = None,
    ) -> Mapping[str, object]:
        ...

    async def acknowledge_event(self, event_id: str) -> None:
        ...

    def add_event_handler(self, handler: UpdateHandler) -> None:
        ...

    def remove_event_handler(self, handler: UpdateHandler) -> None:
        ...


class SnapchatClientStub(SnapchatClientProtocol):
    """Placeholder implementation that raises until a real client lands."""

    def __init__(self, *, reason: str = "Snapchat bridge is not implemented yet") -> None:
        self._reason = reason

    async def connect(self) -> None:
        raise SnapchatBridgeNotImplementedError(self._reason)

    async def disconnect(self) -> None:
        return None

    async def is_linked(self) -> bool:
        raise SnapchatBridgeNotImplementedError(self._reason)

    async def request_link_ticket(
        self, *, device_name: Optional[str] = None
    ) -> SnapchatLinkTicket:
        raise SnapchatBridgeNotImplementedError(self._reason)

    async def get_profile(self) -> SnapchatProfile:
        raise SnapchatBridgeNotImplementedError(self._reason)

    async def send_message(
        self,
        conversation_id: str,
        message: str,
        *,
        metadata: Optional[Mapping[str, object]] = None,
    ) -> Mapping[str, object]:
        raise SnapchatBridgeNotImplementedError(self._reason)

    async def acknowledge_event(self, event_id: str) -> None:
        raise SnapchatBridgeNotImplementedError(self._reason)

    def add_event_handler(self, handler: UpdateHandler) -> None:
        raise SnapchatBridgeNotImplementedError(self._reason)

    def remove_event_handler(self, handler: UpdateHandler) -> None:
        raise SnapchatBridgeNotImplementedError(self._reason)
