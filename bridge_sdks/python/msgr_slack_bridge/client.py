"""Protocols and dataclasses describing the Slack bridge surface area."""

from __future__ import annotations

import asyncio
import contextlib
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

try:  # pragma: no cover - optional runtime dependency
    import aiohttp
    from aiohttp import ClientSession, ClientWebSocketResponse, WSMessage, WSMsgType
except ImportError:  # pragma: no cover - aiohttp not installed during unit tests
    aiohttp = None  # type: ignore
    ClientSession = None  # type: ignore
    ClientWebSocketResponse = None  # type: ignore
    WSMessage = None  # type: ignore
    WSMsgType = None  # type: ignore

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


class SlackRTMClient(SlackClientProtocol):
    """Concrete Slack RTM implementation that talks to the Slack Web API."""

    _API_BASE = "https://slack.com/api"

    def __init__(
        self,
        *,
        session: Optional[ClientSession] = None,
        logger: Optional[logging.Logger] = None,
    ) -> None:
        if session is not None and ClientSession is not None and not isinstance(session, ClientSession):
            raise RuntimeError("session must be an aiohttp.ClientSession instance")

        self._session = session
        self._owns_session = session is None
        self._logger = logger or logging.getLogger(__name__)
        self._token: Optional[SlackToken] = None
        self._websocket: Optional[ClientWebSocketResponse] = None
        self._reader_task: Optional[asyncio.Task[None]] = None
        self._handlers: list[UpdateHandler] = []
        self._identity: Optional[SlackIdentity] = None
        self._capabilities: Optional[Mapping[str, object]] = None
        self._acked: Dict[str, float] = {}

    async def connect(self, token: SlackToken) -> None:
        if aiohttp is None:  # pragma: no cover - exercised in integration tests
            raise RuntimeError("aiohttp is required to establish Slack RTM sessions")

        await self._ensure_session()
        self._token = token

        handshake = await self._api_call("rtm.connect")
        url = str(handshake.get("url"))
        if not url:
            raise RuntimeError("Slack RTM connect response did not include a websocket URL")

        identity = _extract_identity_from_connect(handshake)
        if identity is not None:
            self._identity = identity

        assert self._session is not None
        self._websocket = await self._session.ws_connect(url, heartbeat=20)
        self._reader_task = asyncio.create_task(self._consume_events(), name="slack-rtm")

    async def disconnect(self) -> None:
        if self._reader_task is not None:
            self._reader_task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await self._reader_task
            self._reader_task = None

        if self._websocket is not None:
            await self._websocket.close()
            self._websocket = None

        if self._owns_session and self._session is not None:
            await self._session.close()
            self._session = None

    async def is_connected(self) -> bool:
        return bool(self._websocket is not None and not self._websocket.closed)

    async def fetch_identity(self) -> SlackIdentity:
        if self._identity is None:
            auth = await self._api_call("auth.test")
            user_id = str(auth.get("user_id"))
            team_id = str(auth.get("team_id"))
            user_info = await self._api_call("users.info", params={"user": user_id})
            team_info = await self._api_call("team.info", params={"team": team_id})
            self._identity = _build_identity_from_payload(team_info, user_info)
        return self._identity

    async def describe_capabilities(self) -> Mapping[str, object]:
        if self._capabilities is None:
            auth = await self._api_call("auth.test")
            capabilities: Dict[str, object] = {
                "messaging": {
                    "text": True,
                    "threads": True,
                    "reactions": True,
                    "attachments": ["image", "video", "audio", "file"],
                },
                "presence": {"typing": True, "read_receipts": True},
            }
            if isinstance(auth.get("scope"), str):
                capabilities["scope"] = auth["scope"]
            self._capabilities = capabilities
        return self._capabilities

    async def list_members(self) -> Sequence[Mapping[str, object]]:
        members: list[Mapping[str, object]] = []
        async for page in self._paginate("users.list", "members", params={"limit": 200}):
            members.extend(page)
        return members

    async def list_conversations(self) -> Sequence[Mapping[str, object]]:
        conversations: list[Mapping[str, object]] = []
        params = {"types": "public_channel,private_channel,mpim,im", "limit": 200}
        async for page in self._paginate("conversations.list", "channels", params=params):
            conversations.extend(page)
        return conversations

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
        payload: Dict[str, object] = {"channel": channel, "text": text, "reply_broadcast": reply_broadcast}
        if blocks is not None:
            payload["blocks"] = list(blocks)
        if attachments is not None:
            payload["attachments"] = list(attachments)
        if thread_ts is not None:
            payload["thread_ts"] = thread_ts
        if metadata is not None:
            payload["metadata"] = dict(metadata)
        return await self._api_call("chat.postMessage", http_method="POST", payload=payload)

    async def acknowledge_event(self, event_id: str) -> None:
        if not event_id:
            return
        self._acked[event_id] = time.time()
        if self._websocket is not None and not self._websocket.closed:
            try:
                await self._websocket.send_json({"type": "ack", "event_id": event_id})
            except Exception:  # pragma: no cover - ack failures logged for diagnostics
                self._logger.debug("Slack ack send failed", exc_info=True)

    def add_event_handler(self, handler: UpdateHandler) -> None:
        if handler not in self._handlers:
            self._handlers.append(handler)

    def remove_event_handler(self, handler: UpdateHandler) -> None:
        if handler in self._handlers:
            self._handlers.remove(handler)

    async def _ensure_session(self) -> None:
        if self._session is None:
            if aiohttp is None:  # pragma: no cover
                raise RuntimeError("aiohttp is required to create a Slack HTTP session")
            timeout = aiohttp.ClientTimeout(total=60)
            self._session = aiohttp.ClientSession(timeout=timeout)

    async def _consume_events(self) -> None:
        if self._websocket is None:
            return
        try:
            async for message in self._websocket:  # type: ignore[union-attr]
                await self._handle_ws_message(message)
        except asyncio.CancelledError:  # pragma: no cover - cancellation path
            pass
        except Exception:  # pragma: no cover - network failures logged for ops
            self._logger.exception("Slack websocket consumer crashed")

    async def _handle_ws_message(self, message: WSMessage) -> None:
        if WSMsgType is None:
            return
        if message.type == WSMsgType.TEXT:
            payload = json.loads(message.data)
            event = _normalise_event(payload)
            if event is not None:
                await self._dispatch_event(event)
        elif message.type in (WSMsgType.CLOSE, WSMsgType.CLOSED, WSMsgType.ERROR):
            self._logger.debug("Slack websocket closed: %s", message.type)

    async def _dispatch_event(self, event: Mapping[str, object]) -> None:
        for handler in list(self._handlers):
            try:
                await handler(event)
            except Exception:  # pragma: no cover - handler failures logged for ops
                self._logger.exception("Slack handler raised")

    async def _api_call(
        self,
        method: str,
        *,
        params: Optional[Mapping[str, object]] = None,
        payload: Optional[Mapping[str, object]] = None,
        http_method: str = "GET",
    ) -> Mapping[str, object]:
        if self._session is None or self._token is None:
            raise RuntimeError("Slack client is not connected")

        url = f"{self._API_BASE}/{method}"
        headers = {"Authorization": f"Bearer {self._token.value}", "Content-Type": "application/json; charset=utf-8"}

        request_params = dict(params or {})
        request_json = dict(payload or {}) if payload is not None else None
        async with self._session.request(
            http_method,
            url,
            params=request_params if http_method.upper() == "GET" else None,
            json=request_json if http_method.upper() != "GET" else None,
            headers=headers,
        ) as response:
            response.raise_for_status()
            data = await response.json()

        if not isinstance(data, Mapping):
            raise RuntimeError(f"Slack API {method} returned non-mapping payload")
        if not data.get("ok", True):
            raise RuntimeError(f"Slack API error for {method}: {data.get('error')}")
        return data

    async def _paginate(
        self,
        method: str,
        key: str,
        *,
        params: Optional[Mapping[str, object]] = None,
    ) -> Iterable[Sequence[Mapping[str, object]]]:
        cursor: Optional[str] = None
        while True:
            merged = dict(params or {})
            if cursor:
                merged["cursor"] = cursor
            data = await self._api_call(method, params=merged)
            items = data.get(key)
            if isinstance(items, list):
                yield [item for item in items if isinstance(item, Mapping)]
            cursor = _extract_cursor(data)
            if not cursor:
                break


