#!/usr/bin/env bash
# Register a deployed connector in Agent Registry (manual Service -> projected McpServer).
# Usage: template/register.sh <server>
set -euo pipefail
SERVER="${1:?usage: register.sh <server-name>}"
PROJECT_ID="${PROJECT_ID:-eg-telix}"
REGION="${REGION:-europe-west4}"
REGISTRY_LOCATION="${REGISTRY_LOCATION:-eu}"     # registry metadata residency (eu|global|region)
SERVICE="mcp-${SERVER}"
URL="$(gcloud run services describe "${SERVICE}" --region="${REGION}" --project="${PROJECT_ID}" --format='value(status.url)')"
DESC="$(sed -n 's/^DESCRIPTION=//p' "servers/${SERVER}/server.env" | tr -d '"')"
TOOLS_FILE="servers/${SERVER}/tools.json"

ARGS=(agent-registry services create "${SERVICE}"
  --project="${PROJECT_ID}" --location="${REGISTRY_LOCATION}"
  --display-name="Telix ${SERVER} MCP"
  --description="${DESC:-Public-data MCP connector (${SERVER}) for Telix Gemini Enterprise PoC. Read-only.}"
  --interfaces="url=${URL}/mcp,protocolBinding=jsonrpc")

if [[ -f "${TOOLS_FILE}" ]]; then
  ARGS+=(--mcp-server-spec-type=tool-spec --mcp-server-spec-content="$(cat "${TOOLS_FILE}")")
else
  ARGS+=(--mcp-server-spec-type=no-spec)
fi

echo "gcloud ${ARGS[*]}"
gcloud "${ARGS[@]}"
echo
gcloud agent-registry mcp-servers list --project="${PROJECT_ID}" --location="${REGISTRY_LOCATION}" 2>/dev/null || true
