"""StoneMQ-backed logging helpers for OpenObserve ingestion."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Mapping, MutableMapping, Optional, Protocol

from .envelope import build_envelope


class LogQueueTransport(Protocol):
    async def publish(self, topic: str, body: bytes) -> None:  # pragma: no cover - Protocol definition
        """Publish raw bytes to the StoneMQ topic."""


class OpenObserveLogger:
    """Emit structured log entries to StoneMQ for downstream OpenObserve ingestion."""

    def __init__(
        self,
        transport: LogQueueTransport,
        *,
        service: str = "bridge_daemon",
        stream: str = "daemon",
        topic: str = "observability/logs",
        envelope_service: str = "observability",
        envelope_action: str = "log",
        clock: Optional[callable] = None,
    ) -> None:
        if transport is None:  # pragma: no cover - guard clause
            raise ValueError("transport must not be None")
        if not service:
            raise ValueError("service must not be empty")
        if not stream:
            raise ValueError("stream must not be empty")
        if not topic:
            raise ValueError("topic must not be empty")
        if not envelope_service:
            raise ValueError("envelope_service must not be empty")
        if not envelope_action:
            raise ValueError("envelope_action must not be empty")

        self._transport = transport
        self._service = service
        self._stream = stream
        self._topic = topic
        self._envelope_service = envelope_service
        self._envelope_action = envelope_action
        self._clock = clock or (lambda: datetime.now(tz=timezone.utc))

    async def log(self, level: str, message: str, metadata: Optional[Mapping[str, Any]] = None) -> None:
        if not level:
            raise ValueError("level must not be empty")

        occurred = self._clock().astimezone(timezone.utc)
        occurred = occurred.replace(microsecond=(occurred.microsecond // 1000) * 1000)

        entry: MutableMapping[str, Any] = {
            "level": level,
            "message": message,
            "service": self._service,
            "timestamp": occurred.isoformat(),
        }

        if metadata:
            entry["metadata"] = dict(metadata)

        envelope = build_envelope(
            self._envelope_service,
            self._envelope_action,
            {"entry": entry},
            metadata={
                "destination": "openobserve",
                "stream": self._stream,
                "service": self._service,
            },
            occurred_at=occurred,
        )

        await self._transport.publish(self._topic, envelope.to_json().encode("utf-8"))
