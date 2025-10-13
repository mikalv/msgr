"""Teams bridge daemon wiring StoneMQ queue handlers to Microsoft Graph."""

from __future__ import annotations

import copy
import logging
from typing import Dict, Mapping, MutableMapping, Optional

from msgr_bridge_sdk import Envelope, StoneMQClient, build_envelope

from .client import TeamsClientProtocol, TeamsIdentity, TeamsOAuthClientProtocol, TeamsTenant, TeamsToken
from .session import SessionData, SessionManager

_DEFAULT_CAPABILITIES: Mapping[str, object] = {
    "messaging": {
        "text": True,
        "mentions": True,
        "attachments": ["file", "image"],
    },
    "presence": {"typing": True, "read_receipts": True},
    "threads": {"supported": True},
}


class TeamsBridgeDaemon:
    """Coordinates queue handlers and Teams client sessions."""

    def __init__(
        self,
        mq_client: StoneMQClient,
        sessions: SessionManager,
        *,
        default_user_id: Optional[str] = None,
        oauth: Optional[TeamsOAuthClientProtocol] = None,
        instance: Optional[str] = None,
    ) -> None:
        self._client = mq_client
        self._sessions = sessions
        self._default_user_id = default_user_id
        self._oauth = oauth
        self._instance = instance
        self._event_handlers: Dict[str, object] = {}
        self._ack_state: Dict[str, Mapping[str, object]] = {}
        self._logger = logging.getLogger(__name__)

        self._client.register("outbound_message", self._handle_outbound_message)
        self._client.register("ack_event", self._handle_ack_event)
        self._client.register_request("link_account", self._handle_link_account)
        self._client.register_request("health_snapshot", self._handle_health_snapshot)

    async def start(self) -> None:
        await self._client.start()

    async def shutdown(self) -> None:
        for key, handler in list(self._event_handlers.items()):
            tenant_id, user_id = key.split("::", 1)
            user_id = None if user_id == "user" else user_id
            try:
                client = self._sessions.get_client(tenant_id, user_id)
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

        tenant_payload = _extract_tenant(payload)
        tenant = _build_tenant(tenant_payload) if tenant_payload else None

        token = _extract_token(session_payload)

        if token is None and self._oauth is not None:
            oauth_payload = payload.get("authorization") or payload.get("oauth") or {}
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
                    tenant_payload = _extract_tenant(oauth_response) or tenant_payload
                    tenant = _build_tenant(tenant_payload) if tenant_payload else tenant

        if tenant is None:
            raise ValueError("tenant metadata is required to link Teams")

        if token is None:
            plan = _browser_consent_plan(tenant)
            plan.setdefault("status", "consent_required")
            return plan

        client, session = await self._sessions.ensure_client(
            tenant,
            token=token,
            user_id=user_id,
        )

        identity = await client.fetch_identity()
        session = await self._synchronise_session(identity, session, user_id)

        await self._register_event_handler(identity, client, user_id)

        capabilities = await client.describe_capabilities()
        members = await client.list_members()
        conversations = await client.list_conversations()

        return self._build_linked_response(identity, session, capabilities, members, conversations)

    async def _handle_outbound_message(self, envelope: Envelope) -> None:
        metadata = envelope.metadata
        payload = envelope.payload
        user_id = metadata.get("user_id", self._default_user_id)
        tenant_id = metadata.get("tenant_id") or metadata.get("instance") or self._instance
        if user_id is None or tenant_id is None:
            raise RuntimeError("tenant_id and user_id metadata required for outbound Teams messages")

        session = self._sessions.get_session(str(tenant_id), str(user_id))
        if session is None:
            session = await self._sessions.export_session(str(tenant_id), str(user_id))
        if session is None:
            raise RuntimeError("no session available for outbound Teams message")

        client, _ = await self._sessions.ensure_client(session.tenant, user_id=str(user_id), session=session)

        conversation_id = str(
            payload.get("conversation_id")
            or payload.get("chat_id")
            or payload.get("channel_id")
        )

        message_body = payload.get("message")
        if isinstance(message_body, str):
            message_body = {"body": {"contentType": "text", "content": message_body}}
        elif not isinstance(message_body, Mapping):
            raise ValueError("message payload must be a string or mapping")

        reply_to = payload.get("reply_to") or payload.get("reply_to_id")
        metadata_payload = payload.get("metadata") if isinstance(payload.get("metadata"), Mapping) else None

        await client.send_message(
            conversation_id,
            message_body,  # type: ignore[arg-type]
            reply_to_id=str(reply_to) if isinstance(reply_to, str) else None,
            metadata=metadata_payload,
        )

    async def _handle_ack_event(self, envelope: Envelope) -> None:
        metadata = envelope.metadata
        payload = envelope.payload
        tenant_id = metadata.get("tenant_id") or metadata.get("instance") or self._instance
        user_id = metadata.get("user_id", self._default_user_id)
        event_id = payload.get("event_id")
        if tenant_id is None or user_id is None or event_id is None:
            return

        try:
            client = self._sessions.get_client(str(tenant_id), str(user_id))
        except RuntimeError:
            return

        await client.acknowledge_event(str(event_id))
        self._ack_state[str(event_id)] = dict(payload)

    async def _handle_health_snapshot(self, envelope: Envelope) -> Mapping[str, object]:
        payload = envelope.payload
        filter_tenant = payload.get("tenant_id") or payload.get("instance")
        filter_user = payload.get("user_id")

        entries: list[Mapping[str, object]] = []
        connected = 0
        pending_events = 0

        for tenant_id, user_id, client, session in self._sessions.active_entries():
            if filter_tenant is not None and str(filter_tenant) != tenant_id:
                continue
            if filter_user and str(filter_user) != (user_id or ""):
                continue

            try:
                runtime = await client.health()
            except Exception:  # pragma: no cover - defensive logging for ops
                self._logger.exception(
                    "Teams health snapshot failed",
                    extra={"tenant_id": tenant_id, "user_id": user_id},
                )
                runtime = {"status": "error"}

            client_connected = bool(runtime.get("connected"))
            if client_connected:
                connected += 1

            client_pending = _coerce_int(runtime.get("pending_events"))
            pending_events += client_pending

            entry: Dict[str, object] = {
                "tenant_id": tenant_id,
                "user_id": user_id,
                "connected": client_connected,
                "pending_events": client_pending,
                "runtime": dict(runtime),
            }
            session_payload = session.to_dict() if session is not None else None
            if session_payload is not None:
                entry["session"] = session_payload

            entries.append(_compact_snapshot(entry))

        acked_events = [dict(value) for value in self._ack_state.values()]
        summary = {
            "total_clients": len(entries),
            "connected_clients": connected,
            "pending_events": pending_events,
            "acked_events": len(acked_events),
        }

        return {
            "status": "ok",
            "summary": summary,
            "clients": entries,
            "acked_events": acked_events,
        }

    async def _register_event_handler(
        self,
        identity: TeamsIdentity,
        client: TeamsClientProtocol,
        user_id: str,
    ) -> None:
        key = f"{identity.tenant.id}::{user_id or 'user'}"
        if key in self._event_handlers:
            return

        async def handler(event: Mapping[str, object]) -> None:
            payload: MutableMapping[str, object] = dict(event)
            payload.setdefault("tenant_id", identity.tenant.id)
            payload.setdefault("user_id", user_id)
            envelope = build_envelope("teams", "inbound_event", payload)
            await self._client.publish("inbound_event", envelope, instance=identity.tenant.id)

        client.add_event_handler(handler)
        self._event_handlers[key] = handler

    async def _synchronise_session(
        self,
        identity: TeamsIdentity,
        session: SessionData,
        user_id: str,
    ) -> SessionData:
        enriched = SessionData(tenant=identity.tenant, token=session.token, user_id=user_id)
        await self._sessions.ensure_client(identity.tenant, user_id=user_id, session=enriched)
        return enriched

    def _build_linked_response(
        self,
        identity: TeamsIdentity,
        session: SessionData,
        capabilities: Mapping[str, object],
        members: Mapping[str, object] | list[Mapping[str, object]],
        conversations: Mapping[str, object] | list[Mapping[str, object]],
    ) -> Mapping[str, object]:
        response: Dict[str, object] = {
            "status": "linked",
            "tenant": identity.tenant.to_dict(),
            "user": identity.user.to_dict(),
            "session": _session_payload(session),
            "capabilities": copy.deepcopy(_DEFAULT_CAPABILITIES),
            "members": _ensure_list(members),
            "conversations": _ensure_list(conversations),
        }
        response["capabilities"].update(copy.deepcopy(capabilities))
        return response


