"""Credential bootstrap helpers for StoneMQ daemons."""

from __future__ import annotations

import json
import os
from typing import Mapping, Protocol


class CredentialBootstrapper(Protocol):
    async def bootstrap(self, service: str) -> Mapping[str, object]:
        """Return credential material for the given service."""


class EnvCredentialBootstrapper:
    """Loads credential JSON from environment variables."""

    def __init__(self, loader=None) -> None:
        self._loader = loader or os.getenv

    async def bootstrap(self, service: str) -> Mapping[str, object]:
        key = f"MSGR_{service.upper()}_CREDENTIALS"
        raw = self._loader(key)
        if not raw:
            return {}
        return json.loads(raw)
