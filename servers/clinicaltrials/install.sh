#!/usr/bin/env bash
# Build-time install for the in-house ClinicalTrials.gov server (deps already in the proxy image).
set -euo pipefail
pip install --no-cache-dir "mcp>=1.10"
python -c "import ast,sys; ast.parse(open('/app/server/ctgov_mcp.py').read())"
