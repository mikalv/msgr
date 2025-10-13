"""Protocols and dataclasses describing the Teams bridge surface area."""

from __future__ import annotations

import asyncio
import base64
import contextlib
import datetime as dt
import html
import json
import logging
import re
import time
from dataclasses import dataclass
from html.parser import HTMLParser
from typing import (
    Awaitable,
    Callable,
    Dict,
    Iterable,
    Mapping,
    MutableMapping,
    Optional,
    Protocol,
    Sequence,
    Tuple,
    Union,
)
from urllib.parse import urlparse

try:  # pragma: no cover - optional dependency exercised in integration tests
    import aiohttp
    from aiohttp import ClientSession
except ImportError:  # pragma: no cover - aiohttp not available during unit tests
    aiohttp = None  # type: ignore
    ClientSession = None  # type: ignore

UpdateHandler = Callable[[Mapping[str, object]], Awaitable[None]]

from .notifications import TeamsNotificationSource


@dataclass(frozen=True)
class TeamsTenant:
    """Metadata about the Microsoft 365 tenant backing the Teams account."""

    id: str
    display_name: Optional[str] = None
    domain: Optional[str] = None
    requires_resource_specific_consent: bool = False

    def to_dict(self) -> MutableMapping[str, object]:
        payload: MutableMapping[str, object] = {
            "id": self.id,
            "display_name": self.display_name,
            "domain": self.domain,
        }
        if self.requires_resource_specific_consent:
            payload["requires_resource_specific_consent"] = True
        return payload


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


@dataclass(frozen=True)
class TeamsUploadedFile:
    """Metadata describing a file that was uploaded alongside a Teams message."""

    name: str
    content_type: Optional[str] = None
    size: Optional[int] = None
    content_id: Optional[str] = None
    inline: bool = False

    def to_dict(self) -> MutableMapping[str, object]:
        payload: Dict[str, object] = {"name": self.name, "inline": self.inline}
        if self.content_type:
            payload["content_type"] = self.content_type
        if self.size is not None:
            payload["size"] = int(self.size)
        if self.content_id:
            payload["content_id"] = self.content_id
        return payload


@dataclass(frozen=True)
class TeamsFileUpload:
    """Represents an outbound file that should be attached to a Teams message."""

    filename: str
    content: bytes
    content_type: Optional[str] = None
    inline: bool = False
    content_id: Optional[str] = None
    description: Optional[str] = None

    def content_length(self) -> int:
        return len(self.content)

    def to_attachment(self) -> Tuple[Dict[str, object], TeamsUploadedFile]:
        encoded = base64.b64encode(self.content).decode("ascii")
        attachment = _compact_dict(
            {
                "@odata.type": "#microsoft.graph.fileAttachment",
                "name": self.filename,
                "contentType": self.content_type or "application/octet-stream",
                "contentBytes": encoded,
                "contentId": self.content_id,
                "isInline": True if self.inline else None,
                "description": self.description,
            }
        )
        uploaded = TeamsUploadedFile(
            name=self.filename,
            content_type=self.content_type,
            size=self.content_length(),
            content_id=self.content_id,
            inline=self.inline,
        )
        return attachment, uploaded


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
        file_uploads: Optional[Sequence[Union[TeamsFileUpload, Mapping[str, object]]]] = None,
    ) -> Mapping[str, object]:
        """Send a Teams message and return the resulting Graph payload."""

    async def acknowledge_event(self, event_id: str) -> None:
        """Mark a change notification as processed."""

    def add_event_handler(self, handler: UpdateHandler) -> None:
        """Register an async callback invoked for each inbound change notification."""

    def remove_event_handler(self, handler: UpdateHandler) -> None:
        """Unregister a previously registered event handler."""

    async def health(self) -> Mapping[str, object]:
        """Return runtime health information for operational dashboards."""


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

    async def refresh_token(
        self,
        refresh_token: str,
        *,
        redirect_uri: Optional[str] = None,
    ) -> Mapping[str, object]:
        """Return a refreshed token payload for the supplied ``refresh_token``."""


