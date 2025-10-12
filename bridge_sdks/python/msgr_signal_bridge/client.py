"""Signal client abstractions for the Msgr bridge daemon."""

from __future__ import annotations

import asyncio
import base64
import json
import mimetypes
import os
from io import BytesIO
from dataclasses import dataclass
from pathlib import Path
from typing import Awaitable, Callable, Dict, Mapping, MutableMapping, Optional, Protocol, Sequence
from urllib import error as urlerror
from urllib import parse as urlparse
from urllib import request as urlrequest
from uuid import uuid4

UpdateHandler = Callable[[Mapping[str, object]], Awaitable[None]]


@dataclass(frozen=True)
class LinkingCode:
    """Represents a Signal device-linking code/URI."""

    verification_uri: str
    code: Optional[str] = None
    expires_at: Optional[float] = None
    device_name: Optional[str] = None

    def to_dict(self) -> Mapping[str, object]:
        payload: dict[str, object] = {"verification_uri": self.verification_uri}
        if self.code is not None:
            payload["code"] = self.code
        if self.expires_at is not None:
            payload["expires_at"] = float(self.expires_at)
        if self.device_name:
            payload["device_name"] = self.device_name
        return payload


@dataclass(frozen=True)
class SignalProfile:
    """Subset of Signal profile metadata exposed to Msgr."""

    uuid: str
    phone_number: Optional[str] = None
    display_name: Optional[str] = None

    def to_dict(self) -> Mapping[str, Optional[str]]:
        return {
            "uuid": self.uuid,
            "phone_number": self.phone_number,
            "display_name": self.display_name,
        }


class SignalClientProtocol(Protocol):
    """Protocol describing the client functionality the daemon relies on."""

    async def connect(self) -> None:
        ...

    async def disconnect(self) -> None:
        ...

    async def is_linked(self) -> bool:
        ...

    async def request_linking_code(
        self, *, device_name: Optional[str] = None
    ) -> LinkingCode:
        ...

    async def get_profile(self) -> SignalProfile:
        ...

    async def send_text_message(
        self,
        chat_id: str,
        message: str,
        *,
        attachments: Optional[list[Mapping[str, object]]] = None,
        metadata: Optional[Mapping[str, object]] = None,
    ) -> Mapping[str, object]:
        ...

    def add_event_handler(self, handler: UpdateHandler) -> None:
        ...

    def remove_event_handler(self, handler: UpdateHandler) -> None:
        ...

    async def acknowledge_event(self, event_id: str) -> None:
        ...

    async def list_contacts(self) -> Sequence[Mapping[str, object]]:
        ...

    async def list_conversations(self) -> Sequence[Mapping[str, object]]:
        ...

    async def describe_capabilities(self) -> Mapping[str, object]:
        ...


def encode_session_blob(data: bytes) -> str:
    """Encode a raw session blob into a base64 transport format."""

    return base64.b64encode(data).decode("ascii")


def decode_session_blob(blob: Optional[str]) -> Optional[bytes]:
    """Decode a base64 session string."""

    if blob is None:
        return None
    return base64.b64decode(blob.encode("ascii"))


@dataclass(frozen=True)
class HttpResponse:
    """Represents a low-level HTTP response returned by the transport."""

    status: int
    body: bytes
    headers: Mapping[str, str]


class HttpTransport(Protocol):
    """Protocol describing the HTTP transport used by the REST client."""

    async def request(
        self,
        method: str,
        path: str,
        *,
        params: Optional[Mapping[str, object]] = None,
        json_body: Optional[Mapping[str, object]] = None,
        data: Optional[bytes] = None,
        headers: Optional[Mapping[str, str]] = None,
    ) -> HttpResponse:
        ...


