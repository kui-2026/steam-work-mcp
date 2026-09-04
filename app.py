"""Run steam-mcp as a stateless Streamable HTTP service for ChatGPT Work."""

from __future__ import annotations

import os
from pathlib import Path


def _load_env_file() -> None:
    env_file = Path(__file__).with_name(".env")
    if not env_file.is_file():
        return
    for raw_line in env_file.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        name, value = line.split("=", 1)
        name = name.strip()
        if name:
            os.environ.setdefault(name, value.strip())


_load_env_file()

from steam_mcp.server import mcp  # noqa: E402


def _port() -> int:
    raw = os.getenv("MCP_PORT", "4100")
    try:
        port = int(raw)
    except ValueError as exc:
        raise SystemExit("MCP_PORT must be an integer") from exc
    if not 1 <= port <= 65535:
        raise SystemExit("MCP_PORT must be between 1 and 65535")
    return port


def _path() -> str:
    path = os.getenv("MCP_PATH", "/mcp").strip()
    if not path.startswith("/"):
        path = "/" + path
    return path.rstrip("/") or "/mcp"


def main() -> None:
    mcp.run(
        transport="streamable-http",
        host=os.getenv("MCP_HOST", "127.0.0.1"),
        port=_port(),
        streamable_http_path=_path(),
        stateless_http=True,
        json_response=True,
        max_request_body_size=1_048_576,
    )


if __name__ == "__main__":
    main()
