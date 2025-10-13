"""Change-notification helpers for the Teams bridge client."""

from __future__ import annotations

import asyncio
import contextlib
import datetime as dt
import logging
from dataclasses import dataclass
from typing import Awaitable, Callable, Dict, Mapping, Optional, Protocol

NotificationHandler = Callable[[Mapping[str, object]], Awaitable[None]]


class TeamsNotificationSource(Protocol):
    """Protocol implemented by change-notification providers."""

    async def start(
        self,
        tenant: "TeamsTenant",
        token: "TeamsToken",
        dispatch: NotificationHandler,
    ) -> None:
        """Begin streaming change notifications for ``tenant``."""

    async def stop(self) -> None:
        """Tear down any active subscriptions and background tasks."""

    async def acknowledge(self, event_id: str) -> None:
        """Acknowledge a delivered event so upstream relays can prune it."""

    async def refresh(self, token: "TeamsToken") -> None:
        """Update internal state after OAuth tokens refresh."""

    @property
    def active(self) -> bool:
        """Return ``True`` while notifications are being streamed."""

    @property
    def subscription_id(self) -> Optional[str]:
        """Return the subscription identifier if available."""


class NotificationTransport(Protocol):
    """Abstract transport used by :class:`TeamsWebhookNotificationSource`."""

    async def subscribe(
        self,
        tenant: "TeamsTenant",
        token: "TeamsToken",
        *,
        resource: str,
        expiration: Optional[int] = None,
    ) -> Mapping[str, object]:
        """Register a subscription and return Graph's payload."""

    async def renew(
        self,
        subscription_id: str,
        tenant: "TeamsTenant",
        token: "TeamsToken",
        *,
        resource: str,
        expiration: Optional[int] = None,
    ) -> Mapping[str, object]:
        """Extend a subscription's validity window."""

    async def unsubscribe(self, subscription_id: str) -> None:
        """Remove a subscription from the upstream transport."""

    def register(self, subscription_id: str, handler: NotificationHandler) -> None:
        """Attach a callback invoked for each delivered change notification."""

    def unregister(self, subscription_id: str) -> None:
        """Detach the registered callback for ``subscription_id``."""

    async def acknowledge(self, subscription_id: str, event_id: str) -> None:
        """Propagate acknowledgements for delivered events."""


@dataclass
class TeamsWebhookNotificationSource(TeamsNotificationSource):
    """Manages Microsoft Graph webhook subscriptions for chat messages."""

    transport: NotificationTransport
    resource: str = "/chats/getAllMessages"
    renewal_window: float = 300.0

    def __post_init__(self) -> None:  # pragma: no cover - simple attribute init
        self._logger = logging.getLogger(__name__)
        self._subscription_id: Optional[str] = None
        self._tenant: Optional["TeamsTenant"] = None
        self._token: Optional["TeamsToken"] = None
        self._dispatch: Optional[NotificationHandler] = None
        self._renew_task: Optional[asyncio.Task[None]] = None
        self._shutdown = asyncio.Event()

    async def start(
        self,
        tenant: "TeamsTenant",
        token: "TeamsToken",
        dispatch: NotificationHandler,
    ) -> None:
        if self._subscription_id is not None:
            return

        self._tenant = tenant
        self._token = token
        self._dispatch = dispatch
        response = await self.transport.subscribe(
            tenant,
            token,
            resource=self.resource,
        )
        subscription_id = _extract_subscription_id(response)
        if subscription_id is None:
            raise RuntimeError("subscription response missing identifier")

        self._subscription_id = subscription_id
        self.transport.register(subscription_id, self._handle_notification)
        self._shutdown.clear()
        expiration = _extract_expiration(response)
        self._renew_task = asyncio.create_task(
            self._renewal_loop(expiration),
            name="teams-webhook-renewal",
        )
        self._logger.info(
            "Teams webhook subscription started",
            extra={"subscription_id": subscription_id, "resource": self.resource},
        )

    async def stop(self) -> None:
        self._shutdown.set()
        if self._renew_task is not None:
            self._renew_task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await self._renew_task
            self._renew_task = None

        subscription_id = self._subscription_id
        if subscription_id is not None:
            self.transport.unregister(subscription_id)
            await self.transport.unsubscribe(subscription_id)
            self._logger.info(
                "Teams webhook subscription stopped",
                extra={"subscription_id": subscription_id},
            )

        self._subscription_id = None
        self._tenant = None
        self._token = None
        self._dispatch = None

    async def acknowledge(self, event_id: str) -> None:
        subscription_id = self._subscription_id
        if subscription_id is None or not event_id:
            return
        await self.transport.acknowledge(subscription_id, event_id)

    async def refresh(self, token: "TeamsToken") -> None:
        self._token = token

    @property
    def active(self) -> bool:
        return self._subscription_id is not None and not self._shutdown.is_set()

    @property
    def subscription_id(self) -> Optional[str]:
        return self._subscription_id

    async def _handle_notification(self, payload: Mapping[str, object]) -> None:
        dispatch = self._dispatch
        if dispatch is None:
            return
        enriched = dict(payload)
        if "tenant_id" not in enriched and self._tenant is not None:
            enriched["tenant_id"] = self._tenant.id
        await dispatch(enriched)

    async def _renewal_loop(self, expiration: Optional[float]) -> None:
        try:
            while not self._shutdown.is_set():
                wait_for = _compute_renewal_delay(expiration, self.renewal_window)
                try:
                    await asyncio.wait_for(self._shutdown.wait(), timeout=wait_for)
                except asyncio.TimeoutError:
                    pass
                if self._shutdown.is_set():
                    break
                await self._renew_subscription()
        except asyncio.CancelledError:  # pragma: no cover - cancellation is expected on shutdown
            pass

    async def _renew_subscription(self) -> None:
        subscription_id = self._subscription_id
        tenant = self._tenant
        token = self._token
        if subscription_id is None or tenant is None or token is None:
            return
        try:
            response = await self.transport.renew(
                subscription_id,
                tenant,
                token,
                resource=self.resource,
            )
            expiration = _extract_expiration(response)
            if expiration is not None:
                self._logger.debug(
                    "Teams webhook subscription renewed",
                    extra={
                        "subscription_id": subscription_id,
                        "next_expiration": expiration,
                    },
                )
        except Exception:  # pragma: no cover - defensive logging for ops
            self._logger.exception(
                "Failed to renew Teams webhook subscription",
                extra={"subscription_id": subscription_id},
            )


