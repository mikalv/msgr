import asyncio
from typing import Awaitable, Callable, Dict

from msgr_bridge_sdk import (
    Envelope,
    EnvCredentialBootstrapper,
    NoopTelemetry,
    StoneMQClient,
    build_envelope,
    topic_for,
)


class MemoryTransport:
    def __init__(self) -> None:
        self.subscriptions: Dict[str, Callable[[bytes], Awaitable[None]]] = {}
        self.published: Dict[str, bytes] = {}

    async def subscribe(self, topic: str, handler: Callable[[bytes], Awaitable[None]]) -> None:
        self.subscriptions[topic] = handler

    async def publish(self, topic: str, body: bytes) -> None:
        self.published[topic] = body
        handler = self.subscriptions.get(topic)
        if handler is not None:
            await handler(body)


class RecordingTelemetry(NoopTelemetry):
    def __init__(self) -> None:
        self.records: list[tuple[str, str, str]] = []

    def record_delivery(self, service: str, action: str, duration: float, outcome: str) -> None:
        self.records.append((service, action, outcome))


class RecordingBootstrapper(EnvCredentialBootstrapper):
    def __init__(self) -> None:
        super().__init__(loader=lambda _: "{\"token\":\"abc\"}")
        self.called = False

    async def bootstrap(self, service: str):  # type: ignore[override]
        self.called = True
        return await super().bootstrap(service)


def test_client_registers_and_handles_messages() -> None:
    transport = MemoryTransport()
    telemetry = RecordingTelemetry()
    bootstrapper = RecordingBootstrapper()

    async def scenario() -> None:
        client = StoneMQClient(
            "telegram",
            transport,
            telemetry=telemetry,
            credential_bootstrapper=bootstrapper,
        )

        events: list[Envelope] = []

        async def handler(envelope: Envelope) -> None:
            events.append(envelope)

        client.register("inbound_event", handler)
        await client.start()

        assert bootstrapper.called is True
        assert topic_for("telegram", "inbound_event") in transport.subscriptions

        await client.publish(
            "inbound_event",
            build_envelope("telegram", "inbound_event", {"body": "hi"}, trace_id="trace"),
        )

        await asyncio.sleep(0)

        assert len(events) == 1
        assert events[0].trace_id == "trace"
        assert telemetry.records[-1] == ("telegram", "inbound_event", "ok")

    asyncio.run(scenario())


def test_client_requires_handlers() -> None:
    transport = MemoryTransport()

    async def scenario() -> None:
        client = StoneMQClient("slack", transport)
        try:
            await client.start()
        except RuntimeError:
            return
        raise AssertionError("expected RuntimeError")

    asyncio.run(scenario())