class SlackOAuthClient(SlackOAuthClientProtocol):
    """Slack OAuth helper used during workspace installation flows."""

    _API_BASE = "https://slack.com/api"

    def __init__(
        self,
        client_id: str,
        *,
        client_secret: Optional[str] = None,
        session: Optional[ClientSession] = None,
        logger: Optional[logging.Logger] = None,
    ) -> None:
        if session is not None and ClientSession is not None and not isinstance(session, ClientSession):
            raise RuntimeError("session must be an aiohttp.ClientSession instance")

        self._client_id = client_id
        self._client_secret = client_secret
        self._session = session
        self._owns_session = session is None
        self._logger = logger or logging.getLogger(__name__)

    async def exchange_code(
        self,
        code: str,
        *,
        code_verifier: Optional[str] = None,
        redirect_uri: Optional[str] = None,
    ) -> Mapping[str, object]:
        if aiohttp is None:  # pragma: no cover - exercised in integration tests
            raise RuntimeError("aiohttp is required to exchange Slack OAuth codes")

        await self._ensure_session()

        payload: Dict[str, object] = {"code": code, "client_id": self._client_id}
        if code_verifier:
            payload["code_verifier"] = code_verifier
        if redirect_uri:
            payload["redirect_uri"] = redirect_uri
        if self._client_secret:
            payload["client_secret"] = self._client_secret

        data = await self._post("oauth.v2.access", payload)
        return data

    async def close(self) -> None:
        if self._owns_session and self._session is not None:
            await self._session.close()
            self._session = None

    async def _ensure_session(self) -> None:
        if self._session is None:
            if aiohttp is None:  # pragma: no cover
                raise RuntimeError("aiohttp is required to initialise the Slack OAuth client")
            timeout = aiohttp.ClientTimeout(total=60)
            self._session = aiohttp.ClientSession(timeout=timeout)

    async def _post(self, method: str, payload: Mapping[str, object]) -> Mapping[str, object]:
        if self._session is None:
            raise RuntimeError("OAuth session is not initialised")

        url = f"{self._API_BASE}/{method}"
        async with self._session.post(url, data=payload) as response:
            response.raise_for_status()
            data = await response.json()

        if not isinstance(data, Mapping):
            raise RuntimeError("Slack OAuth returned non-mapping payload")
        if not data.get("ok", True):
            raise RuntimeError(f"Slack OAuth error: {data.get('error')}")
        return data


