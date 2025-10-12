"""Signal bridge daemon wiring StoneMQ queue handlers to the client protocol."""

from __future__ import annotations

from typing import Awaitable, Callable, Dict, Mapping, Optional

from msgr_bridge_sdk import Envelope, StoneMQClient, build_envelope

from .client import SignalClientProtocol, decode_session_blob
from .session import SessionManager


class SignalBridgeDaemon:
    """Coordinates queue handlers and Signal client sessions."""

    def __init__(
        self,
        mq_client: StoneMQClient,
        sessions: SessionManager,
        *,
        default_user_id: Optional[str] = None,
    ) -> None:
        self._client = mq_client
        self._sessions = sessions
        self._default_user_id = default_user_id
        self._event_handlers: Dict[str, Callable[[Mapping[str, object]], Awaitable[None]]] = {}
        self._ack_state: Dict[str, Mapping[str, object]] = {}

        self._client.register("outbound_message", self._handle_outbound_message)
        self._client.register("ack_event", self._handle_ack_event)
        self._client.register_request("link_account", self._handle_link_account)

    async def start(self) -> None:
        await self._client.start()

    async def _handle_link_account(self, envelope: Envelope) -> Mapping[str, object]:
        payload = dict(envelope.payload)
        user_id = str(payload.get("user_id") or self._default_user_id or "default")

        session_info = payload.get("session") or {}
        if not isinstance(session_info, Mapping):
            raise ValueError("session payload must be a mapping")

        session_blob = session_info.get("blob")
        blob_bytes = (
            decode_session_blob(session_blob) if isinstance(session_blob, str) else None
        )

        client = await self._sessions.ensure_client(user_id, session_blob=blob_bytes)

        if await client.is_linked():
            profile = await client.get_profile()
            await self._register_event_handler(user_id, client)
            session_b64 = await self._sessions.export_session(user_id)
            response: Dict[str, object] = {
                "status": "linked",
                "user": profile.to_dict(),
            }
            if session_b64 is not None:
                response["session"] = {"blob": session_b64}
            return response

        linking = payload.get("linking") or {}
        device_name: Optional[str] = None
        if isinstance(linking, Mapping):
            maybe_name = linking.get("device_name")
            if isinstance(maybe_name, str) and maybe_name:
                device_name = maybe_name

        code = await client.request_linking_code(device_name=device_name)
        await self._sessions.remove_client(user_id)
        return {"status": "link_required", "linking": dict(code.to_dict())}

    async def _handle_outbound_message(self, envelope: Envelope) -> None:
        payload = envelope.payload
        metadata = envelope.metadata
        user_id = metadata.get("user_id", self._default_user_id)
        if user_id is None:
            raise RuntimeError("user_id metadata required for outbound messages")

        chat_id = str(payload["chat_id"])
        message = str(payload.get("message", ""))
        attachments = (
            payload.get("attachments")
            if isinstance(payload.get("attachments"), list)
            else None
        )
        extra_metadata = (
            payload.get("metadata") if isinstance(payload.get("metadata"), Mapping) else None
        )

        client = await self._sessions.ensure_client(str(user_id))
        await client.send_text_message(
            chat_id,
            message,
            attachments=attachments,  # type: ignore[arg-type]
            metadata=extra_metadata,
        )

    async def _handle_ack_event(self, envelope: Envelope) -> None:
        payload = envelope.payload
        metadata = envelope.metadata
        user_id = metadata.get("user_id", self._default_user_id)
        if user_id is None:
            return

        event_id = payload.get("event_id")
        if event_id is None:
            return

        try:
            client = self._sessions.get_client(str(user_id))
        except RuntimeError:
            return

        event_key = str(event_id)
        await client.acknowledge_event(event_key)
        self._ack_state[event_key] = dict(payload)

    async def _register_event_handler(
        self, user_id: str, client: SignalClientProtocol
    ) -> None:
        if user_id in self._event_handlers:
            return

        async def handler(event: Mapping[str, object]) -> None:
            event_id = event.get("event_id")
            if event_id is None:
                return

            payload = dict(event)
            payload.setdefault("user_id", user_id)
            envelope = build_envelope("signal", "inbound_event", payload)
            await self._client.publish("inbound_event", envelope)

        client.add_event_handler(handler)
        self._event_handlers[user_id] = handler

    async def shutdown(self) -> None:
        for user_id, handler in list(self._event_handlers.items()):
            try:
                client = self._sessions.get_client(user_id)
            except RuntimeError:
                continue
            client.remove_event_handler(handler)
            self._event_handlers.pop(user_id, None)
        await self._sessions.shutdown()

    @property
    def acked_events(self) -> Dict[str, Mapping[str, object]]:
        return dict(self._ack_state)
