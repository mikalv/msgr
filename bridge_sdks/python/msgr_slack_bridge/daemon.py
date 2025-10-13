"""Slack bridge daemon wiring StoneMQ queue handlers to the RTM client."""

from __future__ import annotations

import copy
from typing import Dict, Mapping, MutableMapping, Optional

from msgr_bridge_sdk import Envelope, StoneMQClient, build_envelope

from .client import SlackClientProtocol, SlackIdentity, SlackOAuthClientProtocol, SlackToken
from .session import SessionData, SessionManager

_DEFAULT_CAPABILITIES: Mapping[str, object] = {
    "messaging": {
        "text": True,
        "threads": True,
        "reactions": True,
        "attachments": ["image", "video", "audio", "file"],
    },
    "presence": {"typing": True, "read_receipts": True},
}


class SlackBridgeDaemon:
    """Coordinates queue handlers and Slack RTM client sessions."""

    def __init__(
        self,
        mq_client: StoneMQClient,
        sessions: SessionManager,
        *,
        default_user_id: Optional[str] = None,
        oauth: Optional[SlackOAuthClientProtocol] = None,
        instance: Optional[str] = None,
    ) -> None:
        self._client = mq_client
        self._sessions = sessions
        self._default_user_id = default_user_id
        self._oauth = oauth
        self._instance = instance
        self._event_handlers: Dict[str, object] = {}
        self._ack_state: Dict[str, Mapping[str, object]] = {}

        self._client.register("outbound_message", self._handle_outbound_message)
        self._client.register("ack_event", self._handle_ack_event)
        self._client.register_request("link_account", self._handle_link_account)

    async def start(self) -> None:
        await self._client.start()

    async def shutdown(self) -> None:
        for key, handler in list(self._event_handlers.items()):
            user_id, instance = key.split("::", 1)
            instance = None if instance == "workspace" else instance
            try:
                client = self._sessions.get_client(user_id, instance)
            except RuntimeError:
                continue
            client.remove_event_handler(handler)  # type: ignore[arg-type]
            self._event_handlers.pop(key, None)
        await self._sessions.shutdown()

    @property
    def acked_events(self) -> Mapping[str, Mapping[str, object]]:
        return copy.deepcopy(self._ack_state)

    async def _handle_link_account(self, envelope: Envelope) -> Mapping[str, object]:
        payload = dict(envelope.payload)
        user_id = str(payload.get("user_id") or self._default_user_id or "default")

        session_payload = payload.get("session") or {}
        if not isinstance(session_payload, Mapping):
            raise ValueError("session payload must be a mapping")

        token = _extract_token(session_payload)
        workspace_hint = _extract_workspace(payload)
        instance = self._instance or workspace_hint.get("id")

        if token is None and self._oauth is not None:
            oauth_payload = payload.get("installation") or payload.get("oauth") or {}
            if isinstance(oauth_payload, Mapping):
                code = oauth_payload.get("code")
                if isinstance(code, str) and code:
                    redirect_uri = oauth_payload.get("redirect_uri")
                    code_verifier = oauth_payload.get("code_verifier")
                    oauth_response = await self._oauth.exchange_code(
                        code,
                        redirect_uri=str(redirect_uri) if isinstance(redirect_uri, str) else None,
                        code_verifier=str(code_verifier) if isinstance(code_verifier, str) else None,
                    )
                    token = _extract_token(oauth_response)
                    workspace_hint = _extract_workspace(oauth_response) or workspace_hint
                    session_payload = oauth_response.get("session") or session_payload

        if token is None:
            plan = _browser_capture_plan()
            plan.setdefault("status", "token_required")
            return plan

        client, session = await self._sessions.ensure_client(
            user_id,
            instance,
            token=token,
        )

        identity = await client.fetch_identity()
        session = await self._synchronise_session(user_id, instance, session, identity)

        await self._register_event_handler(user_id, instance, identity, client)

        capabilities = await client.describe_capabilities()
        members = await client.list_members()
        channels = await client.list_conversations()

        return self._build_linked_response(identity, session, capabilities, members, channels)

    async def _handle_outbound_message(self, envelope: Envelope) -> None:
        metadata = envelope.metadata
        payload = envelope.payload
        user_id = metadata.get("user_id", self._default_user_id)
        instance = metadata.get("instance", self._instance)
        if user_id is None:
            raise RuntimeError("user_id metadata required for outbound Slack messages")

        client, _ = await self._sessions.ensure_client(str(user_id), instance)

        channel = str(payload["channel"])
        text = str(payload.get("text", ""))
        blocks = payload.get("blocks") if isinstance(payload.get("blocks"), list) else None
        attachments = payload.get("attachments") if isinstance(payload.get("attachments"), list) else None
        thread_ts = payload.get("thread_ts")
        reply_broadcast = bool(payload.get("reply_broadcast", False))
        metadata_payload = payload.get("metadata") if isinstance(payload.get("metadata"), Mapping) else None

        await client.post_message(
            channel,
            text,
            blocks=blocks,  # type: ignore[arg-type]
            attachments=attachments,  # type: ignore[arg-type]
            thread_ts=str(thread_ts) if isinstance(thread_ts, str) else None,
            reply_broadcast=reply_broadcast,
            metadata=metadata_payload,
        )

    async def _handle_ack_event(self, envelope: Envelope) -> None:
        metadata = envelope.metadata
        payload = envelope.payload
        user_id = metadata.get("user_id", self._default_user_id)
        instance = metadata.get("instance", self._instance)
        event_id = payload.get("event_id")
        if user_id is None or event_id is None:
            return

        try:
            client = self._sessions.get_client(str(user_id), instance)
        except RuntimeError:
            return

        await client.acknowledge_event(str(event_id))
        self._ack_state[str(event_id)] = dict(payload)

    async def _register_event_handler(
        self,
        user_id: str,
        instance: Optional[str],
        identity: SlackIdentity,
        client: SlackClientProtocol,
    ) -> None:
        key = f"{user_id}::{instance or 'workspace'}"
        if key in self._event_handlers:
            return

        async def handler(event: Mapping[str, object]) -> None:
            payload: MutableMapping[str, object] = dict(event)
            payload.setdefault("user_id", user_id)
            payload.setdefault("workspace_id", identity.workspace.id)
            envelope = build_envelope("slack", "inbound_event", payload)
            await self._client.publish("inbound_event", envelope, instance=instance)

        client.add_event_handler(handler)
        self._event_handlers[key] = handler

    async def _synchronise_session(
        self,
        user_id: str,
        instance: Optional[str],
        session: SessionData,
        identity: SlackIdentity,
    ) -> SessionData:
        enriched = SessionData(
            token=session.token,
            workspace_id=identity.workspace.id,
            user_id=user_id,
        )
        await self._sessions.ensure_client(user_id, instance, session=enriched)
        return enriched

    def _build_linked_response(
        self,
        identity: SlackIdentity,
        session: SessionData,
        capabilities: Mapping[str, object],
        members: Mapping[str, object] | list[Mapping[str, object]],
        channels: Mapping[str, object] | list[Mapping[str, object]],
    ) -> Mapping[str, object]:
        response: Dict[str, object] = {
            "status": "linked",
            "workspace": identity.workspace.to_dict(),
            "user": identity.user.to_dict(),
            "session": _session_payload(session),
            "capabilities": copy.deepcopy(_DEFAULT_CAPABILITIES),
            "members": _ensure_list(members),
            "conversations": _ensure_list(channels),
        }
        response["capabilities"].update(copy.deepcopy(capabilities))
        return response