class TeamsGraphClient(TeamsClientProtocol):
    """Microsoft Graph implementation that polls chats for new messages."""

    _GRAPH_BASE = "https://graph.microsoft.com/v1.0"

    def __init__(
        self,
        *,
        session: Optional[ClientSession] = None,
        logger: Optional[logging.Logger] = None,
        poll_interval: float = 15.0,
        token_refresh_margin: float = 120.0,
        notification_source: Optional[TeamsNotificationSource] = None,
    ) -> None:
        if session is not None and ClientSession is not None and not isinstance(session, ClientSession):
            raise RuntimeError("session must be an aiohttp.ClientSession instance")

        self._session = session
        self._owns_session = session is None
        self._logger = logger or logging.getLogger(__name__)
        self._poll_interval = max(5.0, poll_interval)
        self._refresh_margin = max(30.0, float(token_refresh_margin))
        self._token: Optional[TeamsToken] = None
        self._tenant: Optional[TeamsTenant] = None
        self._identity: Optional[TeamsIdentity] = None
        self._capabilities: Optional[Mapping[str, object]] = None
        self._handlers: list[UpdateHandler] = []
        self._poll_task: Optional[asyncio.Task[None]] = None
        self._notification_source = notification_source
        self._notifications_active = False
        self._last_message_ts: Dict[str, str] = {}
        self._inflight: Dict[str, float] = {}
        self._last_event_at: Optional[float] = None
        self._last_event_id: Optional[str] = None
        self._last_ack_at: Optional[float] = None
        self._last_ack_latency: Optional[float] = None
        self._last_connect_at: Optional[float] = None
        self._last_disconnect_at: Optional[float] = None
        self._last_poll_at: Optional[float] = None
        self._consecutive_errors: int = 0
        self._token_refresher: Optional[Callable[[TeamsToken], Awaitable[TeamsToken]]] = None
        self._token_update_handler: Optional[Callable[[TeamsToken], Awaitable[None]]] = None
        self._refresh_lock = asyncio.Lock()

    async def connect(self, tenant: TeamsTenant, token: TeamsToken) -> None:
        if aiohttp is None:  # pragma: no cover - exercised in integration tests
            raise RuntimeError("aiohttp is required to connect to Microsoft Graph")

        await self._ensure_session()
        self._token = token
        self._tenant = tenant

        me = await self._get("/me")
        self._identity = _build_identity(me, tenant)

        identity = self._identity
        self._logger.info(
            "Teams Graph poller connected",
            extra={
                "tenant": identity.tenant.id if identity else None,
                "user": identity.user.id if identity else None,
            },
        )

        if self._notification_source is not None:
            await self._notification_source.start(tenant, token, self._handle_change_notification)
            self._notifications_active = True
            self._poll_task = None
        elif self._poll_task is None or self._poll_task.done():
            self._poll_task = asyncio.create_task(self._poll_loop(), name="teams-graph-poller")
        self._last_connect_at = time.time()
        self._consecutive_errors = 0

    async def disconnect(self) -> None:
        if self._notification_source is not None and self._notifications_active:
            await self._notification_source.stop()
            self._notifications_active = False

        if self._poll_task is not None:
            self._poll_task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await self._poll_task
            self._poll_task = None

        if self._owns_session and self._session is not None:
            await self._session.close()
            self._session = None

        self._last_disconnect_at = time.time()
        identity = self._identity
        self._logger.info(
            "Teams Graph poller disconnected",
            extra={
                "tenant": identity.tenant.id if identity else None,
                "user": identity.user.id if identity else None,
            },
        )

    async def is_connected(self) -> bool:
        if self._notification_source is not None:
            return self._notification_source.active
        return bool(self._poll_task is not None and not self._poll_task.done())

    async def fetch_identity(self) -> TeamsIdentity:
        if self._identity is None:
            raise RuntimeError("Teams client not connected")
        return self._identity

    async def describe_capabilities(self) -> Mapping[str, object]:
        if self._capabilities is None:
            self._capabilities = {
                "messaging": {
                    "text": True,
                    "mentions": True,
                    "attachments": ["file", "image", "adaptive_card"],
                },
                "presence": {"typing": True, "read_receipts": True},
                "threads": {"supported": True},
            }
        return self._capabilities

    async def list_members(self) -> Sequence[Mapping[str, object]]:
        members: list[Mapping[str, object]] = []
        async for item in self._paged_get("/me/people"):
            members.append(item)
        return members

    async def list_conversations(self) -> Sequence[Mapping[str, object]]:
        conversations: list[Mapping[str, object]] = []
        async for item in self._paged_get("/me/chats"):
            conversations.append(item)
        return conversations

    async def send_message(
        self,
        conversation_id: str,
        message: Mapping[str, object],
        *,
        reply_to_id: Optional[str] = None,
        metadata: Optional[Mapping[str, object]] = None,
        file_uploads: Optional[Sequence[Union[TeamsFileUpload, Mapping[str, object]]]] = None,
    ) -> Mapping[str, object]:
        payload, uploads = _prepare_outbound_message(message, file_uploads=file_uploads)
        if metadata is not None:
            payload.setdefault("metadata", dict(metadata))
        if reply_to_id is not None:
            payload.setdefault("replyToId", reply_to_id)
        response = await self._post(f"/chats/{conversation_id}/messages", payload)
        if uploads:
            response = dict(response)
            response["uploaded_files"] = [upload.to_dict() for upload in uploads]
        return response

    async def acknowledge_event(self, event_id: str) -> None:
        if not event_id:
            return
        now = time.time()
        dispatched_at = self._inflight.pop(event_id, None)
        if dispatched_at is not None:
            self._last_ack_latency = max(0.0, now - dispatched_at)
        self._last_ack_at = now
        if self._notification_source is not None:
            await self._notification_source.acknowledge(event_id)

    def add_event_handler(self, handler: UpdateHandler) -> None:
        if handler not in self._handlers:
            self._handlers.append(handler)

    def remove_event_handler(self, handler: UpdateHandler) -> None:
        if handler in self._handlers:
            self._handlers.remove(handler)

    def configure_token_refresh(
        self,
        refresher: Callable[[TeamsToken], Awaitable[TeamsToken]],
        on_update: Callable[[TeamsToken], Awaitable[None]],
        *,
        margin: Optional[float] = None,
    ) -> None:
        """Register callbacks used to refresh expiring OAuth tokens."""

        self._token_refresher = refresher
        self._token_update_handler = on_update
        if margin is not None:
            self._refresh_margin = max(30.0, float(margin))

    async def _ensure_session(self) -> None:
        if self._session is None:
            if aiohttp is None:  # pragma: no cover
                raise RuntimeError("aiohttp is required to create a Teams HTTP session")
            timeout = aiohttp.ClientTimeout(total=60)
            self._session = aiohttp.ClientSession(timeout=timeout)

    async def _ensure_valid_token(self) -> None:
        token = self._token
        if token is None or token.refresh_token is None:
            return

        expires_at = token.expires_at
        if expires_at is None:
            return

        now = time.time()
        if expires_at - now > self._refresh_margin:
            return

        refresher = self._token_refresher
        if refresher is None:
            return

        async with self._refresh_lock:
            latest = self._token
            if latest is None:
                return
            expires_at = latest.expires_at
            if expires_at is not None and expires_at - time.time() > self._refresh_margin:
                return

            try:
                refreshed = await refresher(latest)
            except Exception:
                self._logger.exception("Teams token refresh failed")
                raise

            if not isinstance(refreshed, TeamsToken):
                raise RuntimeError("Teams token refresher returned an invalid token payload")

            if refreshed.refresh_token is None and latest.refresh_token is not None:
                refreshed = TeamsToken(
                    access_token=refreshed.access_token,
                    refresh_token=latest.refresh_token,
                    expires_at=refreshed.expires_at,
                    token_type=refreshed.token_type,
                )

            self._token = refreshed

            if self._notification_source is not None:
                await self._notification_source.refresh(refreshed)

            if self._token_update_handler is not None:
                await self._token_update_handler(refreshed)

    async def _poll_loop(self) -> None:
        try:
            while True:
                try:
                    self._logger.debug("Teams poll iteration starting")
                    chats = await self.list_conversations()
                    for chat in chats:
                        chat_id = str(chat.get("id"))
                        if chat_id:
                            await self._poll_chat(chat_id)
                    self._consecutive_errors = 0
                except asyncio.CancelledError:
                    raise
                except Exception:  # pragma: no cover - network errors logged
                    self._consecutive_errors += 1
                    self._logger.exception("Teams polling iteration failed")
                finally:
                    self._last_poll_at = time.time()
                await asyncio.sleep(self._poll_interval)
        except asyncio.CancelledError:  # pragma: no cover - cancellation path
            pass

    async def _poll_chat(self, chat_id: str) -> None:
        params = {"$top": 20, "$orderby": "lastModifiedDateTime asc"}
        data = await self._get(f"/chats/{chat_id}/messages", params=params)
        messages = data.get("value") if isinstance(data.get("value"), list) else []
        last_seen = self._last_message_ts.get(chat_id)
        for message in messages:
            if not isinstance(message, Mapping):
                continue
            timestamp = message.get("lastModifiedDateTime") or message.get("createdDateTime")
            if last_seen and _compare_timestamp(timestamp, last_seen) <= 0:
                continue
            await self._dispatch_event(chat_id, message)
            if isinstance(timestamp, str):
                self._last_message_ts[chat_id] = timestamp

    async def _dispatch_event(self, chat_id: str, message: Mapping[str, object]) -> None:
        event = _normalise_chat_event(self._tenant, chat_id, message)
        if event is None:
            return
        now = time.time()
        event_id = event.get("event_id")
        if isinstance(event_id, (str, int)):
            event_id_str = str(event_id)
            self._inflight.setdefault(event_id_str, now)
            self._last_event_id = event_id_str
            self._trim_inflight()
        self._last_event_at = now
        self._logger.debug(
            "Teams event received",
            extra={"chat_id": chat_id, "event_id": event.get("event_id")},
        )
        for handler in list(self._handlers):
            try:
                await handler(event)
            except Exception:  # pragma: no cover - handler failures logged for ops
                self._logger.exception("Teams handler raised")

    async def _handle_change_notification(self, payload: Mapping[str, object]) -> None:
        try:
            chat_id, message = await self._fetch_notification_message(payload)
        except Exception:  # pragma: no cover - defensive logging for ops
            self._logger.exception("Failed to process Teams change notification")
            return

        if chat_id is None or message is None:
            return

        await self._dispatch_event(chat_id, message)

    async def _fetch_notification_message(
        self, payload: Mapping[str, object]
    ) -> Tuple[Optional[str], Optional[Mapping[str, object]]]:
        context = _extract_notification_context(payload)
        message_id = context.get("message_id")
        if not message_id:
            return None, None

        chat_id = context.get("chat_id")
        team_id = context.get("team_id")
        channel_id = context.get("channel_id")

        path: Optional[str]
        if chat_id:
            path = f"/chats/{chat_id}/messages/{message_id}"
        elif team_id and channel_id:
            path = f"/teams/{team_id}/channels/{channel_id}/messages/{message_id}"
            chat_id = channel_id
        else:
            path = None

        if path is None:
            return None, None

        message = await self._get(path)
        if not isinstance(message, Mapping):
            return None, None

        if chat_id is None:
            chat_id = _extract_chat_id_from_message(message)

        if chat_id is None:
            return None, None

        return chat_id, message

    async def health(self) -> Mapping[str, object]:
        connected = await self.is_connected()
        now = time.time()
        oldest_inflight: Optional[float] = None
        if self._inflight:
            oldest_inflight = min(self._inflight.values())
        delivery_mode = "change_notifications" if self._notification_source is not None else "polling"
        poll_interval = self._poll_interval if self._notification_source is None else None
        subscription_id = (
            self._notification_source.subscription_id
            if self._notification_source is not None
            else None
        )
        health = _compact_dict(
            {
                "connected": connected,
                "delivery_mode": delivery_mode,
                "subscription_id": subscription_id,
                "poll_interval": poll_interval,
                "handler_count": len(self._handlers),
                "pending_events": len(self._inflight),
                "oldest_pending_age": max(0.0, now - oldest_inflight)
                if oldest_inflight is not None
                else None,
                "last_event_id": self._last_event_id,
                "last_event_age": max(0.0, now - self._last_event_at)
                if self._last_event_at is not None
                else None,
                "last_ack_at": self._last_ack_at,
                "last_ack_latency": self._last_ack_latency,
                "last_connect_at": self._last_connect_at,
                "last_disconnect_at": self._last_disconnect_at,
                "last_poll_at": self._last_poll_at,
                "consecutive_errors": self._consecutive_errors,
            }
        )
        return health

    async def _get(
        self,
        path: str,
        params: Optional[Mapping[str, object]] = None,
    ) -> Mapping[str, object]:
        if self._session is None or self._token is None:
            raise RuntimeError("Teams client is not connected")

        await self._ensure_valid_token()

        url = f"{self._GRAPH_BASE}{path}"
        headers = {
            "Authorization": f"Bearer {self._token.access_token}",
            "Content-Type": "application/json",
        }
        async with self._session.get(url, params=params, headers=headers) as response:
            response.raise_for_status()
            text = await response.text()
            data = json.loads(text)
        if not isinstance(data, Mapping):
            raise RuntimeError("Teams Graph returned non-mapping payload")
        return data

    async def _post(self, path: str, payload: Mapping[str, object]) -> Mapping[str, object]:
        if self._session is None or self._token is None:
            raise RuntimeError("Teams client is not connected")

        await self._ensure_valid_token()

        url = f"{self._GRAPH_BASE}{path}"
        headers = {
            "Authorization": f"Bearer {self._token.access_token}",
            "Content-Type": "application/json",
        }
        async with self._session.post(url, json=payload, headers=headers) as response:
            response.raise_for_status()
            data = await response.json()
        if not isinstance(data, Mapping):
            raise RuntimeError("Teams Graph returned non-mapping payload")
        return data

    def _trim_inflight(self, *, max_entries: int = 1000, max_age: float = 3600.0) -> None:
        if not self._inflight:
            return
        now = time.time()
        stale_keys = [
            event_id
            for event_id, dispatched_at in self._inflight.items()
            if now - dispatched_at > max_age
        ]
        for event_id in stale_keys:
            self._inflight.pop(event_id, None)
        if len(self._inflight) > max_entries:
            overflow = len(self._inflight) - max_entries
            for event_id in sorted(self._inflight, key=self._inflight.get)[:overflow]:
                self._inflight.pop(event_id, None)

    async def _paged_get(self, path: str) -> Iterable[Mapping[str, object]]:
        url = f"{self._GRAPH_BASE}{path}"
        next_link: Optional[str] = url
        while next_link:
            data = await self._get(next_link.replace(self._GRAPH_BASE, ""))
            values = data.get("value")
            if isinstance(values, list):
                for item in values:
                    if isinstance(item, Mapping):
                        yield item
            next_link = data.get("@odata.nextLink") if isinstance(data.get("@odata.nextLink"), str) else None


