"""WhatsApp client abstractions used by the bridge daemon."""

from __future__ import annotations

import base64
from dataclasses import dataclass
from typing import Awaitable, Callable, Mapping, Optional, Protocol

UpdateHandler = Callable[[Mapping[str, object]], Awaitable[None]]


@dataclass(frozen=True)
class PairingCode:
    """Represents a QR code payload used to pair a WhatsApp session."""

    qr_data: str
    expires_at: Optional[float] = None
    client_name: Optional[str] = None

    def to_dict(self) -> Mapping[str, object]:
        payload: dict[str, object] = {"qr_data": self.qr_data}
        if self.expires_at is not None:
            payload["expires_at"] = float(self.expires_at)
        if self.client_name:
            payload["client_name"] = self.client_name
        return payload


@dataclass(frozen=True)
class UserProfile:
    """Subset of WhatsApp profile data exposed to Msgr."""

    jid: str
    display_name: Optional[str] = None
    phone_number: Optional[str] = None

    def to_dict(self) -> Mapping[str, Optional[str]]:
        return {
            "jid": self.jid,
            "display_name": self.display_name,
            "phone_number": self.phone_number,
        }


class WhatsAppClientProtocol(Protocol):
    """Protocol describing the WhatsApp functionality the daemon relies on."""

    async def connect(self) -> None:
        ...

    async def disconnect(self) -> None:
        ...

    async def is_paired(self) -> bool:
        ...

    async def request_pairing(
        self, *, client_name: Optional[str] = None
    ) -> PairingCode:
        ...

    async def get_profile(self) -> UserProfile:
        ...

    async def send_text_message(
        self,
        chat_id: str,
        message: str,
        *,
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
    """Encode a raw session blob into a transport-safe base64 string."""

    return base64.b64encode(data).decode("ascii")


def decode_session_blob(blob: Optional[str]) -> Optional[bytes]:
    """Decode a base64 session string."""

    if blob is None:
        return None
    return base64.b64decode(blob.encode("ascii"))
