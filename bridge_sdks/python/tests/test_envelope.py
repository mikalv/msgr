from datetime import datetime, timezone

import pytest

from datetime import datetime, timezone

import pytest

from msgr_bridge_sdk.envelope import Envelope, build_envelope, DEFAULT_SCHEMA


def test_build_envelope_defaults() -> None:
    envelope = build_envelope("discord", "send", {"body": "hi"})

    assert envelope.schema == DEFAULT_SCHEMA
    assert envelope.service == "discord"
    assert envelope.action == "send"
    assert envelope.metadata == {}
    assert envelope.trace_id
    assert envelope.occurred_at.tzinfo == timezone.utc


def test_build_envelope_overrides() -> None:
    occurred_at = datetime.now(tz=timezone.utc)
    envelope = build_envelope(
        "slack",
        "sync",
        {},
        trace_id="trace",
        metadata={"retries": 1},
        schema="msgr.bridge.v2",
        occurred_at=occurred_at,
    )

    assert envelope.trace_id == "trace"
    assert envelope.metadata == {"retries": 1}
    assert envelope.schema == "msgr.bridge.v2"
    assert envelope.occurred_at == occurred_at.replace(microsecond=(occurred_at.microsecond // 1000) * 1000)


def test_from_dict_roundtrip() -> None:
    envelope = build_envelope("snapchat", "inbound_event", {"body": "hi"}, trace_id="trace")
    reconstructed = Envelope.from_dict(envelope.to_dict())
    assert reconstructed == envelope


def test_metadata_validation() -> None:
    with pytest.raises(TypeError):
        build_envelope("telegram", "send", {}, metadata=["invalid"])  # type: ignore[arg-type]
