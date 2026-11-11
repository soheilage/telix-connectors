"""Generic MCP connector wrapper for Gemini Enterprise.

Exposes an upstream MCP server (stdio *or* remote streamable-HTTP) as a
Google-authenticated streamable-HTTP endpoint at /mcp, suitable for
registration as a Gemini Enterprise "Custom MCP Server" (auth: Google caller
token) and for Agent Registry.

Configuration (env):
  SERVER_NAME         Display name (default: mcp-connector)
  UPSTREAM_CMD        stdio upstream, e.g. "npx -y pubcrawl"        (mode A)
  UPSTREAM_URL        remote upstream, e.g. https://api.x.com/mcp   (mode B)
  UPSTREAM_TOKEN      bearer token for mode B (from Secret Manager)
  UPSTREAM_HEADERS    JSON object of extra headers for mode B
  AUDIENCE            Expected ID-token audience (the Cloud Run service URL)
  ALLOWED_PRINCIPALS  Comma-separated SA emails allowed to call (optional)
  REQUIRE_AUTH        "true" (default) | "false" for local testing
  PORT                default 8080
"""

from __future__ import annotations

import json
import logging
import os
import shlex

from fastmcp import FastMCP
from fastmcp.client.transports import StdioTransport, StreamableHttpTransport
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token
from starlette.middleware import Middleware
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s %(message)s")
log = logging.getLogger("mcp-connector")

SERVER_NAME = os.environ.get("SERVER_NAME", "mcp-connector")
# Comma-separated list; Cloud Run exposes two URL forms (deterministic + legacy), accept both.
AUDIENCES = [a.strip() for a in os.environ.get("AUDIENCE", "").split(",") if a.strip()]
REQUIRE_AUTH = os.environ.get("REQUIRE_AUTH", "true").lower() == "true"
ALLOWED = {p.strip() for p in os.environ.get("ALLOWED_PRINCIPALS", "").split(",") if p.strip()}
_PUBLIC_PATHS = {"/healthz"}


class GoogleIdTokenAuth(BaseHTTPMiddleware):
    """Verify a Google-signed OIDC ID token (what Gemini Enterprise / Cloud Run send)."""

    async def dispatch(self, request: Request, call_next):
        if request.url.path in _PUBLIC_PATHS or not REQUIRE_AUTH:
            return await call_next(request)
        auth = request.headers.get("authorization", "")
        if not auth.lower().startswith("bearer "):
            return JSONResponse({"error": "missing bearer token"}, status_code=401)
        try:
            claims = id_token.verify_oauth2_token(auth.split(" ", 1)[1], google_requests.Request())
            aud = claims.get("aud")
            if AUDIENCES and aud not in AUDIENCES:
                raise ValueError(f"audience {aud!r} not in {AUDIENCES}")
        except Exception as exc:  # noqa: BLE001
            log.warning("token rejected: %s", exc)
            return JSONResponse({"error": "invalid token"}, status_code=401)
        caller = claims.get("email", "")
        if ALLOWED and caller not in ALLOWED:
            log.warning("forbidden caller %s", caller)
            return JSONResponse({"error": "forbidden"}, status_code=403)
        request.state.caller = caller
        return await call_next(request)


def _build_transport():
    cmd = os.environ.get("UPSTREAM_CMD")
    url = os.environ.get("UPSTREAM_URL")
    if cmd and url:
        raise RuntimeError("Set only one of UPSTREAM_CMD or UPSTREAM_URL")
    if cmd:
        parts = shlex.split(cmd)
        log.info("mode A (stdio): %s", cmd)
        return StdioTransport(command=parts[0], args=parts[1:], env=dict(os.environ))
    if url:
        headers = json.loads(os.environ.get("UPSTREAM_HEADERS", "{}"))
        if tok := os.environ.get("UPSTREAM_TOKEN"):
            headers.setdefault("Authorization", f"Bearer {tok}")
        log.info("mode B (remote http): %s", url)
        return StreamableHttpTransport(url=url, headers=headers)
    raise RuntimeError("Set UPSTREAM_CMD (stdio) or UPSTREAM_URL (remote)")


mcp = FastMCP.as_proxy(_build_transport(), name=SERVER_NAME)


@mcp.custom_route("/healthz", methods=["GET"])
async def healthz(_: Request):
    return JSONResponse({"status": "ok", "server": SERVER_NAME})


app = mcp.http_app(path="/mcp", middleware=[Middleware(GoogleIdTokenAuth)])

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