def _extract_token(payload: Mapping[str, object]) -> Optional[TeamsToken]:
    if isinstance(payload, Mapping):
        token_map = payload.get("token") if isinstance(payload.get("token"), Mapping) else payload
        access_token = token_map.get("access_token") if isinstance(token_map, Mapping) else None
        refresh_token = token_map.get("refresh_token") if isinstance(token_map, Mapping) else None
        expires_at = token_map.get("expires_at") if isinstance(token_map, Mapping) else None
        token_type = token_map.get("token_type") if isinstance(token_map, Mapping) else None
        if isinstance(access_token, str) and access_token:
            return TeamsToken(
                access_token=access_token,
                refresh_token=str(refresh_token) if isinstance(refresh_token, str) else None,
                expires_at=float(expires_at) if isinstance(expires_at, (int, float)) else None,
                token_type=str(token_type) if isinstance(token_type, str) else "Bearer",
            )
        if isinstance(payload.get("access_token"), str):
            return TeamsToken(access_token=str(payload["access_token"]))
    elif isinstance(payload, TeamsToken):
        return payload
    elif isinstance(payload, str) and payload:
        return TeamsToken(access_token=payload)
    return None


def _extract_tenant(payload: Mapping[str, object]) -> Optional[Mapping[str, object]]:
    if not isinstance(payload, Mapping):
        return None
    tenant = payload.get("tenant") or payload.get("organization") or payload.get("tenant_info")
    if isinstance(tenant, Mapping):
        return tenant
    return None


