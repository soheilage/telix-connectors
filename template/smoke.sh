#!/usr/bin/env bash
# Smoke test a deployed connector with your own identity token: initialize + tools/list.
# Usage: template/smoke.sh <server>   (prints tool names; writes servers/<server>/tools.json)
set -euo pipefail
SERVER="${1:?usage: smoke.sh <server-name>}"
PROJECT_ID="${PROJECT_ID:?set PROJECT_ID to the Telix GCP project that hosts the Gemini Enterprise app}"
REGION="${REGION:-europe-west4}"
SERVICE="mcp-${SERVER}"
URL="$(gcloud run services describe "${SERVICE}" --region="${REGION}" --project="${PROJECT_ID}" --format='value(status.url)')"
TESTER="${TESTER:-mcp-tester@${PROJECT_ID}.iam.gserviceaccount.com}"   # created by deploy.sh
TOKEN="$(gcloud auth print-identity-token --impersonate-service-account="${TESTER}" --audiences="${URL}" --include-email 2>/dev/null)"
H=(-H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" -H "Accept: application/json, text/event-stream")

echo "== health"; curl -s -o /dev/null -w "HTTP %{http_code}\n" "${H[@]}" "${URL}/healthz" || true
echo "== initialize"
RESP="$(curl -fsS -D /tmp/mcp_hdr "${H[@]}" "${URL}/mcp" -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"smoke","version":"0.1"}}}')"
SID="$(grep -i '^mcp-session-id:' /tmp/mcp_hdr | awk '{print $2}' | tr -d '\r')"
echo "${RESP}" | sed 's/^data: //' | grep -m1 '{' | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["result"]["serverInfo"])'
curl -fsS "${H[@]}" -H "Mcp-Session-Id: ${SID}" "${URL}/mcp" -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' >/dev/null
echo "== tools/list"
curl -fsS "${H[@]}" -H "Mcp-Session-Id: ${SID}" "${URL}/mcp" -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  | sed 's/^data: //' | grep -m1 '{' | python3 -c '
import sys,json,pathlib
d=json.load(sys.stdin)["result"]; tools=[{k:v for k,v in t.items() if k!="_meta"} for t in d["tools"]]
print(f"{len(tools)} tools:"); [print(" -", t["name"]) for t in tools]
# Agent Registry tool-spec is capped at 10 KB: keep full spec if it fits, else a compact one (name, 1-line description,
# annotations, schema with descriptions stripped); if still too big, write no spec (register.sh falls back to no-spec).
def compact(t):
    sch=json.loads(json.dumps(t.get("inputSchema",{})))
    def strip(o):
        if isinstance(o,dict):
            o.pop("description",None); [strip(v) for v in o.values()]
        elif isinstance(o,list): [strip(v) for v in o]
        return o
    return {"name":t["name"],"description":(t.get("description") or "").strip().split("\n")[0][:200],
            "inputSchema":strip(sch),**({"annotations":t["annotations"]} if t.get("annotations") else {})}
out=pathlib.Path("servers/'"${SERVER}"'/tools.json")
for cand,label in ((tools,"full"),([compact(t) for t in tools],"compact")):
    body=json.dumps({"tools":cand},separators=(",",":"))
    if len(body.encode())<=10000:
        out.write_text(body); print(f"wrote {out} ({label}, {len(body)} bytes) for Agent Registry tool-spec"); break
else:
    out.unlink(missing_ok=True); print("tool spec >10 KB even when compacted; register.sh will use no-spec")'
