"""Session coordination helpers for the Slack bridge."""

from __future__ import annotations

import asyncio
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Dict, Mapping, Optional, Tuple

from .client import SlackClientProtocol, SlackToken


@dataclass(frozen=True)
class SessionData:
    """Persisted Slack session metadata."""

    token: SlackToken
    workspace_id: Optional[str] = None
    user_id: Optional[str] = None

    def to_dict(self) -> Mapping[str, object]:
        payload: Dict[str, object] = {
            "token": self.token.to_dict(),
        }
        if self.workspace_id is not None:
            payload["workspace_id"] = self.workspace_id
        if self.user_id is not None:
            payload["user_id"] = self.user_id
        return payload

    @staticmethod
    def from_dict(data: Mapping[str, object]) -> "SessionData":
        token_payload = data.get("token")
        if isinstance(token_payload, Mapping):
            token_value = str(token_payload.get("token") or token_payload.get("value"))
            token_type = str(token_payload.get("token_type", "user"))
            expires_at = token_payload.get("expires_at")
            token = SlackToken(
                value=token_value,
                token_type=token_type,
                expires_at=float(expires_at) if isinstance(expires_at, (int, float)) else None,
            )
        elif isinstance(token_payload, str):
            token = SlackToken(value=token_payload)
        else:
            raise ValueError("session payload is missing the Slack token")

        workspace_id = data.get("workspace_id")
        user_id = data.get("user_id")

        return SessionData(
            token=token,
            workspace_id=str(workspace_id) if isinstance(workspace_id, str) else None,
            user_id=str(user_id) if isinstance(user_id, str) else None,
        )


class SessionStore:
    """Persists Slack session blobs to disk."""

    def __init__(self, base_path: Path) -> None:
        self._base = Path(base_path)
        self._base.mkdir(parents=True, exist_ok=True)

    def path_for(self, user_id: str, instance: Optional[str]) -> Path:
        safe_user = _slugify(user_id)
        safe_instance = _slugify(instance or "workspace")
        return self._base / f"{safe_user}__{safe_instance}.json"

    async def persist(self, user_id: str, instance: Optional[str], data: SessionData) -> Path:
        path = self.path_for(user_id, instance)
        tmp = path.with_suffix(".tmp")
        payload = json.dumps(data.to_dict(), indent=2, sort_keys=True)
        await asyncio.to_thread(tmp.write_text, payload, encoding="utf-8")
        await asyncio.to_thread(tmp.replace, path)
        return path

    async def load(self, user_id: str, instance: Optional[str]) -> Optional[SessionData]:
        path = self.path_for(user_id, instance)
        if not path.exists():
            return None
        raw = await asyncio.to_thread(path.read_text, encoding="utf-8")
        data = json.loads(raw)
        if not isinstance(data, Mapping):
            raise ValueError("stored session is not a mapping")
        return SessionData.from_dict(data)

    async def delete(self, user_id: str, instance: Optional[str]) -> None:
        path = self.path_for(user_id, instance)
        if path.exists():
            await asyncio.to_thread(path.unlink)


class SessionManager:
    """Coordinates Slack client instances and persisted session state."""

    def __init__(self, store: SessionStore, factory: Callable[[Optional[str]], SlackClientProtocol]) -> None:
        self._store = store
        self._factory = factory
        self._clients: Dict[str, SlackClientProtocol] = {}
        self._sessions: Dict[str, SessionData] = {}
        self._locks: Dict[str, asyncio.Lock] = {}

    async def ensure_client(
        self,
        user_id: str,
        instance: Optional[str],
        *,
        token: Optional[SlackToken] = None,
        session: Optional[SessionData] = None,
    ) -> Tuple[SlackClientProtocol, SessionData]:
        key = self._key(user_id, instance)
        lock = self._locks.setdefault(key, asyncio.Lock())
        async with lock:
            current_session = self._sessions.get(key)
            if session is None and token is not None:
                session = SessionData(token=token, workspace_id=instance, user_id=user_id)
            if session is None:
                session = current_session
            if session is None:
                session = await self._store.load(user_id, instance)
            if session is None:
                raise ValueError("no session available for Slack client")

            client = self._clients.get(key)
            if client is None or not await client.is_connected():
                client = self._factory(instance)
                await client.connect(session.token)
                self._clients[key] = client
            elif token is not None and session.token.value != token.value:
                await client.disconnect()
                client = self._factory(instance)
                session = SessionData(token=token, workspace_id=instance, user_id=user_id)
                await client.connect(session.token)
                self._clients[key] = client

            self._sessions[key] = session
            await self._store.persist(user_id, instance, session)
            return client, session

    def get_client(self, user_id: str, instance: Optional[str]) -> SlackClientProtocol:
        key = self._key(user_id, instance)
        try:
            return self._clients[key]
        except KeyError as exc:
            raise RuntimeError(f"no active Slack client for {user_id}/{instance}") from exc

    def get_session(self, user_id: str, instance: Optional[str]) -> Optional[SessionData]:
        key = self._key(user_id, instance)
        return self._sessions.get(key)

    async def export_session(self, user_id: str, instance: Optional[str]) -> Optional[SessionData]:
        key = self._key(user_id, instance)
        session = self._sessions.get(key)
        if session is not None:
            return session
        return await self._store.load(user_id, instance)

    async def remove_client(self, user_id: str, instance: Optional[str], *, disconnect: bool = True) -> None:
        key = self._key(user_id, instance)
        client = self._clients.pop(key, None)
        self._sessions.pop(key, None)
        if client is not None and disconnect:
            await client.disconnect()

    async def shutdown(self) -> None:
        for key, client in list(self._clients.items()):
            if client is not None:
                await client.disconnect()
            self._clients.pop(key, None)
            self._sessions.pop(key, None)

    @staticmethod
    def _key(user_id: str, instance: Optional[str]) -> str:
        return f"{user_id}::{instance or 'workspace'}"


def _slugify(value: Optional[str]) -> str:
    if value is None:
        return "default"
    cleaned = re.sub(r"[^A-Za-z0-9_.-]+", "_", value)
    return cleaned.strip("_") or "session"