_CHAT_RESOURCE_PATTERN = re.compile(r"/chats\(([\"'])([^\"']+)\1\)/messages\(([\"'])([^\"']+)\3\)", re.IGNORECASE)
_CHANNEL_RESOURCE_PATTERN = re.compile(
    r"/teams\(([\"'])([^\"']+)\1\)/channels\(([\"'])([^\"']+)\3\)/messages\(([\"'])([^\"']+)\5\)",
    re.IGNORECASE,
)


def _extract_notification_context(payload: Mapping[str, object]) -> Dict[str, Optional[str]]:
    context: Dict[str, Optional[str]] = {
        "chat_id": None,
        "message_id": None,
        "team_id": None,
        "channel_id": None,
        "tenant_id": None,
    }

    resource_data = _ensure_mapping(
        payload.get("resourceData") or payload.get("resource_data")
    )
    if resource_data:
        message_id = resource_data.get("id")
        if isinstance(message_id, (str, int)):
            context["message_id"] = str(message_id)

        chat_id = resource_data.get("chatId") or resource_data.get("chat_id")
        if isinstance(chat_id, (str, int)):
            context["chat_id"] = str(chat_id)

        channel_identity = _ensure_mapping(
            resource_data.get("channelIdentity") or resource_data.get("channel_identity")
        )
        if channel_identity:
            channel_id = channel_identity.get("channelId") or channel_identity.get("channel_id")
            if isinstance(channel_id, (str, int)):
                context["channel_id"] = str(channel_id)

            team_id = channel_identity.get("teamId") or channel_identity.get("team_id")
            if isinstance(team_id, (str, int)):
                context["team_id"] = str(team_id)

    resource = payload.get("resource")
    if isinstance(resource, str):
        parsed = _parse_resource_path(resource)
        for key, value in parsed.items():
            if context.get(key) is None and value is not None:
                context[key] = value

    tenant_id = payload.get("tenantId") or payload.get("tenant_id")
    if isinstance(tenant_id, (str, int)):
        context["tenant_id"] = str(tenant_id)

    return context


