"""Protocols and dataclasses describing the Teams bridge surface area."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Awaitable, Callable, Mapping, MutableMapping, Optional, Protocol, Sequence

UpdateHandler = Callable[[Mapping[str, object]], Awaitable[None]]


@dataclass(frozen=True)
class TeamsTenant:
    """Metadata about the Microsoft 365 tenant backing the Teams account."""

    id: str
    display_name: Optional[str] = None
    domain: Optional[str] = None

    def to_dict(self) -> MutableMapping[str, Optional[str]]:
        return {
            "id": self.id,
            "display_name": self.display_name,
            "domain": self.domain,
        }


@dataclass(frozen=True)
class TeamsUser:
    """Subset of Teams user profile fields exposed to Msgr."""

    id: str
    display_name: Optional[str] = None
    user_principal_name: Optional[str] = None
    mail: Optional[str] = None

    def to_dict(self) -> MutableMapping[str, Optional[str]]:
        return {
            "id": self.id,
            "display_name": self.display_name,
            "user_principal_name": self.user_principal_name,
            "mail": self.mail,
        }


@dataclass(frozen=True)
class TeamsIdentity:
    """Combined tenant and user identity returned after linking."""

    tenant: TeamsTenant
    user: TeamsUser

    def to_dict(self) -> MutableMapping[str, object]:
        return {
            "tenant": self.tenant.to_dict(),
            "user": self.user.to_dict(),
        }


@dataclass(frozen=True)
class TeamsToken:
    """OAuth tokens required for Microsoft Graph access."""

    access_token: str
    refresh_token: Optional[str] = None
    expires_at: Optional[float] = None
    token_type: str = "Bearer"

    def to_dict(self) -> MutableMapping[str, object]:
        payload: MutableMapping[str, object] = {
            "access_token": self.access_token,
            "token_type": self.token_type,
        }
        if self.refresh_token is not None:
            payload["refresh_token"] = self.refresh_token
        if self.expires_at is not None:
            payload["expires_at"] = float(self.expires_at)
        return payload


class TeamsClientProtocol(Protocol):
    """Protocol implemented by the concrete Teams Graph/Websocket client."""

    async def connect(self, tenant: TeamsTenant, token: TeamsToken) -> None:
        """Initialise Microsoft Graph clients using the supplied credentials."""

    async def disconnect(self) -> None:
        """Gracefully close any open change notifications/websocket streams."""

    async def is_connected(self) -> bool:
        """Return ``True`` when subscriptions are active."""

    async def fetch_identity(self) -> TeamsIdentity:
        """Return the tenant and user bound to the current session."""

    async def describe_capabilities(self) -> Mapping[str, object]:
        """Return feature flags describing supported Teams functionality."""

    async def list_members(self) -> Sequence[Mapping[str, object]]:
        """Return a snapshot of the user's contacts and organisation."""

    async def list_conversations(self) -> Sequence[Mapping[str, object]]:
        """Return a snapshot of chats/teams available to the user."""

    async def send_message(
        self,
        conversation_id: str,
        message: Mapping[str, object],
        *,
        reply_to_id: Optional[str] = None,
        metadata: Optional[Mapping[str, object]] = None,
    ) -> Mapping[str, object]:
        """Send a Teams message and return the resulting Graph payload."""

    async def acknowledge_event(self, event_id: str) -> None:
        """Mark a change notification as processed."""

    def add_event_handler(self, handler: UpdateHandler) -> None:
        """Register an async callback invoked for each inbound change notification."""

    def remove_event_handler(self, handler: UpdateHandler) -> None:
        """Unregister a previously registered event handler."""


class TeamsOAuthClientProtocol(Protocol):
    """Protocol that exchanges Microsoft identity platform codes for tokens."""

    async def exchange_code(
        self,
        code: str,
        *,
        redirect_uri: Optional[str] = None,
        code_verifier: Optional[str] = None,
    ) -> Mapping[str, object]:
        """Return a mapping containing ``token`` and optional identity fields."""
