"""Canonical StoneMQ envelope helpers."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Mapping, MutableMapping, Optional
import json
import uuid

DEFAULT_SCHEMA = "msgr.bridge.v1"


def _now() -> datetime:
    now = datetime.now(tz=timezone.utc)
    return now.replace(microsecond=(now.microsecond // 1000) * 1000)


def _truncate(dt: datetime) -> datetime:
    converted = dt.astimezone(timezone.utc)
    return converted.replace(microsecond=(converted.microsecond // 1000) * 1000)


@dataclass(frozen=True)
class Envelope:
    """Canonical queue envelope shared across the Msgr bridge ecosystem."""

    service: str
    action: str
    payload: Mapping[str, Any]
    trace_id: str = field(default_factory=lambda: uuid.uuid4().hex)
    schema: str = DEFAULT_SCHEMA
    metadata: Mapping[str, Any] = field(default_factory=dict)
    occurred_at: datetime = field(default_factory=_now)

    def __post_init__(self) -> None:
        if not self.service:
            raise ValueError("service must not be empty")
        if not self.action:
            raise ValueError("action must not be empty")
        if not isinstance(self.payload, Mapping):
            raise TypeError("payload must be a mapping")
        if not isinstance(self.metadata, Mapping):
            raise TypeError("metadata must be a mapping")
        object.__setattr__(self, "occurred_at", _truncate(self.occurred_at))

    def to_dict(self) -> MutableMapping[str, Any]:
        return {
            "schema": self.schema,
            "service": self.service,
            "action": self.action,
            "trace_id": self.trace_id,
            "occurred_at": self.occurred_at.isoformat(),
            "metadata": dict(self.metadata),
            "payload": dict(self.payload),
        }

    def to_json(self) -> str:
        return json.dumps(self.to_dict())

    @staticmethod
    def from_dict(data: Mapping[str, Any]) -> "Envelope":
        occurred = data.get("occurred_at")
        occurred_at: Optional[datetime]
        if isinstance(occurred, str):
            occurred_at = datetime.fromisoformat(occurred)
        elif isinstance(occurred, datetime):
            occurred_at = occurred
        elif occurred is None:
            occurred_at = _now()
        else:
            raise ValueError("occurred_at must be ISO8601 string or datetime")

        payload = data.get("payload") or {}
        metadata = data.get("metadata") or {}

        return Envelope(
            service=str(data["service"]),
            action=str(data["action"]),
            trace_id=str(data.get("trace_id", uuid.uuid4().hex)),
            schema=str(data.get("schema", DEFAULT_SCHEMA)),
            payload=payload,
            metadata=metadata,
            occurred_at=occurred_at,
        )

    @staticmethod
    def from_json(raw: str) -> "Envelope":
        return Envelope.from_dict(json.loads(raw))


def build_envelope(service: str, action: str, payload: Mapping[str, Any], **kwargs: Any) -> Envelope:
    """Convenience helper mirroring the Elixir ServiceBridge contract."""

    if "metadata" in kwargs and not isinstance(kwargs["metadata"], Mapping):
        raise TypeError("metadata must be a mapping")
    return Envelope(service=service, action=action, payload=payload, **kwargs)