class UrlLibTransport:
    """HTTP transport backed by urllib executed inside worker threads."""

    def __init__(self, base_url: str, *, timeout: float = 30.0) -> None:
        self._base_url = base_url.rstrip("/")
        self._timeout = timeout

    async def request(
        self,
        method: str,
        path: str,
        *,
        params: Optional[Mapping[str, object]] = None,
        json_body: Optional[Mapping[str, object]] = None,
        data: Optional[bytes] = None,
        headers: Optional[Mapping[str, str]] = None,
    ) -> HttpResponse:
        return await asyncio.to_thread(
            self._execute_request, method.upper(), path, params, json_body, data, headers
        )

    def _execute_request(
        self,
        method: str,
        path: str,
        params: Optional[Mapping[str, object]],
        json_body: Optional[Mapping[str, object]],
        data: Optional[bytes],
        headers: Optional[Mapping[str, str]],
    ) -> HttpResponse:
        query = f"?{urlparse.urlencode(params)}" if params else ""
        url = f"{self._base_url}{path}{query}"
        body: Optional[bytes] = data
        header_map = {"Content-Type": "application/json"}
        if headers:
            header_map.update(headers)
        if json_body is not None:
            if body is not None:
                raise ValueError("cannot provide both json_body and raw data")
            body = json.dumps(json_body).encode("utf-8")

        request = urlrequest.Request(url, data=body, method=method)
        for header, value in header_map.items():
            request.add_header(header, value)

        try:
            with urlrequest.urlopen(request, timeout=self._timeout) as response:
                body = response.read()
                return HttpResponse(
                    status=response.getcode(),
                    body=body,
                    headers=dict(response.headers.items()),
                )
        except urlerror.HTTPError as exc:
            body = exc.read() if exc.fp is not None else b""
            headers = dict(getattr(exc, "headers", {}) or {})
            return HttpResponse(status=exc.code, body=body, headers=headers)


class SignalServiceError(RuntimeError):
    """Raised when the Signal REST API reports an unexpected error."""