def _extract_cursor(payload: Mapping[str, object]) -> Optional[str]:
    metadata = payload.get("response_metadata")
    if isinstance(metadata, Mapping):
        cursor = metadata.get("next_cursor")
        if isinstance(cursor, str) and cursor:
            return cursor
    return None


def _extract_identity_from_connect(payload: Mapping[str, object]) -> Optional[SlackIdentity]:
    if not isinstance(payload, Mapping):
        return None
    team = payload.get("team")
    user = payload.get("self") or payload.get("user")
    if not isinstance(team, Mapping) or not isinstance(user, Mapping):
        return None
    workspace = SlackWorkspace(
        id=str(team.get("id")),
        name=team.get("name"),
        domain=team.get("domain"),
        icon=team.get("icon", {}).get("image_68") if isinstance(team.get("icon"), Mapping) else None,
    )
    slack_user = SlackUser(
        id=str(user.get("id")),
        real_name=user.get("real_name") or user.get("name"),
        display_name=user.get("display_name") or user.get("name"),
        email=user.get("email"),
    )
    return SlackIdentity(workspace=workspace, user=slack_user)


def _build_identity_from_payload(
    team_info: Mapping[str, object],
    user_info: Mapping[str, object],
) -> SlackIdentity:
    team = team_info.get("team") if isinstance(team_info.get("team"), Mapping) else team_info
    user = user_info.get("user") if isinstance(user_info.get("user"), Mapping) else user_info

    workspace = SlackWorkspace(
        id=str(team.get("id")),
        name=team.get("name"),
        domain=team.get("domain"),
        icon=team.get("icon", {}).get("image_68") if isinstance(team.get("icon"), Mapping) else None,
    )
    profile = user.get("profile") if isinstance(user.get("profile"), Mapping) else {}
    slack_user = SlackUser(
        id=str(user.get("id")),
        real_name=profile.get("real_name") or user.get("real_name"),
        display_name=profile.get("display_name") or user.get("name"),
        email=profile.get("email") or user.get("email"),
    )
    return SlackIdentity(workspace=workspace, user=slack_user)


def _normalise_event(payload: Mapping[str, object]) -> Optional[Dict[str, object]]:
    if not isinstance(payload, Mapping):
        return None

    event_payload = payload.get("event") if isinstance(payload.get("event"), Mapping) else payload
    if not isinstance(event_payload, Mapping):
        return None

    event_type = str(event_payload.get("type") or payload.get("type") or "")

    if event_type == "message":
        return _normalise_message_event(payload, event_payload)
    if event_type in {"reaction_added", "reaction_removed"}:
        return _normalise_reaction_event(payload, event_payload)

    return _base_event(payload, event_payload)