def _parse_resource_path(resource: str) -> Dict[str, Optional[str]]:
    channel_match = _CHANNEL_RESOURCE_PATTERN.search(resource)
    if channel_match:
        return {
            "team_id": channel_match.group(2),
            "channel_id": channel_match.group(4),
            "message_id": channel_match.group(6),
        }

    chat_match = _CHAT_RESOURCE_PATTERN.search(resource)
    if chat_match:
        return {
            "chat_id": chat_match.group(2),
            "message_id": chat_match.group(4),
        }

    return {}


def _ensure_mapping(value: object) -> Dict[str, object]:
    if isinstance(value, Mapping):
        return dict(value)
    return {}


def _extract_chat_id_from_message(message: Mapping[str, object]) -> Optional[str]:
    chat_id = message.get("chatId") or message.get("chat_id")
    if isinstance(chat_id, (str, int)):
        return str(chat_id)

    channel_identity = _ensure_mapping(
        message.get("channelIdentity") or message.get("channel_identity")
    )
    channel_id = channel_identity.get("channelId") or channel_identity.get("channel_id")
    if isinstance(channel_id, (str, int)):
        return str(channel_id)

    return None


def _normalise_chat_event(
    tenant: Optional[TeamsTenant], chat_id: str, message: Mapping[str, object]
) -> Optional[Dict[str, object]]:
    if not isinstance(message, Mapping):
        return None

    message_id = message.get("id") or message.get("messageId")
    if not isinstance(message_id, (str, int)):
        return None
    message_id_str = str(message_id)

    message_payload, channel_identity = _normalise_graph_message(
        message,
        tenant=tenant,
        chat_id=chat_id,
    )

    conversation = _normalise_conversation_context(
        tenant,
        chat_id,
        message,
        channel_identity,
        message_payload.get("thread") if isinstance(message_payload, Mapping) else None,
    )

    event = _compact_dict(
        {
            "event_id": message_id_str,
            "event_type": _determine_event_type(message_payload.get("message_type")),
            "tenant_id": tenant.id if tenant else None,
            "chat_id": chat_id,
            "conversation": conversation if conversation else None,
            "message": message_payload if message_payload else None,
        }
    )
    return event if event else None


def _determine_event_type(message_type: object) -> str:
    if not isinstance(message_type, str):
        return "message"
    lowered = message_type.lower()
    if lowered in {"systemeventmessage", "system"}:
        return "system_event"
    if lowered in {"meetingmessage", "meeting"}:
        return "meeting"
    if lowered in {"announcement", "channelannouncement"}:
        return "announcement"
    return "message"


def _normalise_conversation_context(
    tenant: Optional[TeamsTenant],
    chat_id: str,
    message: Mapping[str, object],
    channel_identity: Optional[Mapping[str, object]],
    thread_summary: Optional[Mapping[str, object]],
) -> Optional[Dict[str, object]]:
    conversation_type = "channel" if channel_identity else "chat"
    chat_type = message.get("chatType") or message.get("chat_type")
    topic = message.get("topic") or message.get("subject")

    conversation = _compact_dict(
        {
            "id": chat_id,
            "tenant_id": tenant.id if tenant else None,
            "type": conversation_type,
            "chat_type": chat_type,
            "topic": topic,
            "channel_identity": dict(channel_identity) if channel_identity else None,
        }
    )

    if conversation and isinstance(thread_summary, Mapping) and thread_summary:
        conversation["thread"] = dict(thread_summary)

    return conversation or None


def _normalise_graph_message(
    message: Mapping[str, object],
    *,
    tenant: Optional[TeamsTenant],
    chat_id: Optional[str],
    channel_identity: Optional[Mapping[str, object]] = None,
) -> Tuple[Dict[str, object], Optional[Dict[str, object]]]:
    if not isinstance(message, Mapping):
        return {}, None

    resolved_channel = channel_identity or _normalise_channel_identity(
        message.get("channelIdentity")
    )

    message_id = _as_str(message.get("id") or message.get("messageId"))
    reply_to_id = _as_str(message.get("replyToId"))

    replies = _normalise_graph_replies(
        message.get("replies"),
        tenant=tenant,
        chat_id=chat_id,
        channel_identity=resolved_channel,
    )
    reply_reference = _build_reply_reference(
        reply_to_id,
        tenant=tenant,
        chat_id=chat_id,
        channel_identity=resolved_channel,
    )
    thread_summary = _build_thread_summary(message_id, reply_reference, replies)

    payload = _compact_dict(
        {
            "id": message_id,
            "message_type": message.get("messageType"),
            "subject": message.get("subject"),
            "summary": message.get("summary"),
            "reply_to_id": reply_to_id,
            "importance": message.get("importance"),
            "body": _normalise_graph_body(message.get("body")),
            "from": _normalise_graph_from(message.get("from")),
            "created_at": message.get("createdDateTime"),
            "last_modified_at": message.get("lastModifiedDateTime"),
            "attachments": _normalise_graph_attachments(message.get("attachments")),
            "mentions": _normalise_graph_mentions(message.get("mentions")),
            "reactions": _normalise_graph_reactions(message.get("reactions")),
            "etag": message.get("etag"),
            "web_url": message.get("webUrl"),
            "meeting": _normalise_meeting_metadata(message),
            "thread": thread_summary,
        }
    )

    if reply_reference:
        payload["reply_to"] = reply_reference
    if replies:
        payload["replies"] = replies

    return payload, resolved_channel


