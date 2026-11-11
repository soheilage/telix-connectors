#!/usr/bin/env bash
# Local end-to-end test: proxy (mode A) + ClinicalTrials.gov server; then auth rejection check.
set -u
cd "$(dirname "$0")/.."; . .venv/bin/activate
PORT=8089
REQUIRE_AUTH=false PORT=$PORT UPSTREAM_CMD="python servers/clinicaltrials/ctgov_mcp.py" nohup python template/proxy/server.py > /tmp/mcp_proxy.log 2>&1 &
P1=$!; sleep 7
echo "== health"; curl -fsS http://localhost:$PORT/healthz; echo
echo "== client"; python tests/local_client.py http://localhost:$PORT/mcp 2>&1 | grep -v -i deprecat
kill $P1; sleep 1
REQUIRE_AUTH=true AUDIENCE=http://localhost:$PORT PORT=$PORT UPSTREAM_CMD="python servers/clinicaltrials/ctgov_mcp.py" nohup python template/proxy/server.py > /tmp/mcp_proxy2.log 2>&1 &
P2=$!; sleep 7
curl -s -o /dev/null -w "== auth: no-token -> HTTP %{http_code}\n" -X POST http://localhost:$PORT/mcp -H 'Content-Type: application/json' -d '{}'
curl -s -o /dev/null -w "== auth: bad-token -> HTTP %{http_code}\n" -X POST http://localhost:$PORT/mcp -H 'Authorization: Bearer abc' -H 'Content-Type: application/json' -d '{}'
kill $P2
