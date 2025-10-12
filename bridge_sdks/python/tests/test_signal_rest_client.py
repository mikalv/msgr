import asyncio
import json
from collections import deque
from pathlib import Path
from typing import Dict, Mapping, Optional, Tuple

from msgr_signal_bridge import (
    HttpResponse,
    SignalRestClient,
)


class FakeTransport:
    def __init__(self) -> None:
        self.requests: deque[Tuple[str, str, Optional[Mapping[str, object]], Optional[Mapping[str, object]]]] = deque()
        self.responses: deque[HttpResponse] = deque()

    def queue_response(
        self,
        status: int,
        body: Optional[object] = None,
        headers: Optional[Mapping[str, str]] = None,
    ) -> None:
        payload: bytes
        if body is None:
            payload = b""
        elif isinstance(body, (dict, list)):
            payload = json.dumps(body).encode("utf-8")
        elif isinstance(body, str):
            payload = body.encode("utf-8")
        elif isinstance(body, bytes):
            payload = body
        else:
            raise TypeError(f"unsupported body type: {type(body)!r}")
        self.responses.append(HttpResponse(status=status, body=payload, headers=headers or {}))

    async def request(
        self,
        method: str,
        path: str,
        *,
        params: Optional[Mapping[str, object]] = None,
        json_body: Optional[Mapping[str, object]] = None,
    ) -> HttpResponse:
        self.requests.append((method, path, params, json_body))
        if not self.responses:
            raise AssertionError("no response queued for request")
        return self.responses.popleft()


def _run(async_fn):
    asyncio.run(async_fn())


def test_is_linked_success(tmp_path: Path) -> None:
    transport = FakeTransport()
    transport.queue_response(200, {"uuid": "uuid-123"})
    client = SignalRestClient(
        "+4712345678",
        transport=transport,
        session_path=tmp_path / "session.json",
    )

    async def scenario() -> None:
        await client.connect()
        assert await client.is_linked() is True
        assert transport.requests[0][:2] == ("GET", "/v1/accounts/+4712345678")

    _run(scenario)


def test_is_linked_not_found(tmp_path: Path) -> None:
    transport = FakeTransport()
    transport.queue_response(404, {})
    client = SignalRestClient(
        "+4798765432",
        transport=transport,
        session_path=tmp_path / "session.json",
    )

    async def scenario() -> None:
        await client.connect()
        assert await client.is_linked() is False

    _run(scenario)


def test_request_linking_code(tmp_path: Path) -> None:
    transport = FakeTransport()
    body = {
        "verification_uri": "https://signal.test/link",
        "code": "ABC-123",
        "expires_at": 123456.0,
    }
    transport.queue_response(200, body)
    client = SignalRestClient(
        "+4712340000",
        transport=transport,
        session_path=tmp_path / "session.json",
    )

    async def scenario() -> None:
        await client.connect()
        code = await client.request_linking_code(device_name="Bridge")
        assert code.verification_uri == "https://signal.test/link"
        assert code.code == "ABC-123"
        assert code.device_name == "Bridge"
        assert transport.requests[0][1] == "/v1/accounts/+4712340000/link"

    _run(scenario)


def test_send_text_message(tmp_path: Path) -> None:
    transport = FakeTransport()
    transport.queue_response(201, {"timestamp": 123, "message_id": "m-1"})
    client = SignalRestClient(
        "+4799999999",
        transport=transport,
        session_path=tmp_path / "session.json",
    )

    async def scenario() -> None:
        await client.connect()
        result = await client.send_text_message(
            "+4798765432",
            "hei",
            attachments=[{"attachment": "id"}],
            metadata={"preview": False},
        )
        assert result["chat_id"] == "+4798765432"
        assert result["timestamp"] == 123
        assert transport.requests[0][1] == "/v1/messages"
        payload = transport.requests[0][3]
        assert payload is not None
        assert payload["recipient"] == "+4798765432"
        assert payload["attachments"] == [{"attachment": "id"}]

    _run(scenario)


def test_event_polling_dispatch(tmp_path: Path) -> None:
    transport = FakeTransport()
    event_body: Dict[str, object] = {
        "envelope": {
            "timestamp": 98765,
            "source": "+47123",
            "dataMessage": {"message": "hei"},
        }
    }
    transport.queue_response(200, [event_body])
    transport.queue_response(204, {})
    client = SignalRestClient(
        "+4711111111",
        transport=transport,
        session_path=tmp_path / "session.json",
        poll_interval=0.01,
    )

    events: list[Mapping[str, object]] = []

    async def scenario() -> None:
        await client.connect()

        async def handler(event: Mapping[str, object]) -> None:
            events.append(event)

        client.add_event_handler(handler)
        await asyncio.sleep(0.05)
        await client.disconnect()
        assert events and events[0]["message"] == "hei"
        assert transport.requests[0][1] == "/v1/receive/+4711111111"

    _run(scenario)


def test_acknowledge_event(tmp_path: Path) -> None:
    transport = FakeTransport()
    transport.queue_response(204, {})
    client = SignalRestClient(
        "+4712222222",
        transport=transport,
        session_path=tmp_path / "session.json",
    )

    async def scenario() -> None:
        await client.connect()
        await client.acknowledge_event("123456")
        assert transport.requests[0][:2] == ("DELETE", "/v1/receive/+4712222222/123456")

    _run(scenario)