def _build_reply_reference(
    reply_to_id: Optional[str],
    *,
    tenant: Optional[TeamsTenant],
    chat_id: Optional[str],
    channel_identity: Optional[Mapping[str, object]],
) -> Optional[Dict[str, object]]:
    if not reply_to_id:
        return None
    reference = _compact_dict(
        {
            "id": reply_to_id,
            "tenant_id": tenant.id if tenant else None,
            "chat_id": chat_id,
            "channel_identity": dict(channel_identity) if channel_identity else None,
        }
    )
    return reference or None


def _build_thread_summary(
    message_id: Optional[str],
    reply_reference: Optional[Mapping[str, object]],
    replies: Optional[Sequence[Mapping[str, object]]],
) -> Optional[Dict[str, object]]:
    if not message_id and not reply_reference and not replies:
        return None

    summary: Dict[str, object] = {}
    if message_id:
        if reply_reference and isinstance(reply_reference.get("id"), str):
            summary["root_id"] = reply_reference["id"]  # type: ignore[index]
        else:
            summary["root_id"] = message_id
    if reply_reference and isinstance(reply_reference.get("id"), str):
        summary["parent_id"] = reply_reference["id"]  # type: ignore[index]
    if replies:
        summary["has_replies"] = True
        summary["reply_count"] = len(replies)

    return _compact_dict(summary) or None


def _normalise_graph_replies(
    replies: object,
    *,
    tenant: Optional[TeamsTenant],
    chat_id: Optional[str],
    channel_identity: Optional[Mapping[str, object]],
) -> Optional[list[Mapping[str, object]]]:
    if not isinstance(replies, list):
        return None
    normalised: list[Mapping[str, object]] = []
    for entry in replies:
        if not isinstance(entry, Mapping):
            continue
        reply_payload, reply_channel = _normalise_graph_message(
            entry,
            tenant=tenant,
            chat_id=chat_id,
            channel_identity=channel_identity or _normalise_channel_identity(entry.get("channelIdentity")),
        )
        if reply_payload:
            normalised.append(reply_payload)
        channel_identity = channel_identity or reply_channel
    return normalised or None


def _normalise_meeting_metadata(message: Mapping[str, object]) -> Optional[Dict[str, object]]:
    meeting_info = message.get("meetingInfo") or message.get("meeting_info")
    online_info = message.get("onlineMeetingInfo") or message.get("online_meeting_info")
    event_detail = message.get("eventDetail") or message.get("event_detail")
    call_id = message.get("callId") or message.get("call_id")
    meeting = _compact_dict(
        {
            "message_type": message.get("meetingMessageType") or message.get("meeting_message_type"),
            "call_id": call_id,
            "event_detail": dict(event_detail) if isinstance(event_detail, Mapping) else None,
            "info": _normalise_meeting_info(meeting_info),
            "online_meeting": _normalise_online_meeting_info(online_info),
        }
    )
    return meeting or None


def _normalise_meeting_info(info: object) -> Optional[Dict[str, object]]:
    if not isinstance(info, Mapping):
        return None
    join_url = info.get("joinUrl") or info.get("join_url")
    normalised = _compact_dict(
        {
            "id": info.get("id"),
            "subject": info.get("subject"),
            "join_url": join_url if isinstance(join_url, str) and _is_safe_href(join_url) else None,
            "organizer": _compact_dict(
                {
                    "id": organizer.get("id"),
                    "display_name": organizer.get("displayName") or organizer.get("display_name"),
                    "user_identity_type": organizer.get("userIdentityType")
                    or organizer.get("user_identity_type"),
                }
            )
            if isinstance(organizer := info.get("organizer"), Mapping)
            else None,
        }
    )
    return normalised or None


def _normalise_online_meeting_info(info: object) -> Optional[Dict[str, object]]:
    if not isinstance(info, Mapping):
        return None
    join_url = info.get("joinUrl") or info.get("join_url")
    return _compact_dict(
        {
            "calendar_event_id": info.get("calendarEventId") or info.get("calendar_event_id"),
            "conference_id": info.get("conferenceId") or info.get("conference_id"),
            "external_id": info.get("externalId") or info.get("external_id"),
            "join_url": join_url if isinstance(join_url, str) and _is_safe_href(join_url) else None,
        }
    )


def _normalise_graph_body(body: object) -> Optional[Dict[str, object]]:
    if not isinstance(body, Mapping):
        return None
    return _compact_dict(
        {
            "content": body.get("content"),
            "content_type": body.get("contentType"),
        }
    )


def _normalise_graph_attachments(attachments: object) -> Optional[list[Mapping[str, object]]]:
    if not isinstance(attachments, list):
        return None
    normalised: list[Mapping[str, object]] = []
    for attachment in attachments:
        if not isinstance(attachment, Mapping):
            continue
        normalised_attachment = _compact_dict(
            {
                "id": _as_str(attachment.get("id")),
                "content_type": attachment.get("contentType"),
                "content_url": attachment.get("contentUrl"),
                "name": attachment.get("name"),
                "content": attachment.get("content"),
                "content_bytes": attachment.get("contentBytes"),
                "content_location": attachment.get("contentLocation"),
                "thumbnail_url": attachment.get("thumbnailUrl"),
                "size": attachment.get("size"),
            }
        )
        if normalised_attachment:
            normalised.append(normalised_attachment)
    return normalised or None


