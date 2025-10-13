"""Microsoft Teams bridge daemon implementation using the StoneMQ SDK."""

from .client import (
    TeamsClientProtocol,
    TeamsFileUpload,
    TeamsGraphClient,
    TeamsIdentity,
    TeamsOAuthClient,
    TeamsOAuthClientProtocol,
    TeamsTenant,
    TeamsToken,
    TeamsUploadedFile,
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
    "TeamsFileUpload",
    "TeamsIdentity",
    "TeamsOAuthClient",
    "TeamsOAuthClientProtocol",
    "TeamsUploadedFile",
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
