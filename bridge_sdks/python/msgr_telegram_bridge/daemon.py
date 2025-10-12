"""Telegram bridge daemon wiring StoneMQ queue handlers to MTProto."""

from __future__ import annotations

from typing import Awaitable, Callable, Dict, Mapping, Optional

from msgr_bridge_sdk import Envelope, StoneMQClient, build_envelope

from .client import (
    PasswordRequiredError,
    SignInError,
    TelegramClientProtocol,
    decode_session_blob,
)
from .session import SessionManager


class TelegramBridgeDaemon:
    """Coordinates queue handlers and Telegram client sessions."""

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
        self._update_handlers: Dict[str, Callable[[Mapping[str, object]], Awaitable[None]]] = {}
        self._ack_state: Dict[int, Mapping[str, object]] = {}

        self._client.register("outbound_message", self._handle_outbound_message)
        self._client.register("ack_update", self._handle_ack_update)
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
        blob_bytes = decode_session_blob(session_blob) if isinstance(session_blob, str) else None

        client = await self._sessions.ensure_client(user_id, session_blob=blob_bytes)

        if await client.is_authorized():
            profile = await client.get_me()
            await self._register_update_handler(user_id, client)
            session_b64 = await self._sessions.export_session(user_id)
            response: Dict[str, object] = {
                "status": "linked",
                "user": profile.to_dict(),
            }
            if session_b64 is not None:
                response["session"] = {"blob": session_b64}
            return response

        phone_number = payload.get("phone_number")
        if not isinstance(phone_number, str) or not phone_number:
            await self._sessions.remove_client(user_id)
            raise ValueError("phone_number is required when no session is available")

        code = session_info.get("code")
        two_factor = payload.get("two_factor") or {}
        password = None
        if isinstance(two_factor, Mapping):
            password = two_factor.get("password")

        if code is None:
            sent_code = await client.send_login_code(phone_number)
            await self._sessions.remove_client(user_id)
            return {
                "status": "code_required",
                "phone_code_hash": sent_code.phone_code_hash,
            }

        try:
            profile = await client.sign_in(phone_number, str(code), password=password if isinstance(password, str) else None)
        except PasswordRequiredError as exc:
            await self._sessions.remove_client(user_id)
            return {
                "status": "password_required",
                "phone_code_hash": exc.phone_code_hash,
            }
        except SignInError as exc:
            await self._sessions.remove_client(user_id)
            return {
                "status": "code_invalid",
                "reason": str(exc),
            }

        await self._register_update_handler(user_id, client)
        session_b64 = await self._sessions.export_session(user_id)
        response = {
            "status": "linked",
            "user": profile.to_dict(),
        }
        if session_b64 is not None:
            response["session"] = {"blob": session_b64}
        return response

    async def _handle_outbound_message(self, envelope: Envelope) -> None:
        payload = envelope.payload
        metadata = envelope.metadata
        user_id = metadata.get("user_id", self._default_user_id)
        if user_id is None:
            raise RuntimeError("user_id metadata required for outbound messages")

        chat_id = int(payload["chat_id"])
        message = str(payload.get("message", ""))
        entities = payload.get("entities")
        reply_to = payload.get("reply_to")
        media = payload.get("media")

        client = await self._sessions.ensure_client(str(user_id))
        await client.send_text_message(
            chat_id,
            message,
            entities=entities,
            reply_to=reply_to,
            media=media,
        )

    async def _handle_ack_update(self, envelope: Envelope) -> None:
        payload = envelope.payload
        metadata = envelope.metadata
        user_id = metadata.get("user_id", self._default_user_id)
        if user_id is None:
            return

        update_id = payload.get("update_id")
        if update_id is None:
            return

        try:
            client = self._sessions.get_client(str(user_id))
        except RuntimeError:
            return

        await client.acknowledge_update(int(update_id))
        self._ack_state[int(update_id)] = dict(payload)

    async def _register_update_handler(
        self, user_id: str, client: TelegramClientProtocol
    ) -> None:
        if user_id in self._update_handlers:
            return

        async def handler(update: Mapping[str, object]) -> None:
            update_id = update.get("update_id")
            if update_id is None:
                return

            payload = dict(update)
            payload.setdefault("user_id", user_id)
            envelope = build_envelope("telegram", "inbound_update", payload)
            await self._client.publish("inbound_update", envelope)

        client.add_update_handler(handler)
        self._update_handlers[user_id] = handler

    async def shutdown(self) -> None:
        for user_id, handler in list(self._update_handlers.items()):
            try:
                client = self._sessions.get_client(user_id)
            except RuntimeError:
                continue
            client.remove_update_handler(handler)
            self._update_handlers.pop(user_id, None)
        await self._sessions.shutdown()

    @property
    def acked_updates(self) -> Dict[int, Mapping[str, object]]:
        return dict(self._ack_state)
