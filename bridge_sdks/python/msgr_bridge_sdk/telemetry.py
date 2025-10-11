"""Telemetry primitives for the Python bridge SDK."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol


class TelemetryRecorder(Protocol):
    def record_delivery(self, service: str, action: str, duration: float, outcome: str) -> None:
        """Record a queue delivery metric."""


@dataclass
class NoopTelemetry:
    """Telemetry recorder that ignores all metrics."""

    def record_delivery(self, service: str, action: str, duration: float, outcome: str) -> None:
        return
