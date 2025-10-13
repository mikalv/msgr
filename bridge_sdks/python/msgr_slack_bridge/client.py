"""Protocols and dataclasses describing the Slack bridge surface area."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Awaitable, Callable, Mapping, MutableMapping, Optional, Protocol, Sequence

UpdateHandler = Callable[[Mapping[str, object]], Awaitable[None]]


@dataclass(frozen=True)
class SlackWorkspace:
    """Metadata about a Slack workspace used during account linking."""

    id: str
    name: Optional[str] = None
    domain: Optional[str] = None
    icon: Optional[str] = None

    def to_dict(self) -> MutableMapping[str, Optional[str]]:
        return {
            "id": self.id,
            "name": self.name,
            "domain": self.domain,
            "icon": self.icon,
        }


@dataclass(frozen=True)
class SlackUser:
    """Subset of Slack user profile fields exposed to Msgr."""

    id: str
    real_name: Optional[str] = None
    display_name: Optional[str] = None
    email: Optional[str] = None

    def to_dict(self) -> MutableMapping[str, Optional[str]]:
        return {
            "id": self.id,
            "real_name": self.real_name,
            "display_name": self.display_name,
            "email": self.email,
        }


@dataclass(frozen=True)
class SlackIdentity:
    """Combined workspace and user identity returned after linking."""

    workspace: SlackWorkspace
    user: SlackUser

    def to_dict(self) -> MutableMapping[str, object]:
        return {
            "workspace": self.workspace.to_dict(),
            "user": self.user.to_dict(),
        }


@dataclass(frozen=True)
class SlackToken:
    """Represents the credentials required for a Slack RTM connection."""

    value: str
    token_type: str = "user"
    expires_at: Optional[float] = None

    def to_dict(self) -> MutableMapping[str, object]:
        payload: MutableMapping[str, object] = {
            "token": self.value,
            "token_type": self.token_type,
        }
        if self.expires_at is not None:
            payload["expires_at"] = float(self.expires_at)
        return payload


class SlackClientProtocol(Protocol):
    """Protocol implemented by the concrete Slack RTM/Web API client."""

    async def connect(self, token: SlackToken) -> None:
        """Initialise the websocket and HTTP clients using the supplied token."""

    async def disconnect(self) -> None:
        """Gracefully close the websocket connection."""

    async def is_connected(self) -> bool:
        """Return ``True`` when an RTM connection is active."""

    async def fetch_identity(self) -> SlackIdentity:
        """Return the workspace and user identity bound to the current token."""

    async def describe_capabilities(self) -> Mapping[str, object]:
        """Return feature flags describing which Slack features are bridged."""

    async def list_members(self) -> Sequence[Mapping[str, object]]:
        """Return a snapshot of workspace members."""

    async def list_conversations(self) -> Sequence[Mapping[str, object]]:
        """Return a snapshot of available channels, groups and DMs."""

    async def post_message(
        self,
        channel: str,
        text: str,
        *,
        blocks: Optional[Sequence[Mapping[str, object]]] = None,
        attachments: Optional[Sequence[Mapping[str, object]]] = None,
        thread_ts: Optional[str] = None,
        reply_broadcast: bool = False,
        metadata: Optional[Mapping[str, object]] = None,
    ) -> Mapping[str, object]:
        """Send a message to Slack and return the resulting Slack payload."""

    async def acknowledge_event(self, event_id: str) -> None:
        """Mark an event as processed to advance the RTM cursor."""

    def add_event_handler(self, handler: UpdateHandler) -> None:
        """Register an async callback invoked for each inbound RTM event."""

    def remove_event_handler(self, handler: UpdateHandler) -> None:
        """Unregister a previously registered event handler."""


class SlackOAuthClientProtocol(Protocol):
    """Protocol that exchanges Slack OAuth codes for RTM tokens."""

    async def exchange_code(
        self,
        code: str,
        *,
        code_verifier: Optional[str] = None,
        redirect_uri: Optional[str] = None,
    ) -> Mapping[str, object]:
        """Return a mapping containing ``token`` and optional identity fields."""
