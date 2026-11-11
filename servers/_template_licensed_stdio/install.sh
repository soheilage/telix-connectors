#!/usr/bin/env bash
# Licensed source, self-hosted stdio (mode A): e.g. PatSnap official MCP (Apache-2.0).
# Source: https://github.com/patsnap/mcp  - TODO pin SHA; credentials via secrets.txt.
set -euo pipefail
PATSNAP_REF="${PATSNAP_REF:-main}"
pip install --no-cache-dir "git+https://github.com/patsnap/mcp@${PATSNAP_REF}"
