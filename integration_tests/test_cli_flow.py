"""End-to-end integration tests for the CLI client against the dockerised backend."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any, Dict, Optional

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
DOCKER_COMPOSE_FILE = REPO_ROOT / "docker-compose.yml"
LIBMSGR_PACKAGE_DIR = REPO_ROOT / "flutter_frontend" / "packages" / "libmsgr"
DEFAULT_TIMEOUT = 180


def _http_request(
    method: str,
    url: str,
    *,
    data: Optional[Dict[str, Any]] = None,
    headers: Optional[Dict[str, str]] = None,
    timeout: int = 15,
) -> Dict[str, Any]:
    body: Optional[bytes] = None
    if data is not None:
        body = json.dumps(data).encode("utf-8")
    request = urllib.request.Request(url, data=body, method=method.upper())
    request.add_header("Accept", "application/json")
    if data is not None:
        request.add_header("Content-Type", "application/json")
    if headers:
        for key, value in headers.items():
            request.add_header(key, value)

    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            payload = response.read()
            if not payload:
                return {}
            return json.loads(payload.decode("utf-8"))
    except urllib.error.HTTPError as exc:  # pragma: no cover - integration behaviour
        details = exc.read().decode("utf-8", errors="replace")
        raise AssertionError(
            f"HTTP {exc.code} for {method} {url}: {details}"
        ) from exc


def _wait_for_http(url: str, *, timeout: int = DEFAULT_TIMEOUT) -> None:
    start = time.time()
    last_error: Optional[Exception] = None
    while time.time() - start < timeout:
        try:
            request = urllib.request.Request(url, method="GET")
            with urllib.request.urlopen(request, timeout=5) as response:
                if response.status in {200, 201, 202, 400, 401, 403, 404}:
                    return
        except Exception as exc:  # pragma: no cover - integration behaviour
            last_error = exc
            time.sleep(2)
    raise TimeoutError(f"Timed out waiting for {url}") from last_error


@pytest.fixture(scope="session")
def backend_stack() -> Dict[str, Any]:
    if shutil.which("docker") is None:
        pytest.skip("Docker is required to run the integration backend stack")

    env = os.environ.copy()
    env.setdefault("MSGR_WEB_LEGACY_ACTOR_HEADERS", "true")

    up_cmd = [
        "docker",
        "compose",
        "-f",
        str(DOCKER_COMPOSE_FILE),
        "up",
        "-d",
        "db",
        "stonemq",
        "backend",
    ]
    subprocess.run(up_cmd, check=True, cwd=REPO_ROOT, env=env)

    try:
        _wait_for_http("http://auth.7f000001.nip.io:4080/", timeout=DEFAULT_TIMEOUT)
        yield {"env": env}
    finally:
        down_cmd = [
            "docker",
            "compose",
            "-f",
            str(DOCKER_COMPOSE_FILE),
            "down",
            "--volumes",
        ]
        subprocess.run(down_cmd, check=False, cwd=REPO_ROOT, env=env)


def _run_cli_flow(env: Dict[str, str]) -> Dict[str, Any]:
    if shutil.which("dart") is None:
        pytest.skip("Dart SDK is required to run the CLI integration flow")

    subprocess.run(["dart", "pub", "get"], check=True, cwd=LIBMSGR_PACKAGE_DIR, env=env)

    process = subprocess.run(
        ["dart", "run", "tool/integration_flow.dart"],
        check=True,
        cwd=LIBMSGR_PACKAGE_DIR,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    stdout = process.stdout.strip().splitlines()
    if not stdout:
        raise AssertionError("integration_flow.dart produced no output")

    try:
        return json.loads(stdout[-1])
    except json.JSONDecodeError as exc:  # pragma: no cover - defensive
        raise AssertionError(
            "Failed to parse integration flow output as JSON."
        ) from exc


@pytest.mark.integration
@pytest.mark.usefixtures("backend_stack")
def test_cli_can_register_login_and_exchange_messages(backend_stack: Dict[str, Any]) -> None:
    env = backend_stack["env"]
    flow_output = _run_cli_flow(env)

    required_keys = {
        "email",
        "userId",
        "teamId",
        "teamName",
        "profileId",
        "teamAccessToken",
        "teamHost",
    }
    missing = required_keys.difference(flow_output.keys())
    assert not missing, f"integration flow output missing keys: {missing}"

    team_host = flow_output["teamHost"]
    team_base = f"http://{team_host}"
    conversation_body = {
        "kind": "channel",
        "topic": "Integration Test Channel",
        "participant_ids": [flow_output["profileId"]],
        "structure_type": "channel",
    }

    auth_headers = {
        "Authorization": f"Bearer {flow_output['teamAccessToken']}",
        "X-Account-Id": flow_output["userId"],
        "X-Profile-Id": flow_output["profileId"],
    }

    conversation_response = _http_request(
        "POST",
        f"{team_base}/api/conversations",
        data=conversation_body,
        headers=auth_headers,
    )

    conversation_id = conversation_response.get("data", {}).get("id")
    assert conversation_id, "Conversation creation did not return an ID"

    message_body = {
        "message": {
            "kind": "text",
            "body": "Hello from the integration suite",
        }
    }

    _http_request(
        "POST",
        f"{team_base}/api/conversations/{conversation_id}/messages",
        data=message_body,
        headers=auth_headers,
    )

    history = _http_request(
        "GET",
        f"{team_base}/api/conversations/{conversation_id}/messages",
        headers=auth_headers,
    )

    messages = history.get("data", [])
    assert any(msg.get("body") == "Hello from the integration suite" for msg in messages), (
        "Expected message not found in conversation history"
    )