def _normalise_graph_mentions(mentions: object) -> Optional[list[Mapping[str, object]]]:
    if not isinstance(mentions, list):
        return None
    normalised: list[Mapping[str, object]] = []
    for mention in mentions:
        if not isinstance(mention, Mapping):
            continue
        mentioned = mention.get("mentioned")
        mentioned_entity: Optional[Dict[str, object]] = None
        if isinstance(mentioned, Mapping):
            user = mentioned.get("user")
            application = mentioned.get("application")
            if isinstance(user, Mapping):
                mentioned_entity = _compact_dict(
                    {
                        "type": "user",
                        "id": user.get("id"),
                        "display_name": user.get("displayName"),
                        "user_identity_type": user.get("userIdentityType"),
                    }
                )
            elif isinstance(application, Mapping):
                mentioned_entity = _compact_dict(
                    {
                        "type": "application",
                        "id": application.get("id"),
                        "display_name": application.get("displayName"),
                    }
                )
        normalised_mention = _compact_dict(
            {
                "id": _as_str(mention.get("id")),
                "text": mention.get("mentionText"),
                "mentioned": mentioned_entity,
            }
        )
        if normalised_mention:
            normalised.append(normalised_mention)
    return normalised or None


def _normalise_graph_reactions(reactions: object) -> Optional[list[Mapping[str, object]]]:
    if not isinstance(reactions, list):
        return None
    normalised: list[Mapping[str, object]] = []
    for reaction in reactions:
        if not isinstance(reaction, Mapping):
            continue
        user_info = reaction.get("user")
        normalised_user = _normalise_graph_from(user_info)
        normalised_reaction = _compact_dict(
            {
                "type": reaction.get("reactionType"),
                "created_at": reaction.get("createdDateTime"),
                "user": normalised_user,
            }
        )
        if normalised_reaction:
            normalised.append(normalised_reaction)
    return normalised or None


def _normalise_graph_from(entity: object) -> Optional[Dict[str, object]]:
    if not isinstance(entity, Mapping):
        return None
    user = entity.get("user")
    application = entity.get("application")
    device = entity.get("device")
    normalised: Dict[str, object] = {}
    if isinstance(user, Mapping):
        normalised["user"] = _compact_dict(
            {
                "id": user.get("id"),
                "display_name": user.get("displayName"),
                "user_identity_type": user.get("userIdentityType"),
                "tenant_id": user.get("tenantId"),
            }
        )
    if isinstance(application, Mapping):
        normalised["application"] = _compact_dict(
            {
                "id": application.get("id"),
                "display_name": application.get("displayName"),
            }
        )
    if isinstance(device, Mapping):
        normalised["device"] = _compact_dict(
            {
                "id": device.get("id"),
                "display_name": device.get("displayName"),
            }
        )
    return normalised or None


def _normalise_channel_identity(identity: object) -> Optional[Dict[str, object]]:
    if not isinstance(identity, Mapping):
        return None
    return _compact_dict(
        {
            "team_id": identity.get("teamId"),
            "channel_id": identity.get("channelId"),
            "tenant_id": identity.get("tenantId"),
        }
    )


def _prepare_outbound_message(
    message: Mapping[str, object],
    *,
    file_uploads: Optional[Sequence[Union[TeamsFileUpload, Mapping[str, object]]]] = None,
) -> Tuple[Dict[str, object], list[TeamsUploadedFile]]:
    payload = dict(message)

    body = payload.get("body")
    if isinstance(body, Mapping):
        content_value = body.get("content")
        content_text = str(content_value) if content_value is not None else ""
        content_type_value = body.get("contentType")
        content_type = str(content_type_value).lower() if isinstance(content_type_value, str) else "text"

        if content_type in {"text", "plain", "text/plain"}:
            payload["body"] = {
                "contentType": "html",
                "content": _render_plain_text(content_text),
            }
        else:
            sanitised = _sanitise_html(content_text)
            payload["body"] = {
                "contentType": "html" if content_type in {"", "html"} else content_type,
                "content": sanitised,
            }
    else:
        payload["body"] = {
            "contentType": "html",
            "content": _render_plain_text(str(body) if body is not None else ""),
        }

    cleaned_attachments: list[Dict[str, object]] = []
    attachments = payload.get("attachments")
    if isinstance(attachments, list):
        for attachment in attachments:
            if not isinstance(attachment, Mapping):
                continue
            cleaned_attachment = _sanitise_outbound_attachment(attachment)
            if cleaned_attachment:
                cleaned_attachments.append(cleaned_attachment)

    uploads: list[TeamsUploadedFile] = []
    if file_uploads:
        for candidate in file_uploads:
            upload = _coerce_file_upload(candidate)
            if upload is None:
                continue
            attachment, uploaded = upload.to_attachment()
            cleaned_attachments.append(attachment)
            uploads.append(uploaded)

    if cleaned_attachments:
        payload["attachments"] = cleaned_attachments
    elif "attachments" in payload:
        payload.pop("attachments")

    return payload, uploads


def _sanitise_outbound_attachment(attachment: Mapping[str, object]) -> Optional[Dict[str, object]]:
    mapping = _ensure_mapping(attachment)
    if not mapping:
        return None

    cleaned: Dict[str, object] = {}

    def _copy_field(target: str, *candidates: str) -> None:
        for candidate in candidates:
            if candidate not in mapping:
                continue
            value = mapping[candidate]
            if value is None:
                continue
            cleaned[target] = value
            return

    _copy_field("id", "id")
    _copy_field("name", "name", "filename", "title")
    _copy_field("description", "description", "text")
    _copy_field("contentType", "contentType", "content_type")
    _copy_field("contentBytes", "contentBytes", "content_bytes")
    _copy_field("contentLocation", "contentLocation", "content_location")
    _copy_field("thumbnailUrl", "thumbnailUrl", "thumbnail_url")
    _copy_field("@odata.type", "@odata.type", "odata_type")

    url_value = mapping.get("contentUrl") or mapping.get("content_url")
    if isinstance(url_value, str) and _is_safe_href(url_value):
        cleaned["contentUrl"] = url_value

    thumbnail = mapping.get("thumbnailUrl") or mapping.get("thumbnail_url")
    if isinstance(thumbnail, str) and _is_safe_href(thumbnail):
        cleaned["thumbnailUrl"] = thumbnail

    content_type = cleaned.get("contentType")
    content_value = mapping.get("content")
    if _is_adaptive_card_content_type(content_type):
        cleaned["content"] = _sanitise_adaptive_card(content_value)
    elif isinstance(content_value, str):
        cleaned["content"] = _sanitise_html(content_value)
    elif isinstance(content_value, Mapping):
        cleaned["content"] = _sanitise_adaptive_card(content_value)
    elif content_value is not None:
        cleaned["content"] = content_value

    return _compact_dict(cleaned)