def _build_tenant(payload: Mapping[str, object]) -> TeamsTenant:
    return TeamsTenant(
        id=str(payload.get("id") or payload.get("tenant_id")),
        display_name=str(payload.get("display_name")) if payload.get("display_name") else None,
        domain=str(payload.get("domain")) if payload.get("domain") else None,
    )


def _session_payload(session: SessionData) -> Mapping[str, object]:
    data = session.token.to_dict()
    data["tenant_id"] = session.tenant.id
    if session.user_id is not None:
        data["user_id"] = session.user_id
    return data


def _ensure_list(value: Mapping[str, object] | list[Mapping[str, object]]) -> list[Mapping[str, object]]:
    if isinstance(value, list):
        return [dict(item) for item in value]
    if isinstance(value, Mapping):
        return [dict(value)]
    return []


def _coerce_int(value: object) -> int:
    if isinstance(value, (int, float)):
        return int(value)
    return 0


def _compact_snapshot(values: Mapping[str, object | None]) -> Dict[str, object]:
    return {key: value for key, value in values.items() if value is not None}


def _browser_consent_plan(tenant: TeamsTenant) -> Dict[str, object]:
    return {
        "status": "consent_required",
        "reason": "interactive_consent_required",
        "flow": {
            "kind": "embedded_browser_consent",
            "tenant": tenant.to_dict(),
            "steps": [
                {
                    "action": "open_webview",
                    "url": "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
                    "note": "Initiate the Microsoft identity platform authorization code flow for Teams scopes.",
                },
                {
                    "action": "capture_redirect",
                    "note": "Intercept the redirect URI inside the webview and extract the authorization code.",
                },
                {
                    "action": "exchange_code",
                    "note": "Use the captured code with the Teams bridge backend to obtain access/refresh tokens via Microsoft Graph.",
                },
            ],
        },
    }
