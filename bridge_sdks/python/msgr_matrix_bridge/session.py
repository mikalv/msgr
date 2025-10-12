"""Session persistence for the Matrix bridge."""

from __future__ import annotations

import asyncio
import json
import re
from pathlib import Path
from typing import Callable, Dict, Mapping, Optional, Tuple

from .client import MatrixClientProtocol, MatrixSession


class MatrixSessionStore:
    """Persists Matrix sessions to disk."""

    def __init__(self, base_path: Path) -> None:
        self._base = Path(base_path)
        self._base.mkdir(parents=True, exist_ok=True)

    def path_for(self, homeserver: str, user_id: str) -> Path:
        safe_home = _slugify(homeserver)
        safe_user = _slugify(user_id)
        return self._base / safe_home / f"{safe_user}.json"

    async def persist(self, homeserver: str, user_id: str, session: MatrixSession) -> Path:
        path = self.path_for(homeserver, user_id)
        directory = path.parent
        directory.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(".tmp")
        payload = json.dumps(session.to_dict())
        await asyncio.to_thread(tmp.write_text, payload, encoding="utf-8")
        await asyncio.to_thread(tmp.replace, path)
        return path

    async def load(self, homeserver: str, user_id: str) -> Optional[MatrixSession]:
        path = self.path_for(homeserver, user_id)
        if not path.exists():
            return None
        text = await asyncio.to_thread(path.read_text, encoding="utf-8")
        data = json.loads(text)
        if not isinstance(data, Mapping):  # pragma: no cover - defensive
            raise ValueError("invalid session payload")
        return MatrixSession.from_mapping(dict(data))

    async def export(self, homeserver: str, user_id: str) -> Optional[Dict[str, str]]:
        session = await self.load(homeserver, user_id)
        if session is None:
            return None
        return dict(session.to_dict())


class MatrixSessionManager:
    """Coordinates Matrix client lifetimes and persistence."""

    def __init__(
        self,
        store: MatrixSessionStore,
        factory: Callable[[str, Optional[MatrixSession]], MatrixClientProtocol],
    ) -> None:
        self._store = store
        self._factory = factory
        self._clients: Dict[Tuple[str, str], MatrixClientProtocol] = {}
        self._locks: Dict[Tuple[str, str], asyncio.Lock] = {}

    async def ensure_client(
        self,
        user_id: str,
        homeserver: str,
        *,
        session: Optional[MatrixSession] = None,
    ) -> MatrixClientProtocol:
        key = (homeserver, user_id)
        lock = self._locks.setdefault(key, asyncio.Lock())
        async with lock:
            client = self._clients.get(key)
            if client is not None:
                return client

            if session is None:
                session = await self._store.load(homeserver, user_id)
            else:
                await self._store.persist(homeserver, user_id, session)

            client = self._factory(homeserver, session)
            self._clients[key] = client
            return client

    def get_client(self, user_id: str, homeserver: str) -> MatrixClientProtocol:
        key = (homeserver, user_id)
        try:
            return self._clients[key]
        except KeyError as exc:  # pragma: no cover - defensive
            raise RuntimeError(f"no active session for {user_id}@{homeserver}") from exc

    async def persist_session(self, user_id: str, homeserver: str, session: MatrixSession) -> None:
        await self._store.persist(homeserver, user_id, session)

    async def export_session(self, user_id: str, homeserver: str) -> Optional[Dict[str, str]]:
        return await self._store.export(homeserver, user_id)

    async def remove_client(self, user_id: str, homeserver: str, *, close: bool = True) -> None:
        key = (homeserver, user_id)
        client = self._clients.pop(key, None)
        if client is not None and close:
            await client.close()

    async def shutdown(self) -> None:
        for homeserver, user_id in list(self._clients.keys()):
            await self.remove_client(user_id, homeserver)


def _slugify(value: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9_.-]+", "_", value)
    return cleaned.strip("_") or "session"
