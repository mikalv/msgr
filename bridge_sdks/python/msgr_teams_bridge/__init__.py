"""Microsoft Teams bridge daemon implementation using the StoneMQ SDK."""

from .client import (
    TeamsClientProtocol,
    TeamsIdentity,
    TeamsOAuthClientProtocol,
    TeamsToken,
    TeamsUser,
    TeamsTenant,
)
from .daemon import TeamsBridgeDaemon
from .session import SessionData, SessionManager, SessionStore

__all__ = [
    "TeamsClientProtocol",
    "TeamsIdentity",
    "TeamsOAuthClientProtocol",
    "TeamsToken",
    "TeamsUser",
    "TeamsTenant",
    "TeamsBridgeDaemon",
    "SessionData",
    "SessionManager",
    "SessionStore",
]
