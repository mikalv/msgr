import asyncio
import json
from pathlib import Path
from typing import Awaitable, Callable, Dict

import pytest

from msgr_bridge_sdk import StoneMQClient, build_envelope
from msgr_snapchat_bridge import (
    SessionManager,
    SessionStore,
    SnapchatBridgeDaemon,
    SnapchatClientStub,
)
from msgr_snapchat_bridge.client import SnapchatBridgeNotImplementedError


class MemoryTransport:
    def __init__(self) -> None:
        self.subscriptions: Dict[str, Callable[[bytes], Awaitable[None]]] = {}
        self.request_handlers: Dict[str, Callable[[bytes], Awaitable[bytes]]] = {}
        self.published: Dict[str, bytes] = {}

    async def subscribe(self, topic: str, handler: Callable[[bytes], Awaitable[None]]) -> None:
        self.subscriptions[topic] = handler

    async def publish(self, topic: str, body: bytes) -> None:
        self.published[topic] = body
        handler = self.subscriptions.get(topic)
        if handler is not None:
            await handler(body)

    async def subscribe_request(self, topic: str, handler: Callable[[bytes], Awaitable[bytes]]) -> None:
        self.request_handlers[topic] = handler

    async def request(self, topic: str, body: bytes) -> bytes:
        handler = self.request_handlers[topic]
        return await handler(body)


def _run(async_fn: Callable[[], Awaitable[None]]) -> None:
    asyncio.run(async_fn())


def _build_daemon(tmp_path: Path) -> tuple[SnapchatBridgeDaemon, MemoryTransport]:
    transport = MemoryTransport()
    client = StoneMQClient("snapchat", transport)
    store = SessionStore(tmp_path / "snap_sessions")
    sessions = SessionManager(store, lambda _: SnapchatClientStub())
    daemon = SnapchatBridgeDaemon(client, sessions, default_user_id="42")
    return daemon, transport


def test_snapchat_daemon_records_invocations(tmp_path: Path) -> None:
    daemon, transport = _build_daemon(tmp_path)

    async def scenario() -> None:
        await daemon.start()
        request = build_envelope(
            "snapchat",
            "link_account",
            {"user_id": "42"},
        )
        topic = "bridge/snapchat/link_account"
        response_raw = await transport.request(topic, request.to_json().encode("utf-8"))
        response = json.loads(response_raw.decode("utf-8"))
        assert response["status"] == "not_implemented"

        outbound = build_envelope(
            "snapchat",
            "outbound_message",
            {"conversation_id": "conv-1", "message": "hei"},
        )
        await transport.publish("bridge/snapchat/outbound_message", outbound.to_json().encode("utf-8"))

        ack = build_envelope(
            "snapchat",
            "ack_event",
            {"event_id": "evt-1"},
        )
        await transport.publish("bridge/snapchat/ack_event", ack.to_json().encode("utf-8"))

        recorded = daemon.recorded_invocations
        assert recorded["outbound_message"][0]["message"] == "hei"
        assert recorded["ack_event"][0]["event_id"] == "evt-1"

        await daemon.shutdown()

    _run(scenario)


def test_snapchat_client_stub_raises(tmp_path: Path) -> None:
    client = SnapchatClientStub()

    async def scenario() -> None:
        with pytest.raises(SnapchatBridgeNotImplementedError):
            await client.connect()

    _run(scenario)