def _normalise_message_event(
    wrapper: Mapping[str, object], event_payload: Mapping[str, object]
) -> Optional[Dict[str, object]]:
    message_payload = event_payload.get("message") if isinstance(event_payload.get("message"), Mapping) else event_payload
    previous_message = event_payload.get("previous_message")

    event = _base_event(wrapper, event_payload)
    event["event_type"] = "message"

    channel_id = _extract_channel_id(event_payload, message_payload)
    team_id = _extract_team_id(wrapper, event_payload, message_payload)

    message = _normalise_message_payload(message_payload)
    if message:
        event.setdefault("message", message)
        if message.get("ts"):
            event.setdefault("ts", message["ts"])  # type: ignore[index]
        if message.get("thread_ts"):
            event.setdefault("thread_ts", message["thread_ts"])  # type: ignore[index]

    conversation = _compact(
        {
            "id": channel_id,
            "team_id": team_id,
            "type": event_payload.get("channel_type"),
            "thread_ts": message.get("thread_ts") if message else None,
        }
    )
    if conversation:
        event["conversation"] = conversation

    if channel_id:
        event["channel_id"] = channel_id
    if team_id:
        event["team_id"] = team_id

    subtype = event_payload.get("subtype")
    if isinstance(subtype, str) and subtype:
        event["subtype"] = subtype

    if isinstance(previous_message, Mapping):
        event["previous_message"] = _normalise_message_payload(previous_message)

    if subtype == "message_changed":
        event["change_type"] = "edited"
    elif subtype == "message_deleted":
        event["change_type"] = "deleted"
        deleted_ts = event_payload.get("deleted_ts")
        if deleted_ts is not None:
            event["deleted_ts"] = str(deleted_ts)
        if "message" not in event:
            event["message"] = {}

    return event if event else None


def _normalise_reaction_event(
    wrapper: Mapping[str, object], event_payload: Mapping[str, object]
) -> Dict[str, object]:
    event = _base_event(wrapper, event_payload)
    event_type = str(event_payload.get("type") or "reaction")
    event["event_type"] = "reaction"
    event["reaction"] = event_payload.get("reaction")
    event["action"] = "added" if event_type == "reaction_added" else "removed"
    user_id = event_payload.get("user")
    if isinstance(user_id, (str, int)):
        event["user_id"] = str(user_id)
    item_user = event_payload.get("item_user")
    if isinstance(item_user, (str, int)):
        event["item_user"] = str(item_user)

    item = event_payload.get("item")
    normalised_item = _compact(
        {
            "type": item.get("type") if isinstance(item, Mapping) else None,
            "channel": _ensure_str(item.get("channel")) if isinstance(item, Mapping) else None,
            "ts": _ensure_str(item.get("ts")) if isinstance(item, Mapping) else None,
        }
    )
    if normalised_item:
        event["item"] = normalised_item

    channel_id = _extract_channel_id(event_payload, item if isinstance(item, Mapping) else None)
    team_id = _extract_team_id(wrapper, event_payload)
    if channel_id:
        event["channel_id"] = channel_id
    if team_id:
        event["team_id"] = team_id

    return event


def _base_event(
    wrapper: Mapping[str, object], event_payload: Mapping[str, object]
) -> Dict[str, object]:
    event_id = _extract_event_id(wrapper, event_payload)
    event: Dict[str, object] = {"event_id": event_id}
    wrapper_type = wrapper.get("type")
    if isinstance(wrapper_type, str) and wrapper_type:
        event["callback_type"] = wrapper_type
    team_id = _extract_team_id(wrapper, event_payload)
    if team_id:
        event["team_id"] = team_id
    return event


def _extract_event_id(
    wrapper: Mapping[str, object], event_payload: Mapping[str, object]
) -> str:
    candidates: list[object] = [
        event_payload.get("event_ts"),
        event_payload.get("ts"),
        wrapper.get("event_id"),
    ]
    message = event_payload.get("message")
    if isinstance(message, Mapping):
        candidates.extend(
            [message.get("event_ts"), message.get("ts"), message.get("client_msg_id")]
        )
    for candidate in candidates:
        if isinstance(candidate, (str, int, float)) and str(candidate):
            return str(candidate)
    return str(time.time())


def _extract_team_id(
    *sources: Mapping[str, object] | None,
) -> Optional[str]:
    for source in sources:
        if not isinstance(source, Mapping):
            continue
        team = source.get("team") or source.get("team_id")
        if isinstance(team, (str, int)) and str(team):
            return str(team)
    return None


