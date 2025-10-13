"""Session coordination helpers for the Teams bridge."""

from __future__ import annotations

import asyncio
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Dict, List, Mapping, Optional, Tuple

from .client import TeamsClientProtocol, TeamsTenant, TeamsToken


@dataclass(frozen=True)
class SessionData:
    """Persisted Teams session metadata."""

    tenant: TeamsTenant
    token: TeamsToken
    user_id: Optional[str] = None

    def to_dict(self) -> Mapping[str, object]:
        return {
            "tenant": self.tenant.to_dict(),
            "token": self.token.to_dict(),
            "user_id": self.user_id,
        }

    @staticmethod
    def from_dict(data: Mapping[str, object]) -> "SessionData":
        tenant_payload = data.get("tenant")
        if not isinstance(tenant_payload, Mapping):
            raise ValueError("session payload missing tenant metadata")
        tenant = TeamsTenant(
            id=str(tenant_payload["id"]),
            display_name=str(tenant_payload.get("display_name")) if tenant_payload.get("display_name") else None,
            domain=str(tenant_payload.get("domain")) if tenant_payload.get("domain") else None,
        )

        token_payload = data.get("token")
        if isinstance(token_payload, Mapping):
            access_token = str(token_payload.get("access_token") or token_payload.get("token"))
            refresh_token = token_payload.get("refresh_token")
            expires_at = token_payload.get("expires_at")
            token_type = token_payload.get("token_type", "Bearer")
            token = TeamsToken(
                access_token=access_token,
                refresh_token=str(refresh_token) if isinstance(refresh_token, str) else None,
                expires_at=float(expires_at) if isinstance(expires_at, (int, float)) else None,
                token_type=str(token_type),
            )
        elif isinstance(token_payload, str):
            token = TeamsToken(access_token=token_payload)
        else:
            raise ValueError("session payload missing token metadata")

        user_id = data.get("user_id")
        return SessionData(
            tenant=tenant,
            token=token,
            user_id=str(user_id) if isinstance(user_id, str) else None,
        )


class SessionStore:
    """Persists Teams session blobs to disk."""

    def __init__(self, base_path: Path) -> None:
        self._base = Path(base_path)
        self._base.mkdir(parents=True, exist_ok=True)

    def path_for(self, tenant_id: str, user_id: Optional[str]) -> Path:
        safe_tenant = _slugify(tenant_id)
        safe_user = _slugify(user_id or "user")
        return self._base / f"{safe_tenant}__{safe_user}.json"

    async def persist(self, tenant_id: str, user_id: Optional[str], data: SessionData) -> Path:
        path = self.path_for(tenant_id, user_id)
        tmp = path.with_suffix(".tmp")
        payload = json.dumps(data.to_dict(), indent=2, sort_keys=True)
        await asyncio.to_thread(tmp.write_text, payload, encoding="utf-8")
        await asyncio.to_thread(tmp.replace, path)
        return path

    async def load(self, tenant_id: str, user_id: Optional[str]) -> Optional[SessionData]:
        path = self.path_for(tenant_id, user_id)
        if not path.exists():
            return None
        raw = await asyncio.to_thread(path.read_text, encoding="utf-8")
        data = json.loads(raw)
        if not isinstance(data, Mapping):
            raise ValueError("stored session is not a mapping")
        return SessionData.from_dict(data)

    async def delete(self, tenant_id: str, user_id: Optional[str]) -> None:
        path = self.path_for(tenant_id, user_id)
        if path.exists():
            await asyncio.to_thread(path.unlink)


class SessionManager:
    """Coordinates Teams client instances and persisted session state."""

    def __init__(self, store: SessionStore, factory: Callable[[TeamsTenant], TeamsClientProtocol]) -> None:
        self._store = store
        self._factory = factory
        self._clients: Dict[str, TeamsClientProtocol] = {}
        self._sessions: Dict[str, SessionData] = {}
        self._locks: Dict[str, asyncio.Lock] = {}

    async def ensure_client(
        self,
        tenant: TeamsTenant,
        *,
        token: Optional[TeamsToken] = None,
        user_id: Optional[str] = None,
        session: Optional[SessionData] = None,
    ) -> Tuple[TeamsClientProtocol, SessionData]:
        key = self._key(tenant.id, user_id)
        lock = self._locks.setdefault(key, asyncio.Lock())
        async with lock:
            current_session = self._sessions.get(key)
            session_to_use = session

            if session_to_use is None:
                if token is not None:
                    session_to_use = SessionData(tenant=tenant, token=token, user_id=user_id)
                elif current_session is not None:
                    session_to_use = current_session
                else:
                    session_to_use = await self._store.load(tenant.id, user_id)

            if session_to_use is None:
                raise ValueError("no session available for Teams client")

            if token is not None and token.access_token and session_to_use.token.access_token != token.access_token:
                session_to_use = SessionData(tenant=tenant, token=token, user_id=user_id or session_to_use.user_id)

            client = self._clients.get(key)
            if client is None or not await client.is_connected():
                client = self._factory(session_to_use.tenant)
                await client.connect(session_to_use.tenant, session_to_use.token)
                self._clients[key] = client
            elif token is not None and session_to_use.token.access_token == token.access_token:
                # Session already reflects the updated token and connection remains valid.
                pass
            elif token is not None:
                await client.disconnect()
                client = self._factory(session_to_use.tenant)
                await client.connect(session_to_use.tenant, session_to_use.token)
                self._clients[key] = client

            self._sessions[key] = session_to_use
            await self._store.persist(session_to_use.tenant.id, session_to_use.user_id, session_to_use)
            return client, session_to_use

    def get_client(self, tenant_id: str, user_id: Optional[str]) -> TeamsClientProtocol:
        key = self._key(tenant_id, user_id)
        try:
            return self._clients[key]
        except KeyError as exc:
            raise RuntimeError(f"no active Teams client for {tenant_id}/{user_id}") from exc

    def get_session(self, tenant_id: str, user_id: Optional[str]) -> Optional[SessionData]:
        key = self._key(tenant_id, user_id)
        return self._sessions.get(key)

    def active_entries(self) -> List[Tuple[str, Optional[str], TeamsClientProtocol, Optional[SessionData]]]:
        """Return a snapshot of active Teams clients and their sessions."""

        entries: List[Tuple[str, Optional[str], TeamsClientProtocol, Optional[SessionData]]] = []
        for key, client in self._clients.items():
            tenant_id, user_token = key.split("::", 1)
            user_id = None if user_token == "user" else user_token
            entries.append((tenant_id, user_id, client, self._sessions.get(key)))
        return entries

    async def export_session(self, tenant_id: str, user_id: Optional[str]) -> Optional[SessionData]:
        key = self._key(tenant_id, user_id)
        session = self._sessions.get(key)
        if session is not None:
            return session
        return await self._store.load(tenant_id, user_id)

    async def remove_client(self, tenant_id: str, user_id: Optional[str], *, disconnect: bool = True) -> None:
        key = self._key(tenant_id, user_id)
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
    def _key(tenant_id: str, user_id: Optional[str]) -> str:
        return f"{tenant_id}::{user_id or 'user'}"


def _slugify(value: Optional[str]) -> str:
    if value is None:
        return "default"
    cleaned = re.sub(r"[^A-Za-z0-9_.-]+", "_", value)
    return cleaned.strip("_") or "session"
