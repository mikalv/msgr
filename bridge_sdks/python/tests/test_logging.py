from __future__ import annotations

import asyncio
from datetime import datetime, timezone

import pytest

from msgr_bridge_sdk.logging import OpenObserveLogger
from msgr_bridge_sdk.envelope import Envelope


class CaptureTransport:
    def __init__(self) -> None:
        self.published: list[tuple[str, bytes]] = []

    async def publish(self, topic: str, body: bytes) -> None:
        self.published.append((topic, body))


def test_logger_publishes_envelope() -> None:
    transport = CaptureTransport()
    clock = lambda: datetime(2024, 1, 1, 12, 0, 0, tzinfo=timezone.utc)
    logger = OpenObserveLogger(transport, service="discord", clock=clock)

    asyncio.run(logger.log("info", "booted", {"module": "sync"}))

    assert transport.published
    topic, body = transport.published[0]
    assert topic == "observability/logs"

    envelope = Envelope.from_json(body.decode("utf-8"))
    assert envelope.service == "observability"
    assert envelope.action == "log"
    assert envelope.metadata["destination"] == "openobserve"

    entry = envelope.payload["entry"]
    assert entry["message"] == "booted"
    assert entry["service"] == "discord"
    assert entry["metadata"]["module"] == "sync"


def test_logger_validates_level() -> None:
    logger = OpenObserveLogger(CaptureTransport())
    with pytest.raises(ValueError):
        asyncio.run(logger.log("", "message"))