class SignalRestClient(SignalClientProtocol):
    """Signal client that talks to the `signal-cli-rest-api` service."""

    def __init__(
        self,
        account: str,
        *,
        base_url: Optional[str] = None,
        transport: Optional[HttpTransport] = None,
        session_path: Optional[Path] = None,
        receive_timeout: int = 25,
        poll_interval: float = 1.0,
    ) -> None:
        if transport is None:
            if base_url is None:
                raise ValueError("base_url is required when no transport is provided")
            transport = UrlLibTransport(base_url)

        self._transport = transport
        self._account = account
        self._session_path = (session_path or Path("signal_sessions") / account).with_suffix(
            ".json"
        )
        self._session_path.parent.mkdir(parents=True, exist_ok=True)
        self._receive_timeout = receive_timeout
        self._poll_interval = poll_interval
        self._handlers: Dict[UpdateHandler, UpdateHandler] = {}
        self._poll_task: Optional[asyncio.Task[None]] = None
        self._stop_event = asyncio.Event()
        self._session_cache: Dict[str, object] = {}

    async def connect(self) -> None:
        await self._load_session()
        self._stop_event.clear()

    async def disconnect(self) -> None:
        self._stop_event.set()
        if self._poll_task is not None:
            await self._poll_task
            self._poll_task = None
        self._handlers.clear()

    async def is_linked(self) -> bool:
        response = await self._transport.request(
            "GET", f"/v1/accounts/{self._account}", params=None
        )
        if response.status == 200:
            payload = _safe_json(response.body)
            if isinstance(payload, MutableMapping):
                self._session_cache.update(payload)
                await self._persist_session()
            return True
        if response.status == 404:
            return False
        raise SignalServiceError(
            f"failed to determine link status for {self._account}: {response.status}"
        )

    async def request_linking_code(
        self, *, device_name: Optional[str] = None
    ) -> LinkingCode:
        payload: Dict[str, object] = {}
        if device_name:
            payload["device_name"] = device_name

        response = await self._transport.request(
            "POST",
            f"/v1/accounts/{self._account}/link",
            json_body=payload,
        )
        if response.status != 200:
            raise SignalServiceError(
                f"link request for {self._account} failed with status {response.status}"
            )

        body = _safe_json(response.body)
        if not isinstance(body, Mapping):
            raise SignalServiceError("link response payload was not a mapping")

        verification_uri = str(
            body.get("verification_uri")
            or body.get("linkingUri")
            or body.get("link_uri")
            or body.get("uri")
            or ""
        )
        code = body.get("code") or body.get("verification_code") or body.get("verificationCode")
        expires = body.get("expires_at") or body.get("expiration")

        return LinkingCode(
            verification_uri=verification_uri,
            code=str(code) if code else None,
            expires_at=float(expires) if isinstance(expires, (int, float)) else None,
            device_name=device_name,
        )

    async def get_profile(self) -> SignalProfile:
        response = await self._transport.request(
            "GET", f"/v1/accounts/{self._account}/profile"
        )
        if response.status != 200:
            raise SignalServiceError(
                f"failed to fetch profile for {self._account}: {response.status}"
            )
        payload = _safe_json(response.body)
        if not isinstance(payload, Mapping):
            raise SignalServiceError("profile payload was not a mapping")

        uuid = str(payload.get("uuid") or payload.get("id") or "")
        profile = SignalProfile(
            uuid=uuid,
            phone_number=str(payload.get("number") or payload.get("phone_number") or self._account),
            display_name=payload.get("name") or payload.get("display_name"),
        )
        self._session_cache.update({"uuid": profile.uuid, "phone_number": profile.phone_number})
        await self._persist_session()
        return profile

    async def send_text_message(
        self,
        chat_id: str,
        message: str,
        *,
        attachments: Optional[list[Mapping[str, object]]] = None,
        metadata: Optional[Mapping[str, object]] = None,
    ) -> Mapping[str, object]:
        payload: Dict[str, object] = {
            "recipient": chat_id,
            "message": message,
            "account": self._account,
        }
        if attachments:
            attachment_ids: list[str] = []
            for attachment in attachments:
                attachment_id: Optional[str] = None
                if isinstance(attachment, Mapping):
                    attachment_id = _preuploaded_attachment_id(attachment)
                    if attachment_id is None:
                        attachment_id = await self._upload_attachment(attachment)
                elif isinstance(attachment, str):
                    attachment_id = attachment
                if attachment_id is not None:
                    attachment_ids.append(str(attachment_id))
            if attachment_ids:
                payload["attachments"] = attachment_ids
        if metadata:
            payload["metadata"] = metadata

        response = await self._transport.request(
            "POST", "/v1/messages", json_body=payload
        )
        if response.status not in (200, 201):
            raise SignalServiceError(
                f"failed to send message for {self._account}: {response.status}"
            )
        body = _safe_json(response.body)
        result: Dict[str, object] = {"chat_id": chat_id}
        if isinstance(body, Mapping):
            if "timestamp" in body:
                result["timestamp"] = body["timestamp"]
            if "message_id" in body:
                result["message_id"] = body["message_id"]
        return result

    async def _upload_attachment(
        self, attachment: Mapping[str, object]
    ) -> Optional[str]:
        data = _attachment_bytes(attachment)
        if data is None:
            return None

        filename = _attachment_filename(attachment)
        content_type = _attachment_content_type(attachment)

        boundary = f"----MsgrSignalBoundary{uuid4().hex}"
        body = BytesIO()
        body.write(f"--{boundary}\r\n".encode("utf-8"))
        body.write(
            (
                f'Content-Disposition: form-data; name="file"; filename="{filename}"\r\n'
                f"Content-Type: {content_type}\r\n\r\n"
            ).encode("utf-8")
        )
        body.write(data)
        body.write("\r\n".encode("utf-8"))
        body.write(f"--{boundary}--\r\n".encode("utf-8"))

        response = await self._transport.request(
            "POST",
            "/v1/attachments",
            data=body.getvalue(),
            headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        )

        if response.status not in (200, 201):
            raise SignalServiceError(
                f"failed to upload attachment for {self._account}: {response.status}"
            )

        payload = _safe_json(response.body)
        if isinstance(payload, Mapping):
            for key in ("id", "attachmentId", "attachment_id", "attachment"):
                if key in payload:
                    return str(payload[key])
        raise SignalServiceError("attachment upload did not return an identifier")

    def add_event_handler(self, handler: UpdateHandler) -> None:
        self._handlers[handler] = handler
        if self._poll_task is None or self._poll_task.done():
            self._stop_event.clear()
            self._poll_task = asyncio.create_task(self._poll_updates())

    def remove_event_handler(self, handler: UpdateHandler) -> None:
        self._handlers.pop(handler, None)
        if not self._handlers:
            self._stop_event.set()

    async def acknowledge_event(self, event_id: str) -> None:
        await self._transport.request(
            "DELETE", f"/v1/receive/{self._account}/{event_id}"
        )

    async def list_contacts(self) -> Sequence[Mapping[str, object]]:
        contacts = self._session_cache.get("contacts")
        if isinstance(contacts, Sequence):
            return [dict(entry) for entry in contacts if isinstance(entry, Mapping)]
        return []

    async def list_conversations(self) -> Sequence[Mapping[str, object]]:
        conversations = self._session_cache.get("conversations")
        if isinstance(conversations, Sequence):
            return [dict(entry) for entry in conversations if isinstance(entry, Mapping)]
        return []

    async def describe_capabilities(self) -> Mapping[str, object]:
        return {
            "messaging": {
                "text": True,
                "attachments": ["image", "video", "audio", "file"],
                "reactions": True,
            },
            "presence": {"typing": True, "read_receipts": True},
        }

    async def _poll_updates(self) -> None:
        try:
            while not self._stop_event.is_set():
                if not self._handlers:
                    await asyncio.sleep(self._poll_interval)
                    continue

                response = await self._transport.request(
                    "GET",
                    f"/v1/receive/{self._account}",
                    params={"timeout": self._receive_timeout},
                )

                if response.status == 204:
                    continue

                if response.status >= 400:
                    await asyncio.sleep(self._poll_interval)
                    continue

                payload = _safe_json(response.body)
                if not isinstance(payload, list):
                    await asyncio.sleep(self._poll_interval)
                    continue

                for entry in payload:
                    event = _normalise_event(entry)
                    if event is None:
                        continue
                    for handler in list(self._handlers):
                        try:
                            await handler(event)
                        except Exception:  # pragma: no cover - defensive
                            continue
        finally:
            self._poll_task = None

    async def _load_session(self) -> None:
        if not self._session_path.exists():
            self._session_cache = {}
            return
        data = await asyncio.to_thread(self._session_path.read_text, encoding="utf-8")
        try:
            cached = json.loads(data)
        except json.JSONDecodeError:
            self._session_cache = {}
            return
        if isinstance(cached, dict):
            self._session_cache = cached
        else:
            self._session_cache = {}

    async def _persist_session(self) -> None:
        await asyncio.to_thread(
            self._session_path.write_text,
            json.dumps(self._session_cache, ensure_ascii=False, sort_keys=True),
            encoding="utf-8",
        )


