#!/usr/bin/env bash
# Open Targets Platform MCP (Apache-2.0), official. https://github.com/opentargets/open-targets-platform-mcp
# Pinned: git 742f7ef (reviewed 2026-11-10; tools are read-only GraphQL queries against the public API).
# Installed in its own venv because upstream pins fastmcp==2.13.3 (the proxy uses a newer fastmcp).
set -euo pipefail
OT_REF="${OT_REF:-742f7ef}"
uv venv --python 3.12 /opt/otp
uv pip install --python /opt/otp/bin/python "git+https://github.com/opentargets/open-targets-platform-mcp@${OT_REF}"
/opt/otp/bin/otp-mcp --version
