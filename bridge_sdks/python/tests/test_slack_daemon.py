from __future__ import annotations

import asyncio
import copy
import json
from pathlib import Path
from typing import Awaitable, Callable, Dict, Mapping, Optional

from msgr_bridge_sdk import StoneMQClient, build_envelope
from msgr_slack_bridge import SessionManager, SessionStore, SlackBridgeDaemon
from msgr_slack_bridge.client import SlackIdentity, SlackToken, SlackUser, SlackWorkspace


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


class FakeSlackClient:
    def __init__(self) -> None:
        self.connected = False
        self.token: Optional[SlackToken] = None
        workspace = SlackWorkspace(id="T999", name="Acme", domain="acme")
        user = SlackUser(id="U123", real_name="Alice Example", display_name="alice")
        self.identity = SlackIdentity(workspace=workspace, user=user)
        self.capabilities: Mapping[str, object] = {
            "messaging": {"text": True, "threads": True},
            "presence": {"typing": True},
        }
        self.members: list[Mapping[str, object]] = [
            {"id": "U123", "real_name": "Alice Example"},
            {"id": "U456", "real_name": "Bob Builder"},
        ]
        self.channels: list[Mapping[str, object]] = [
            {"id": "C1", "name": "general"},
        ]
        self.sent_messages: list[Mapping[str, object]] = []
        self.handlers: list[Callable[[Mapping[str, object]], Awaitable[None]]] = []
        self.acked: list[str] = []
        self.pending_events = 0
        self.health_calls = 0

    async def connect(self, token: SlackToken) -> None:
        self.connected = True
        self.token = token

    async def disconnect(self) -> None:
        self.connected = False

    async def is_connected(self) -> bool:
        return self.connected

    async def fetch_identity(self) -> SlackIdentity:
        return self.identity

    async def describe_capabilities(self) -> Mapping[str, object]:
        return copy.deepcopy(self.capabilities)

    async def list_members(self) -> list[Mapping[str, object]]:
        return copy.deepcopy(self.members)

    async def list_conversations(self) -> list[Mapping[str, object]]:
        return copy.deepcopy(self.channels)

    async def post_message(
        self,
        channel: str,
        text: str,
        *,
        blocks: Optional[list[Mapping[str, object]]] = None,
        attachments: Optional[list[Mapping[str, object]]] = None,
        thread_ts: Optional[str] = None,
        reply_broadcast: bool = False,
        metadata: Optional[Mapping[str, object]] = None,
    ) -> Mapping[str, object]:
        payload = {
            "channel": channel,
            "text": text,
            "blocks": blocks,
            "attachments": attachments,
            "thread_ts": thread_ts,
            "reply_broadcast": reply_broadcast,
            "metadata": metadata,
        }
        self.sent_messages.append(payload)
        return {"ok": True, "channel": channel}

    async def acknowledge_event(self, event_id: str) -> None:
        self.acked.append(event_id)
        if self.pending_events > 0:
            self.pending_events -= 1

    def add_event_handler(self, handler: Callable[[Mapping[str, object]], Awaitable[None]]) -> None:
        self.handlers.append(handler)

    def remove_event_handler(self, handler: Callable[[Mapping[str, object]], Awaitable[None]]) -> None:
        if handler in self.handlers:
            self.handlers.remove(handler)

    async def dispatch_event(self, event: Mapping[str, object]) -> None:
        for handler in list(self.handlers):
            await handler(event)
        self.pending_events += 1

    async def health(self) -> Mapping[str, object]:
        self.health_calls += 1
        return {
            "connected": self.connected,
            "pending_events": self.pending_events,
            "last_event_id": self.acked[-1] if self.acked else None,
        }


class FakeClientFactory:
    def __init__(self, client: FakeSlackClient) -> None:
        self._client = client

    def create(self, _instance: Optional[str]) -> FakeSlackClient:
        return self._client


def _build_daemon(tmp_path: Path, client: FakeSlackClient) -> tuple[SlackBridgeDaemon, MemoryTransport]:
    transport = MemoryTransport()
    queue_client = StoneMQClient("slack", transport, instance="T999")
    store = SessionStore(tmp_path / "slack_sessions")
    factory = FakeClientFactory(client)
    sessions = SessionManager(store, factory.create)
    daemon = SlackBridgeDaemon(queue_client, sessions, default_user_id="acct-1", instance="T999")
    return daemon, transport


def _run(async_fn: Callable[[], Awaitable[None]]) -> None:
    asyncio.run(async_fn())


