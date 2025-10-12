"""Session persistence helpers for the Signal bridge daemon."""

from __future__ import annotations

import asyncio
import re
from pathlib import Path
from typing import Callable, Dict, Optional

from .client import SignalClientProtocol, encode_session_blob


class SessionStore:
    """Persists Signal session state blobs on disk."""

    def __init__(self, base_path: Path) -> None:
        self._base = Path(base_path)
        self._base.mkdir(parents=True, exist_ok=True)

    def path_for(self, user_id: str) -> Path:
        safe = _slugify(user_id)
        return self._base / f"{safe}.state"

    async def persist(self, user_id: str, blob: bytes) -> Path:
        path = self.path_for(user_id)
        tmp = path.with_suffix(".tmp")
        await asyncio.to_thread(tmp.write_bytes, blob)
        await asyncio.to_thread(tmp.replace, path)
        return path

    async def load(self, user_id: str) -> Optional[bytes]:
        path = self.path_for(user_id)
        if not path.exists():
            return None
        return await asyncio.to_thread(path.read_bytes)

    async def export_base64(self, user_id: str) -> Optional[str]:
        data = await self.load(user_id)
        if data is None:
            return None
        return encode_session_blob(data)


class SessionManager:
    """Coordinates Signal client instances and shared session state."""

    def __init__(self, store: SessionStore, factory: Callable[[Path], SignalClientProtocol]) -> None:
        self._store = store
        self._factory = factory
        self._clients: Dict[str, SignalClientProtocol] = {}
        self._locks: Dict[str, asyncio.Lock] = {}

    async def ensure_client(
        self, user_id: str, *, session_blob: Optional[bytes] = None
    ) -> SignalClientProtocol:
        lock = self._locks.setdefault(user_id, asyncio.Lock())
        async with lock:
            client = self._clients.get(user_id)
            if client is not None:
                return client

            if session_blob is not None:
                await self._store.persist(user_id, session_blob)

            path = self._store.path_for(user_id)
            client = self._factory(path)
            await client.connect()
            self._clients[user_id] = client
            return client

    def get_client(self, user_id: str) -> SignalClientProtocol:
        try:
            return self._clients[user_id]
        except KeyError as exc:
            raise RuntimeError(f"no active session for {user_id}") from exc

    async def remove_client(self, user_id: str, *, disconnect: bool = True) -> None:
        client = self._clients.pop(user_id, None)
        if client is not None and disconnect:
            await client.disconnect()

    async def export_session(self, user_id: str) -> Optional[str]:
        return await self._store.export_base64(user_id)

    async def shutdown(self) -> None:
        for user_id in list(self._clients.keys()):
            await self.remove_client(user_id)


def _slugify(value: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9_.-]+", "_", value)
    return cleaned.strip("_") or "session"
