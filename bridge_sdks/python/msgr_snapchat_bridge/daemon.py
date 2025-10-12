"""Queue-facing skeleton for the Snapchat bridge."""

from __future__ import annotations

from collections import defaultdict
from typing import Dict, List, Mapping, Optional

from msgr_bridge_sdk import Envelope, StoneMQClient

from .session import SessionManager


class SnapchatBridgeDaemon:
    """Captures queue traffic for Snapchat until a real client implementation lands."""

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
        self._recorded: Dict[str, List[Mapping[str, object]]] = defaultdict(list)

        self._client.register("outbound_message", self._handle_outbound_message)
        self._client.register("ack_event", self._handle_ack_event)
        self._client.register_request("link_account", self._handle_link_account)

    async def start(self) -> None:
        await self._client.start()

    async def shutdown(self) -> None:
        await self._sessions.shutdown()

    async def _handle_link_account(self, envelope: Envelope) -> Mapping[str, object]:
        self._recorded["link_account"].append(dict(envelope.payload))
        return {
            "status": "not_implemented",
            "reason": (
                "Snapchat bridge client is not implemented yet. Provide API bindings and "
                "credentials to enable account linking."
            ),
        }

    async def _handle_outbound_message(self, envelope: Envelope) -> None:
        self._recorded["outbound_message"].append(dict(envelope.payload))

    async def _handle_ack_event(self, envelope: Envelope) -> None:
        self._recorded["ack_event"].append(dict(envelope.payload))

    @property
    def recorded_invocations(self) -> Dict[str, List[Mapping[str, object]]]:
        return {action: list(payloads) for action, payloads in self._recorded.items()}
