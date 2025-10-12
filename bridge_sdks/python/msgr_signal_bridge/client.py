"""Signal client abstractions for the Msgr bridge daemon."""

from __future__ import annotations

import base64
from dataclasses import dataclass
from typing import Awaitable, Callable, Mapping, Optional, Protocol

UpdateHandler = Callable[[Mapping[str, object]], Awaitable[None]]


@dataclass(frozen=True)
class LinkingCode:
    """Represents a Signal device-linking code/URI."""

    verification_uri: str
    code: Optional[str] = None
    expires_at: Optional[float] = None
    device_name: Optional[str] = None

    def to_dict(self) -> Mapping[str, object]:
        payload: dict[str, object] = {"verification_uri": self.verification_uri}
        if self.code is not None:
            payload["code"] = self.code
        if self.expires_at is not None:
            payload["expires_at"] = float(self.expires_at)
        if self.device_name:
            payload["device_name"] = self.device_name
        return payload


@dataclass(frozen=True)
class SignalProfile:
    """Subset of Signal profile metadata exposed to Msgr."""

    uuid: str
    phone_number: Optional[str] = None
    display_name: Optional[str] = None

    def to_dict(self) -> Mapping[str, Optional[str]]:
        return {
            "uuid": self.uuid,
            "phone_number": self.phone_number,
            "display_name": self.display_name,
        }


class SignalClientProtocol(Protocol):
    """Protocol describing the client functionality the daemon relies on."""

    async def connect(self) -> None:
        ...

    async def disconnect(self) -> None:
        ...

    async def is_linked(self) -> bool:
        ...

    async def request_linking_code(
        self, *, device_name: Optional[str] = None
    ) -> LinkingCode:
        ...

    async def get_profile(self) -> SignalProfile:
        ...

    async def send_text_message(
        self,
        chat_id: str,
        message: str,
        *,
        attachments: Optional[list[Mapping[str, object]]] = None,
        metadata: Optional[Mapping[str, object]] = None,
    ) -> Mapping[str, object]:
        ...

    def add_event_handler(self, handler: UpdateHandler) -> None:
        ...

    def remove_event_handler(self, handler: UpdateHandler) -> None:
        ...

    async def acknowledge_event(self, event_id: str) -> None:
        ...


def encode_session_blob(data: bytes) -> str:
    """Encode a raw session blob into a base64 transport format."""

    return base64.b64encode(data).decode("ascii")


def decode_session_blob(blob: Optional[str]) -> Optional[bytes]:
    """Decode a base64 session string."""

    if blob is None:
        return None
    return base64.b64decode(blob.encode("ascii"))
