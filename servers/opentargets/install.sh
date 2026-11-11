#!/usr/bin/env bash
# Open Targets Platform MCP (Apache-2.0). Source: https://github.com/opentargets/platform-mcp
# TODO(phase 2): pin to a commit SHA after review.
set -euo pipefail
OT_REF="${OT_REF:-main}"
pip install --no-cache-dir "git+https://github.com/opentargets/platform-mcp@${OT_REF}"