async def _link_account(daemon: SlackBridgeDaemon, transport: MemoryTransport) -> Mapping[str, object]:
    await daemon.start()
    envelope = build_envelope(
        "slack",
        "link_account",
        {
            "user_id": "acct-1",
            "session": {"token": "xoxs-token"},
            "workspace": {"id": "T999", "name": "Acme"},
        },
    )
    topic = "bridge/slack/T999/link_account"
    response_raw = await transport.request(topic, envelope.to_json().encode("utf-8"))
    return json.loads(response_raw.decode("utf-8"))


def test_link_account_returns_workspace_snapshot(tmp_path: Path) -> None:
    client = FakeSlackClient()
    daemon, transport = _build_daemon(tmp_path, client)

    async def scenario() -> None:
        response = await _link_account(daemon, transport)
        assert response["status"] == "linked"
        assert response["workspace"]["id"] == "T999"
        assert response["user"]["id"] == "U123"
        assert response["session"]["token"] == "xoxs-token"
        assert response["capabilities"]["messaging"]["threads"] is True
        assert response["members"][1]["real_name"] == "Bob Builder"

        await client.dispatch_event({"event_id": "evt-1", "channel": "C1", "text": "hei"})
        topic = "bridge/slack/T999/inbound_event"
        assert topic in transport.published
        envelope = json.loads(transport.published[topic].decode("utf-8"))
        assert envelope["payload"]["channel"] == "C1"
        assert envelope["payload"]["workspace_id"] == "T999"

        await daemon.shutdown()

    _run(scenario)


def test_link_account_without_token_requests_browser_plan(tmp_path: Path) -> None:
    client = FakeSlackClient()
    daemon, transport = _build_daemon(tmp_path, client)

    async def scenario() -> None:
        await daemon.start()
        envelope = build_envelope(
            "slack",
            "link_account",
            {"user_id": "acct-1", "session": {}},
        )
        topic = "bridge/slack/T999/link_account"
        response_raw = await transport.request(topic, envelope.to_json().encode("utf-8"))
        response = json.loads(response_raw.decode("utf-8"))

        assert response["status"] == "token_required"
        assert response["flow"]["kind"] == "embedded_browser_capture"

        await daemon.shutdown()

    _run(scenario)


def test_outbound_message_dispatch(tmp_path: Path) -> None:
    client = FakeSlackClient()
    daemon, transport = _build_daemon(tmp_path, client)

    async def scenario() -> None:
        await _link_account(daemon, transport)
        envelope = build_envelope(
            "slack",
            "outbound_message",
            {
                "channel": "C1",
                "text": "Hello",
            },
            metadata={"user_id": "acct-1", "instance": "T999"},
        )
        topic = "bridge/slack/T999/outbound_message"
        await transport.publish(topic, envelope.to_json().encode("utf-8"))

        assert client.sent_messages[0]["text"] == "Hello"
        await daemon.shutdown()

    _run(scenario)


def test_ack_event_invokes_client(tmp_path: Path) -> None:
    client = FakeSlackClient()
    daemon, transport = _build_daemon(tmp_path, client)

    async def scenario() -> None:
        await _link_account(daemon, transport)
        envelope = build_envelope(
            "slack",
            "ack_event",
            {"event_id": "evt-1"},
            metadata={"user_id": "acct-1", "instance": "T999"},
        )
        topic = "bridge/slack/T999/ack_event"
        await transport.publish(topic, envelope.to_json().encode("utf-8"))

        assert client.acked == ["evt-1"]
        await daemon.shutdown()

    _run(scenario)


def test_health_snapshot_reports_runtime_state(tmp_path: Path) -> None:
    client = FakeSlackClient()
    daemon, transport = _build_daemon(tmp_path, client)

    async def scenario() -> None:
        await _link_account(daemon, transport)

        ack_envelope = build_envelope(
            "slack",
            "ack_event",
            {"event_id": "evt-2", "status": "accepted"},
            metadata={"user_id": "acct-1", "instance": "T999"},
        )
        await transport.publish("bridge/slack/T999/ack_event", ack_envelope.to_json().encode("utf-8"))
        client.pending_events = 3

        health_envelope = build_envelope("slack", "health_snapshot", {"instance": "T999"})
        response_raw = await transport.request(
            "bridge/slack/T999/health_snapshot",
            health_envelope.to_json().encode("utf-8"),
        )
        snapshot = json.loads(response_raw.decode("utf-8"))

        assert snapshot["summary"]["total_clients"] == 1
        assert snapshot["summary"]["pending_events"] == 3
        assert snapshot["summary"]["acked_events"] == 1
        assert snapshot["clients"][0]["instance"] == "T999"
        assert snapshot["clients"][0]["pending_events"] == 3

        await daemon.shutdown()

    _run(scenario)