def _coerce_file_upload(
    upload: Union[TeamsFileUpload, Mapping[str, object]],
) -> Optional[TeamsFileUpload]:
    if isinstance(upload, TeamsFileUpload):
        return upload
    if not isinstance(upload, Mapping):
        return None

    filename_value = upload.get("filename") or upload.get("name")
    if not isinstance(filename_value, str) or not filename_value.strip():
        return None
    filename = filename_value.strip()

    content_value = (
        upload.get("content")
        or upload.get("data")
        or upload.get("bytes")
        or upload.get("body")
    )
    content_bytes: Optional[bytes]
    if hasattr(content_value, "read"):
        try:
            read_result = content_value.read()  # type: ignore[call-arg]
        except Exception:  # pragma: no cover - defensive
            return None
        content_bytes = bytes(read_result)
    elif isinstance(content_value, (bytes, bytearray, memoryview)):
        content_bytes = bytes(content_value)
    elif isinstance(content_value, str):
        content_bytes = content_value.encode("utf-8")
    else:
        content_bytes = None

    if content_bytes is None:
        return None

    content_type_value = (
        upload.get("content_type")
        or upload.get("contentType")
        or upload.get("mimetype")
        or upload.get("mime_type")
    )
    content_type = (
        str(content_type_value).strip()
        if isinstance(content_type_value, str) and content_type_value.strip()
        else None
    )

    inline_flag = upload.get("inline")
    inline = bool(inline_flag) if inline_flag is not None else False

    content_id_value = upload.get("content_id") or upload.get("contentId")
    content_id = (
        str(content_id_value).strip()
        if isinstance(content_id_value, (str, int)) and str(content_id_value).strip()
        else None
    )

    description_value = upload.get("description") or upload.get("alt_text")
    description = (
        str(description_value).strip()
        if isinstance(description_value, str) and description_value.strip()
        else None
    )

    return TeamsFileUpload(
        filename=filename,
        content=content_bytes,
        content_type=content_type,
        inline=inline,
        content_id=content_id,
        description=description,
    )


def _is_adaptive_card_content_type(content_type: object) -> bool:
    if not content_type:
        return False
    value = str(content_type).strip().lower()
    return value in {
        "application/vnd.microsoft.card.adaptive",
        "application/vnd.microsoft.card.hero",
        "application/vnd.microsoft.card.thumbnail",
    }


def _sanitise_adaptive_card(content: object) -> str:
    if isinstance(content, str) and content.strip():
        try:
            data = json.loads(content)
        except json.JSONDecodeError:
            data = {"type": "AdaptiveCard", "body": [{"type": "TextBlock", "text": content}]}
    elif isinstance(content, Mapping):
        data = dict(content)
    else:
        data = {}

    cleaned = _clean_adaptive_card(data)
    if cleaned is None:
        cleaned = {}
    return json.dumps(cleaned, ensure_ascii=False)


def _clean_adaptive_card(value: object) -> Optional[object]:
    if isinstance(value, Mapping):
        cleaned_mapping: Dict[str, object] = {}
        for key, entry in value.items():
            if entry is None:
                continue
            key_lower = key.lower()
            if key_lower in {"url", "href", "iconurl", "image"}:
                if isinstance(entry, str) and _is_safe_href(entry):
                    cleaned_mapping[key] = entry
                continue
            if key_lower in {"text", "title", "speak"} and isinstance(entry, str):
                cleaned_mapping[key] = html.escape(entry)
                continue
            cleaned_value = _clean_adaptive_card(entry)
            if cleaned_value is not None:
                cleaned_mapping[key] = cleaned_value
        return cleaned_mapping
    if isinstance(value, list):
        cleaned_list = []
        for item in value:
            cleaned_item = _clean_adaptive_card(item)
            if cleaned_item is not None:
                cleaned_list.append(cleaned_item)
        return cleaned_list
    if isinstance(value, (str, int, float, bool)):
        return value
    return None


class _TeamsHTMLSanitiser(HTMLParser):
    _ALLOWED_TAGS = {
        "a": {"href", "title"},
        "b": set(),
        "blockquote": set(),
        "br": set(),
        "code": {"class"},
        "em": set(),
        "i": set(),
        "li": set(),
        "ol": set(),
        "p": set(),
        "pre": {"class"},
        "span": {"class"},
        "strong": set(),
        "ul": set(),
    }
    _VOID_TAGS = {"br"}
    _ALLOWED_SCHEMES = {"http", "https", "mailto"}

    def __init__(self) -> None:
        super().__init__()
        self._parts: list[str] = []
        self._stack: list[Optional[str]] = []
        self._skip_depth = 0

    def handle_starttag(self, tag: str, attrs) -> None:
        tag_lower = tag.lower()
        if self._skip_depth > 0:
            if tag_lower not in self._VOID_TAGS:
                self._skip_depth += 1
                self._stack.append(None)
            return
        if tag_lower not in self._ALLOWED_TAGS:
            if tag_lower not in self._VOID_TAGS:
                self._skip_depth = 1
                self._stack.append(None)
            return

        attrs_text = self._serialise_attrs(tag_lower, attrs)
        if attrs_text is None:
            self._stack.append(None)
            return
        if tag_lower in self._VOID_TAGS:
            if attrs_text:
                self._parts.append(f"<{tag_lower}{attrs_text} />")
            else:
                self._parts.append(f"<{tag_lower} />")
            self._stack.append(None)
            return

        self._parts.append(f"<{tag_lower}{attrs_text}>")
        self._stack.append(tag_lower)

    def handle_startendtag(self, tag: str, attrs) -> None:  # pragma: no cover - handled via starttag
        before = len(self._stack)
        self.handle_starttag(tag, attrs)
        if len(self._stack) > before:
            entry = self._stack.pop()
            if entry:
                self._parts.append(f"</{entry}>")

    def handle_endtag(self, tag: str) -> None:
        tag_lower = tag.lower()
        if not self._stack:
            return
        entry = self._stack.pop()
        if entry is None:
            if self._skip_depth > 0:
                self._skip_depth -= 1
            return
        if entry == tag_lower:
            self._parts.append(f"</{tag_lower}>")

    def handle_data(self, data: str) -> None:
        if self._skip_depth > 0:
            return
        self._parts.append(html.escape(data))

    def handle_entityref(self, name: str) -> None:  # pragma: no cover - rare branch
        if self._skip_depth > 0:
            return
        self._parts.append(f"&{name};")

    def handle_charref(self, name: str) -> None:  # pragma: no cover - rare branch
        if self._skip_depth > 0:
            return
        self._parts.append(f"&#{name};")

    def _serialise_attrs(self, tag: str, attrs) -> Optional[str]:
        allowed = self._ALLOWED_TAGS[tag]
        parts: list[str] = []
        has_href = False
        for name, value in attrs:
            if value is None:
                continue
            name_lower = name.lower()
            if name_lower not in allowed:
                continue
            if name_lower == "href" and not _is_safe_href(value):
                continue
            escaped_value = html.escape(str(value), quote=True)
            parts.append(f'{name_lower}="{escaped_value}"')
            if name_lower == "href":
                has_href = True
        if tag == "a" and not has_href:
            return None
        if not parts:
            return ""
        return " " + " ".join(parts)

    def get_html(self) -> str:
        return "".join(self._parts)