def _extract_channel_id(
    event_payload: Mapping[str, object],
    message_payload: Mapping[str, object] | None = None,
) -> Optional[str]:
    channel = event_payload.get("channel")
    if isinstance(channel, Mapping):
        channel = channel.get("id")
    if not channel and isinstance(message_payload, Mapping):
        channel = message_payload.get("channel")
    item = event_payload.get("item")
    if not channel and isinstance(item, Mapping):
        channel = item.get("channel")
    if isinstance(channel, (str, int)) and str(channel):
        return str(channel)
    return None


def _normalise_message_payload(message: Mapping[str, object]) -> Dict[str, object]:
    if not isinstance(message, Mapping):
        return {}

    payload = _compact(
        {
            "id": _ensure_str(
                message.get("client_msg_id") or message.get("id") or message.get("ts")
            ),
            "ts": _ensure_str(message.get("ts")),
            "text": message.get("text"),
            "user": _ensure_str(message.get("user")),
            "bot_id": _ensure_str(message.get("bot_id")),
            "team": _ensure_str(message.get("team")),
            "thread_ts": _ensure_str(message.get("thread_ts")),
            "parent_user_id": _ensure_str(message.get("parent_user_id")),
            "app_id": _ensure_str(message.get("app_id")),
            "reply_broadcast": bool(message.get("reply_broadcast"))
            if "reply_broadcast" in message
            else None,
            "metadata": dict(message.get("metadata", {}))
            if isinstance(message.get("metadata"), Mapping)
            else None,
            "blocks": [block for block in message.get("blocks", []) if isinstance(block, Mapping)]
            if isinstance(message.get("blocks"), list)
            else None,
            "attachments": _normalise_attachments(message.get("attachments")),
            "files": _normalise_files(message.get("files")),
            "reactions": _normalise_message_reactions(message.get("reactions")),
            "edited": dict(message.get("edited"))
            if isinstance(message.get("edited"), Mapping)
            else None,
        }
    )
    return payload


def _normalise_attachments(attachments: object) -> Optional[list[Mapping[str, object]]]:
    if not isinstance(attachments, list):
        return None
    normalised: list[Mapping[str, object]] = []
    for attachment in attachments:
        if not isinstance(attachment, Mapping):
            continue
        normalised_attachment = _compact(
            {
                "id": _ensure_str(attachment.get("id")),
                "fallback": attachment.get("fallback"),
                "text": attachment.get("text"),
                "title": attachment.get("title"),
                "pretext": attachment.get("pretext"),
                "color": attachment.get("color"),
                "fields": [field for field in attachment.get("fields", []) if isinstance(field, Mapping)]
                if isinstance(attachment.get("fields"), list)
                else None,
                "author_name": attachment.get("author_name"),
                "author_link": attachment.get("author_link"),
                "author_icon": attachment.get("author_icon"),
                "thumb_url": attachment.get("thumb_url") or attachment.get("thumb_360"),
                "footer": attachment.get("footer"),
                "ts": _ensure_str(attachment.get("ts")),
            }
        )
        if normalised_attachment:
            normalised.append(normalised_attachment)
    return normalised or None


def _normalise_files(files: object) -> Optional[list[Mapping[str, object]]]:
    if not isinstance(files, list):
        return None
    normalised: list[Mapping[str, object]] = []
    for entry in files:
        if not isinstance(entry, Mapping):
            continue
        normalised_file = _compact(
            {
                "id": _ensure_str(entry.get("id")),
                "name": entry.get("name"),
                "title": entry.get("title"),
                "mimetype": entry.get("mimetype"),
                "filetype": entry.get("filetype"),
                "size": entry.get("size"),
                "permalink": entry.get("permalink"),
                "url_private": entry.get("url_private"),
                "url_private_download": entry.get("url_private_download"),
                "thumb_url": entry.get("thumb_360"),
            }
        )
        if normalised_file:
            normalised.append(normalised_file)
    return normalised or None


def _normalise_message_reactions(reactions: object) -> Optional[list[Mapping[str, object]]]:
    if not isinstance(reactions, list):
        return None
    normalised: list[Mapping[str, object]] = []
    for reaction in reactions:
        if not isinstance(reaction, Mapping):
            continue
        users = reaction.get("users") if isinstance(reaction.get("users"), list) else []
        normalised_reaction = _compact(
            {
                "name": reaction.get("name"),
                "count": reaction.get("count"),
                "users": [str(user) for user in users if isinstance(user, (str, int))],
            }
        )
        if normalised_reaction:
            normalised.append(normalised_reaction)
    return normalised or None


def _compact(values: Mapping[str, object | None]) -> Dict[str, object]:
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


def _ensure_str(value: object) -> Optional[str]:
    if isinstance(value, (str, int, float)):
        text = str(value)
        return text if text else None
    return None
