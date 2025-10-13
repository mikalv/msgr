"""Protocols and dataclasses describing the Teams bridge surface area."""

from __future__ import annotations

import asyncio
import contextlib
import datetime as dt
import json
import logging
import time
from dataclasses import dataclass
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
)

try:  # pragma: no cover - optional dependency exercised in integration tests
    import aiohttp
    from aiohttp import ClientSession
except ImportError:  # pragma: no cover - aiohttp not available during unit tests
    aiohttp = None  # type: ignore
    ClientSession = None  # type: ignore

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


class TeamsGraphClient(TeamsClientProtocol):
    """Microsoft Graph implementation that polls chats for new messages."""

    _GRAPH_BASE = "https://graph.microsoft.com/v1.0"

    def __init__(
        self,
        *,
        session: Optional[ClientSession] = None,
        logger: Optional[logging.Logger] = None,
        poll_interval: float = 15.0,
    ) -> None:
        if session is not None and ClientSession is not None and not isinstance(session, ClientSession):
            raise RuntimeError("session must be an aiohttp.ClientSession instance")

        self._session = session
        self._owns_session = session is None
        self._logger = logger or logging.getLogger(__name__)
        self._poll_interval = max(5.0, poll_interval)
        self._token: Optional[TeamsToken] = None
        self._tenant: Optional[TeamsTenant] = None
        self._identity: Optional[TeamsIdentity] = None
        self._capabilities: Optional[Mapping[str, object]] = None
        self._handlers: list[UpdateHandler] = []
        self._poll_task: Optional[asyncio.Task[None]] = None
        self._last_message_ts: Dict[str, str] = {}
        self._acked: Dict[str, float] = {}

    async def connect(self, tenant: TeamsTenant, token: TeamsToken) -> None:
        if aiohttp is None:  # pragma: no cover - exercised in integration tests
            raise RuntimeError("aiohttp is required to connect to Microsoft Graph")

        await self._ensure_session()
        self._token = token
        self._tenant = tenant

        me = await self._get("/me")
        self._identity = _build_identity(me, tenant)

        if self._poll_task is None or self._poll_task.done():
            self._poll_task = asyncio.create_task(self._poll_loop(), name="teams-graph-poller")

    async def disconnect(self) -> None:
        if self._poll_task is not None:
            self._poll_task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await self._poll_task
            self._poll_task = None

        if self._owns_session and self._session is not None:
            await self._session.close()
            self._session = None

    async def is_connected(self) -> bool:
        return bool(self._poll_task is not None and not self._poll_task.done())

    async def fetch_identity(self) -> TeamsIdentity:
        if self._identity is None:
            raise RuntimeError("Teams client not connected")
        return self._identity

    async def describe_capabilities(self) -> Mapping[str, object]:
        if self._capabilities is None:
            self._capabilities = {
                "messaging": {"text": True, "mentions": True, "attachments": ["file", "image"]},
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
    ) -> Mapping[str, object]:
        payload = dict(message)
        if metadata is not None:
            payload.setdefault("metadata", dict(metadata))
        if reply_to_id is not None:
            payload.setdefault("replyToId", reply_to_id)
        return await self._post(f"/chats/{conversation_id}/messages", payload)

    async def acknowledge_event(self, event_id: str) -> None:
        if not event_id:
            return
        self._acked[event_id] = time.time()

    def add_event_handler(self, handler: UpdateHandler) -> None:
        if handler not in self._handlers:
            self._handlers.append(handler)

    def remove_event_handler(self, handler: UpdateHandler) -> None:
        if handler in self._handlers:
            self._handlers.remove(handler)

    async def _ensure_session(self) -> None:
        if self._session is None:
            if aiohttp is None:  # pragma: no cover
                raise RuntimeError("aiohttp is required to create a Teams HTTP session")
            timeout = aiohttp.ClientTimeout(total=60)
            self._session = aiohttp.ClientSession(timeout=timeout)

    async def _poll_loop(self) -> None:
        try:
            while True:
                try:
                    chats = await self.list_conversations()
                    for chat in chats:
                        chat_id = str(chat.get("id"))
                        if chat_id:
                            await self._poll_chat(chat_id)
                except asyncio.CancelledError:
                    raise
                except Exception:  # pragma: no cover - network errors logged
                    self._logger.exception("Teams polling iteration failed")
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
        for handler in list(self._handlers):
            try:
                await handler(event)
            except Exception:  # pragma: no cover - handler failures logged for ops
                self._logger.exception("Teams handler raised")

    async def _get(
        self,
        path: str,
        params: Optional[Mapping[str, object]] = None,
    ) -> Mapping[str, object]:
        if self._session is None or self._token is None:
            raise RuntimeError("Teams client is not connected")

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


def _normalise_chat_event(
    tenant: Optional[TeamsTenant], chat_id: str, message: Mapping[str, object]
) -> Optional[Dict[str, object]]:
    if not isinstance(message, Mapping):
        return None

    message_id = message.get("id") or message.get("messageId")
    if not isinstance(message_id, (str, int)):
        return None
    message_id_str = str(message_id)

    conversation = _compact_dict(
        {
            "id": chat_id,
            "tenant_id": tenant.id if tenant else None,
            "channel_identity": _normalise_channel_identity(message.get("channelIdentity")),
        }
    )

    message_payload = _compact_dict(
        {
            "id": message_id_str,
            "message_type": message.get("messageType"),
            "subject": message.get("subject"),
            "summary": message.get("summary"),
            "reply_to_id": _as_str(message.get("replyToId")),
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
        }
    )

    event = _compact_dict(
        {
            "event_id": message_id_str,
            "event_type": "message",
            "tenant_id": tenant.id if tenant else None,
            "chat_id": chat_id,
            "conversation": conversation if conversation else None,
            "message": message_payload if message_payload else None,
        }
    )
    return event if event else None


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