def _sanitise_html(content: str) -> str:
    if not content:
        return ""
    parser = _TeamsHTMLSanitiser()
    parser.feed(content)
    parser.close()
    return parser.get_html()


def _render_plain_text(text: str) -> str:
    if not text:
        return ""
    escaped = html.escape(text)
    return "<p>" + escaped.replace("\n", "<br />") + "</p>"


def _is_safe_href(value: str) -> bool:
    if not value:
        return False
    parsed = urlparse(value)
    if parsed.scheme:
        return parsed.scheme.lower() in _TeamsHTMLSanitiser._ALLOWED_SCHEMES
    return not value.lower().strip().startswith("javascript:")


def _compact_dict(values: Mapping[str, object | None]) -> Dict[str, object]:
    compacted: Dict[str, object] = {}
    for key, value in values.items():
        if value is None:
            continue
        if isinstance(value, str) and value == "":
            continue
        if isinstance(value, (list, tuple)) and not value:
            continue
        if isinstance(value, Mapping) and not value:
            continue
        compacted[key] = value
    return compacted


def _as_str(value: object) -> Optional[str]:
    if isinstance(value, (str, int, float)):
        text = str(value)
        return text if text else None
    return None


class TeamsOAuthClient(TeamsOAuthClientProtocol):
    """OAuth helper that exchanges Microsoft authorization codes for tokens."""

    def __init__(
        self,
        client_id: str,
        *,
        client_secret: Optional[str] = None,
        tenant: str = "common",
        scope: Optional[Sequence[str]] = None,
        session: Optional[ClientSession] = None,
        logger: Optional[logging.Logger] = None,
    ) -> None:
        if session is not None and ClientSession is not None and not isinstance(session, ClientSession):
            raise RuntimeError("session must be an aiohttp.ClientSession instance")

        self._client_id = client_id
        self._client_secret = client_secret
        self._tenant = tenant
        self._scope = " ".join(scope) if scope else "https://graph.microsoft.com/.default"
        self._session = session
        self._owns_session = session is None
        self._logger = logger or logging.getLogger(__name__)

    async def exchange_code(
        self,
        code: str,
        *,
        redirect_uri: Optional[str] = None,
        code_verifier: Optional[str] = None,
    ) -> Mapping[str, object]:
        if aiohttp is None and self._session is None:  # pragma: no cover - exercised in integration tests
            raise RuntimeError("aiohttp is required to exchange Microsoft OAuth codes")

        await self._ensure_session()

        payload: Dict[str, object] = {
            "client_id": self._client_id,
            "scope": self._scope,
            "code": code,
            "grant_type": "authorization_code",
        }
        if redirect_uri:
            payload["redirect_uri"] = redirect_uri
        if code_verifier:
            payload["code_verifier"] = code_verifier
        if self._client_secret:
            payload["client_secret"] = self._client_secret

        token_endpoint = f"https://login.microsoftonline.com/{self._tenant}/oauth2/v2.0/token"
        data = await self._post(token_endpoint, payload)
        return data

    async def refresh_token(
        self,
        refresh_token: str,
        *,
        redirect_uri: Optional[str] = None,
    ) -> Mapping[str, object]:
        if aiohttp is None and self._session is None:  # pragma: no cover - exercised in integration tests
            raise RuntimeError("aiohttp is required to refresh Microsoft OAuth tokens")

        await self._ensure_session()

        payload: Dict[str, object] = {
            "client_id": self._client_id,
            "refresh_token": refresh_token,
            "grant_type": "refresh_token",
            "scope": self._scope,
        }
        if redirect_uri:
            payload["redirect_uri"] = redirect_uri
        if self._client_secret:
            payload["client_secret"] = self._client_secret

        token_endpoint = f"https://login.microsoftonline.com/{self._tenant}/oauth2/v2.0/token"
        data = await self._post(token_endpoint, payload)
        return data

    async def close(self) -> None:
        if self._owns_session and self._session is not None:
            await self._session.close()
            self._session = None

    async def _ensure_session(self) -> None:
        if self._session is None:
            if aiohttp is None:  # pragma: no cover
                raise RuntimeError("aiohttp is required to initialise the Teams OAuth client")
            timeout = aiohttp.ClientTimeout(total=60)
            self._session = aiohttp.ClientSession(timeout=timeout)

    async def _post(self, url: str, payload: Mapping[str, object]) -> Mapping[str, object]:
        if self._session is None:
            raise RuntimeError("OAuth session is not initialised")

        async with self._session.post(url, data=payload) as response:
            response.raise_for_status()
            data = await response.json()

        if not isinstance(data, Mapping):
            raise RuntimeError("Teams OAuth returned non-mapping payload")
        if "access_token" not in data:
            raise RuntimeError("Teams OAuth response missing access_token")
        return data


def _build_identity(me_payload: Mapping[str, object], tenant: TeamsTenant) -> TeamsIdentity:
    user = TeamsUser(
        id=str(me_payload.get("id")),
        display_name=me_payload.get("displayName"),
        user_principal_name=me_payload.get("userPrincipalName"),
        mail=me_payload.get("mail"),
    )
    return TeamsIdentity(tenant=tenant, user=user)


def _compare_timestamp(current: Optional[object], previous: Optional[str]) -> int:
    if not isinstance(previous, str):
        return 1
    current_dt = _parse_datetime(current)
    previous_dt = _parse_datetime(previous)
    if current_dt is None or previous_dt is None:
        return 1
    if current_dt > previous_dt:
        return 1
    if current_dt == previous_dt:
        return 0
    return -1


def _parse_datetime(value: Optional[object]) -> Optional[dt.datetime]:
    if not isinstance(value, str):
        return None
    try:
        if value.endswith("Z"):
            value = value[:-1] + "+00:00"
        return dt.datetime.fromisoformat(value)
    except ValueError:
        return None