class MemoryNotificationTransport(NotificationTransport):
    """In-memory transport used in unit tests."""

    def __init__(self) -> None:
        self.subscriptions: Dict[str, Dict[str, object]] = {}
        self.handlers: Dict[str, NotificationHandler] = {}
        self.acknowledged: list[tuple[str, str]] = []
        self.renewals: list[str] = []
        self.unsubscribed: list[str] = []
        self._counter = 0

    async def subscribe(
        self,
        tenant: "TeamsTenant",
        token: "TeamsToken",
        *,
        resource: str,
        expiration: Optional[int] = None,
    ) -> Mapping[str, object]:
        self._counter += 1
        subscription_id = f"sub-{self._counter}"
        expiration_dt = dt.datetime.now(dt.timezone.utc) + dt.timedelta(minutes=10)
        payload = {
            "id": subscription_id,
            "resource": resource,
            "tenant_id": tenant.id,
            "expirationDateTime": expiration_dt.replace(microsecond=0).isoformat() + "Z",
        }
        self.subscriptions[subscription_id] = dict(payload)
        return payload

    async def renew(
        self,
        subscription_id: str,
        tenant: "TeamsTenant",
        token: "TeamsToken",
        *,
        resource: str,
        expiration: Optional[int] = None,
    ) -> Mapping[str, object]:
        self.renewals.append(subscription_id)
        expiration_dt = dt.datetime.now(dt.timezone.utc) + dt.timedelta(minutes=10)
        payload = {
            "id": subscription_id,
            "resource": resource,
            "tenant_id": tenant.id,
            "expirationDateTime": expiration_dt.replace(microsecond=0).isoformat() + "Z",
        }
        self.subscriptions[subscription_id] = dict(payload)
        return payload

    async def unsubscribe(self, subscription_id: str) -> None:
        self.unsubscribed.append(subscription_id)
        self.subscriptions.pop(subscription_id, None)
        self.handlers.pop(subscription_id, None)

    def register(self, subscription_id: str, handler: NotificationHandler) -> None:
        self.handlers[subscription_id] = handler

    def unregister(self, subscription_id: str) -> None:
        self.handlers.pop(subscription_id, None)

    async def acknowledge(self, subscription_id: str, event_id: str) -> None:
        self.acknowledged.append((subscription_id, event_id))

    async def dispatch(self, subscription_id: str, payload: Mapping[str, object]) -> None:
        handler = self.handlers.get(subscription_id)
        if handler is not None:
            await handler(payload)


def _extract_subscription_id(payload: Mapping[str, object]) -> Optional[str]:
    value = payload.get("id") if isinstance(payload.get("id"), str) else None
    if value:
        return value
    subscription = payload.get("subscriptionId")
    return subscription if isinstance(subscription, str) else None


def _extract_expiration(payload: Mapping[str, object]) -> Optional[float]:
    value = payload.get("expirationDateTime")
    if isinstance(value, str):
        try:
            cleaned = value.replace("Z", "")
            if cleaned.endswith("+00:00"):
                cleaned = cleaned[:-6]
            dt_obj = dt.datetime.fromisoformat(cleaned)
        except ValueError:
            return None
        return dt_obj.replace(tzinfo=dt.timezone.utc).timestamp()
    return None


def _compute_renewal_delay(expiration: Optional[float], renewal_window: float) -> float:
    if expiration is None:
        return max(renewal_window, 60.0)
    now = dt.datetime.now(dt.timezone.utc).timestamp()
    delay = max(5.0, expiration - now - renewal_window)
    return delay


__all__ = [
    "TeamsNotificationSource",
    "NotificationTransport",
    "TeamsWebhookNotificationSource",
    "MemoryNotificationTransport",
]

