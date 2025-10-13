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
)
from .daemon import TeamsBridgeDaemon
from .session import SessionData, SessionManager, SessionStore

__all__ = [
    "TeamsClientProtocol",
    "TeamsGraphClient",
    "TeamsIdentity",
    "TeamsOAuthClient",
    "TeamsOAuthClientProtocol",
    "TeamsTenant",
    "TeamsToken",
    "TeamsUser",
    "TeamsBridgeDaemon",
    "SessionData",
    "SessionManager",
    "SessionStore",
]