def _extract_token(payload: Mapping[str, object]) -> Optional[SlackToken]:
    if isinstance(payload, Mapping):
        maybe_token = payload.get("token") or payload.get("access_token") or payload.get("value")
        if isinstance(maybe_token, SlackToken):
            return maybe_token
        if isinstance(maybe_token, str) and maybe_token:
            token_type = payload.get("token_type") or payload.get("kind") or "user"
            expires_at = payload.get("expires_at")
            return SlackToken(
                value=maybe_token,
                token_type=str(token_type),
                expires_at=float(expires_at) if isinstance(expires_at, (int, float)) else None,
            )
    elif isinstance(payload, SlackToken):
        return payload
    elif isinstance(payload, str) and payload:
        return SlackToken(value=payload)
    return None


def _extract_workspace(payload: Mapping[str, object]) -> Mapping[str, object]:
    if not isinstance(payload, Mapping):
        return {}
    candidates = [
        payload.get("workspace"),
        payload.get("team"),
    ]
    for candidate in candidates:
        if isinstance(candidate, Mapping):
            return candidate
    return {}


def _session_payload(session: SessionData) -> Mapping[str, object]:
    data = session.token.to_dict()
    if session.workspace_id is not None:
        data["workspace_id"] = session.workspace_id
    if session.user_id is not None:
        data["user_id"] = session.user_id
    return data


def _ensure_list(value: Mapping[str, object] | list[Mapping[str, object]]) -> list[Mapping[str, object]]:
    if isinstance(value, list):
        return [dict(item) for item in value]
    if isinstance(value, Mapping):
        return [dict(value)]
    return []


def _browser_capture_plan() -> Dict[str, object]:
    return {
        "status": "token_required",
        "reason": "interactive_login_required",
        "flow": {
            "kind": "embedded_browser_capture",
            "steps": [
                {
                    "action": "open_webview",
                    "url": "https://slack.com/signin",
                    "note": "Use a trusted webview so we can intercept the RTM token exchange.",
                },
                {
                    "action": "monitor_websocket",
                    "note": "Once the workspace loads, capture the xoxs/xoxp token from the SlackStream websocket handshake.",
                    "references": [
                        "https://github.com/haringsrob/CollabApp",
                        "https://github.com/mazun/SlackStream",
                    ],
                },
                {
                    "action": "store_token",
                    "note": "Persist the captured token encrypted in the Msgr vault and pass it back via the session payload.",
                },
            ],
        },
    }
