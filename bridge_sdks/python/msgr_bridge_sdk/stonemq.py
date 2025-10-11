"""StoneMQ client skeleton for bridge daemons."""

from __future__ import annotations

import asyncio
import json
from typing import Awaitable, Callable, Dict, Optional, Protocol

from .envelope import Envelope
from .telemetry import TelemetryRecorder, NoopTelemetry
from .credentials import CredentialBootstrapper

QueueHandler = Callable[[Envelope], Awaitable[None]]


class QueueTransport(Protocol):
    async def subscribe(self, topic: str, handler: Callable[[bytes], Awaitable[None]]) -> None:
        ...

    async def publish(self, topic: str, body: bytes) -> None:
        ...


def topic_for(service: str, action: str) -> str:
    return f"bridge/{service}/{action}"


class StoneMQClient:
    """Coordinates queue subscriptions, telemetry and credential bootstrapping."""

    def __init__(
        self,
        service: str,
        transport: QueueTransport,
        *,
        telemetry: Optional[TelemetryRecorder] = None,
        credential_bootstrapper: Optional[CredentialBootstrapper] = None,
    ) -> None:
        if not service:
            raise ValueError("service must not be empty")
        self._service = service
        self._transport = transport
        self._telemetry = telemetry or NoopTelemetry()
        self._credential_bootstrapper = credential_bootstrapper
        self._handlers: Dict[str, QueueHandler] = {}

    def register(self, action: str, handler: QueueHandler) -> None:
        self._handlers[action] = handler

    async def start(self) -> None:
        if self._credential_bootstrapper is not None:
            await self._credential_bootstrapper.bootstrap(self._service)

        if not self._handlers:
            raise RuntimeError("no handlers registered")

        for action, handler in self._handlers.items():
            await self._transport.subscribe(topic_for(self._service, action), self._wrap(action, handler))

    async def publish(self, action: str, envelope: Envelope) -> None:
        await self._transport.publish(topic_for(self._service, action), envelope.to_json().encode("utf-8"))

    def _wrap(self, action: str, handler: QueueHandler) -> Callable[[bytes], Awaitable[None]]:
        async def _inner(body: bytes) -> None:
            loop = asyncio.get_running_loop()
            start = loop.time()
            outcome = "ok"
            try:
                envelope = Envelope.from_dict(json.loads(body.decode("utf-8")))
                await handler(envelope)
            except Exception:  # pylint: disable=broad-except
                outcome = "error"
                raise
            finally:
                self._telemetry.record_delivery(self._service, action, loop.time() - start, outcome)

        return _inner
