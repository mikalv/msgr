"""Microsoft Teams bridge daemon implementation using the StoneMQ SDK."""

from .client import (
    TeamsClientProtocol,
    TeamsGraphClient,
    TeamsIdentity,
    TeamsOAuthClient,
    TeamsOAuthClientProtocol,
    TeamsTenant,
    TeamsToken,
    TeamsUser,
    UpdateHandler,
)
from .daemon import TeamsBridgeDaemon
from .notifications import (
    MemoryNotificationTransport,
    TeamsNotificationSource,
    TeamsWebhookNotificationSource,
)
from .session import SessionData, SessionManager, SessionStore

__all__ = [
    "TeamsClientProtocol",
    "TeamsGraphClient",
    "TeamsIdentity",
    "TeamsOAuthClient",
    "TeamsOAuthClientProtocol",
    "TeamsNotificationSource",
    "TeamsWebhookNotificationSource",
    "MemoryNotificationTransport",
    "TeamsTenant",
    "TeamsToken",
    "TeamsUser",
    "UpdateHandler",
    "TeamsBridgeDaemon",
    "SessionData",
    "SessionManager",
    "SessionStore",
]