def _attachment_bytes(attachment: Mapping[str, object]) -> Optional[bytes]:
    if "data" in attachment:
        raw = attachment["data"]
        if isinstance(raw, bytes):
            return raw
        if isinstance(raw, str):
            try:
                return base64.b64decode(raw.encode("ascii"))
            except (ValueError, UnicodeEncodeError):
                return raw.encode("utf-8")
    path_value = attachment.get("path") or attachment.get("file")
    if isinstance(path_value, (str, os.PathLike)):
        path = Path(path_value)
        if path.exists():
            return path.read_bytes()
    return None


def _preuploaded_attachment_id(attachment: Mapping[str, object]) -> Optional[str]:
    for key in ("id", "attachment", "attachment_id", "attachmentId"):
        value = attachment.get(key)
        if isinstance(value, (str, int)):
            return str(value)
    return None


def _attachment_filename(attachment: Mapping[str, object]) -> str:
    name = attachment.get("filename") or attachment.get("name")
    if isinstance(name, str) and name:
        return name
    path_value = attachment.get("path") or attachment.get("file")
    if isinstance(path_value, (str, os.PathLike)):
        return Path(path_value).name
    return "attachment.bin"


def _attachment_content_type(attachment: Mapping[str, object]) -> str:
    content_type = attachment.get("content_type") or attachment.get("mime_type")
    if isinstance(content_type, str) and content_type:
        return content_type
    filename = _attachment_filename(attachment)
    guess, _ = mimetypes.guess_type(filename)
    return guess or "application/octet-stream"


def _safe_json(body: bytes) -> object:
    if not body:
        return {}
    try:
        return json.loads(body.decode("utf-8"))
    except json.JSONDecodeError:
        return {}


def _normalise_event(payload: object) -> Optional[Dict[str, object]]:
    if not isinstance(payload, Mapping):
        return None
    envelope = payload.get("envelope")
    if isinstance(envelope, Mapping):
        payload = envelope

    timestamp = payload.get("timestamp")
    source = payload.get("sourceNumber") or payload.get("source")
    if timestamp is None or source is None:
        return None

    data_message = payload.get("dataMessage") or payload.get("data_message")
    message_text: Optional[str] = None
    attachments: Optional[object] = None
    if isinstance(data_message, Mapping):
        message_text = data_message.get("message")
        if message_text is None:
            message_text = data_message.get("body")
        attachments = data_message.get("attachments")
        group_info = data_message.get("groupInfo") or data_message.get("group_info")
        if isinstance(group_info, Mapping):
            source = group_info.get("groupId") or group_info.get("id") or source

    if message_text is None:
        return None

    event: Dict[str, object] = {
        "event_id": str(timestamp),
        "chat_id": str(source),
        "message": message_text,
        "timestamp": timestamp,
    }
    if attachments:
        event["attachments"] = attachments
    return event
