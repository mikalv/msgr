"""Matrix bridge daemon wiring StoneMQ handlers to Matrix clients."""

from __future__ import annotations

from typing import Awaitable, Callable, Dict, Mapping, Optional, Tuple

from msgr_bridge_sdk import Envelope, StoneMQClient, build_envelope

from .client import (
    AuthenticationError,
    MatrixClientProtocol,
    MatrixEvent,
    MatrixSession,
    SessionRevokedError,
)
from .session import MatrixSessionManager


class MatrixBridgeDaemon:
    """Coordinates queue handlers and Matrix client sessions."""

    def __init__(
        self,
        mq_client: StoneMQClient,
        sessions: MatrixSessionManager,
        *,
        default_user_id: Optional[str] = None,
        default_homeserver: Optional[str] = None,
    ) -> None:
        self._client = mq_client
        self._sessions = sessions
        self._default_user_id = default_user_id
        self._default_homeserver = default_homeserver
        self._update_handlers: Dict[Tuple[str, str], Callable[[MatrixEvent], Awaitable[None]]] = {}
        self._ack_state: Dict[str, Mapping[str, object]] = {}

        self._client.register("outbound_message", self._handle_outbound_message)
        self._client.register("ack_update", self._handle_ack_update)
        self._client.register_request("link_account", self._handle_link_account)

    async def start(self) -> None:
        await self._client.start()

    async def _handle_link_account(self, envelope: Envelope) -> Mapping[str, object]:
        payload = dict(envelope.payload)
        metadata = envelope.metadata
        user_id = str(
            payload.get("user_id")
            or metadata.get("user_id")
            or self._default_user_id
            or "default"
        )
        homeserver = str(
            payload.get("homeserver")
            or metadata.get("homeserver")
            or self._default_homeserver
            or ""
        )
        if not homeserver:
            raise ValueError("homeserver is required to link a Matrix account")

        session_info = payload.get("session")
        session = self._parse_session(session_info, homeserver)

        credentials = payload.get("credentials") or {}
        if not isinstance(credentials, Mapping):
            raise ValueError("credentials must be a mapping")

        access_token = None
        username = None
        password = None

        if session is not None:
            access_token = session.access_token
            username = session.user_id
        else:
            access_token = self._extract_str(credentials.get("access_token"))
            username = self._extract_str(credentials.get("username"))

        if password is None:
            password = self._extract_str(credentials.get("password"))

        client = await self._sessions.ensure_client(user_id, homeserver, session=session)

        try:
            session_state = await client.ensure_logged_in(
                access_token=access_token,
                username=username,
                password=password,
            )
        except AuthenticationError as exc:
            await self._sessions.remove_client(user_id, homeserver)
            return {"status": "auth_failed", "reason": str(exc)}

        await self._sessions.persist_session(user_id, homeserver, session_state)
        profile = await client.get_profile()
        await self._register_update_handler(user_id, homeserver, client)

        response: Dict[str, object] = {
            "status": "linked",
            "user": dict(profile.to_dict()),
            "session": dict(session_state.to_dict()),
            "homeserver": homeserver,
        }
        return response

    async def _handle_outbound_message(self, envelope: Envelope) -> None:
        payload = envelope.payload
        metadata = envelope.metadata
        user_id = metadata.get("user_id") or payload.get("user_id") or self._default_user_id
        homeserver = (
            metadata.get("homeserver")
            or payload.get("homeserver")
            or self._default_homeserver
        )
        if user_id is None or homeserver is None:
            raise RuntimeError("user_id and homeserver metadata are required")

        room_id = str(payload["room_id"])
        message = str(payload.get("message", ""))
        txn_id = payload.get("txn_id")

        client = self._sessions.get_client(str(user_id), str(homeserver))
        try:
            await client.send_text(room_id, message, txn_id=str(txn_id) if txn_id is not None else None)
        except SessionRevokedError:
            await self._sessions.remove_client(str(user_id), str(homeserver))
            raise

    async def _handle_ack_update(self, envelope: Envelope) -> None:
        payload = envelope.payload
        metadata = envelope.metadata
        user_id = metadata.get("user_id") or payload.get("user_id") or self._default_user_id
        homeserver = (
            metadata.get("homeserver")
            or payload.get("homeserver")
            or self._default_homeserver
        )
        if user_id is None or homeserver is None:
            return

        event_id = payload.get("event_id")
        if not isinstance(event_id, str):
            return

        try:
            client = self._sessions.get_client(str(user_id), str(homeserver))
        except RuntimeError:
            return

        await client.acknowledge(event_id)
        self._ack_state[event_id] = dict(payload)

    async def _register_update_handler(
        self,
        user_id: str,
        homeserver: str,
        client: MatrixClientProtocol,
    ) -> None:
        key = (homeserver, user_id)
        if key in self._update_handlers:
            return

        async def handler(event: MatrixEvent) -> None:
            payload = event.to_payload()
            payload.setdefault("user_id", user_id)
            payload.setdefault("homeserver", homeserver)
            envelope = build_envelope("matrix", "inbound_event", payload)
            await self._client.publish("inbound_event", envelope)

        client.add_update_handler(handler)
        self._update_handlers[key] = handler

    async def shutdown(self) -> None:
        for (homeserver, user_id), handler in list(self._update_handlers.items()):
            try:
                client = self._sessions.get_client(user_id, homeserver)
            except RuntimeError:
                continue
            client.remove_update_handler(handler)
            await self._sessions.remove_client(user_id, homeserver)
            self._update_handlers.pop((homeserver, user_id), None)
        await self._sessions.shutdown()

    @property
    def acked_updates(self) -> Dict[str, Mapping[str, object]]:
        return dict(self._ack_state)

    def _parse_session(
        self, session_info: object, homeserver: str
    ) -> Optional[MatrixSession]:
        if not isinstance(session_info, Mapping):
            return None
        data = dict(session_info)
        data.setdefault("homeserver", homeserver)
        try:
            return MatrixSession.from_mapping(data)
        except ValueError:
            return None

    @staticmethod
    def _extract_str(value: object) -> Optional[str]:
        if value is None:
            return None
        return str(value)
