#!/usr/bin/env bash
# Smoke test a deployed connector with your own identity token: initialize + tools/list.
# Usage: template/smoke.sh <server>   (prints tool names; writes servers/<server>/tools.json)
set -euo pipefail
SERVER="${1:?usage: smoke.sh <server-name>}"
PROJECT_ID="${PROJECT_ID:-eg-telix}"
REGION="${REGION:-europe-west4}"
SERVICE="mcp-${SERVER}"
URL="$(gcloud run services describe "${SERVICE}" --region="${REGION}" --project="${PROJECT_ID}" --format='value(status.url)')"
TOKEN="$(gcloud auth print-identity-token --audiences="${URL}")"
H=(-H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" -H "Accept: application/json, text/event-stream")

echo "== health";  curl -fsS "${URL}/healthz"; echo
echo "== initialize"
RESP="$(curl -fsS -D /tmp/mcp_hdr "${H[@]}" "${URL}/mcp" -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"smoke","version":"0.1"}}}')"
SID="$(grep -i '^mcp-session-id:' /tmp/mcp_hdr | awk '{print $2}' | tr -d '\r')"
echo "${RESP}" | sed 's/^data: //' | grep -m1 '{' | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["result"]["serverInfo"])'
curl -fsS "${H[@]}" -H "Mcp-Session-Id: ${SID}" "${URL}/mcp" -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' >/dev/null
echo "== tools/list"
curl -fsS "${H[@]}" -H "Mcp-Session-Id: ${SID}" "${URL}/mcp" -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  | sed 's/^data: //' | grep -m1 '{' | python3 -c '
import sys,json,pathlib
d=json.load(sys.stdin)["result"]; tools=d["tools"]
print(f"{len(tools)} tools:"); [print(" -", t["name"]) for t in tools]
pathlib.Path("servers/'"${SERVER}"'/tools.json").write_text(json.dumps({"tools":tools},indent=1)[:9500])
print("wrote servers/'"${SERVER}"'/tools.json (for Agent Registry tool-spec)")'
