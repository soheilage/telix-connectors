#!/usr/bin/env bash
# Deploy one connector to Cloud Run (private, EU, dedicated SA).
# Usage: template/deploy.sh <server> [--allow-caller SA_EMAIL]...
set -euo pipefail

SERVER="${1:?usage: deploy.sh <server-name> [--allow-caller SA]...}"; shift || true
PROJECT_ID="${PROJECT_ID:-eg-telix}"
REGION="${REGION:-europe-west4}"
REPO="${REPO:-mcp-connectors}"
SERVICE="mcp-${SERVER}"
SA_NAME="mcp-${SERVER}"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
SRV_DIR="servers/${SERVER}"

CALLERS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-caller) CALLERS+=("$2"); shift 2 ;;
    *) echo "unknown arg $1" >&2; exit 1 ;;
  esac
done

[[ -f "${SRV_DIR}/server.env" && -f "${SRV_DIR}/install.sh" ]] || { echo "missing ${SRV_DIR}/{server.env,install.sh}" >&2; exit 1; }

echo "== ${SERVICE} -> ${PROJECT_ID}/${REGION}"
gcloud config set project "${PROJECT_ID}" >/dev/null

echo "== APIs"
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com \
  secretmanager.googleapis.com agentregistry.googleapis.com iam.googleapis.com --quiet

echo "== Artifact Registry"
gcloud artifacts repositories describe "${REPO}" --location="${REGION}" >/dev/null 2>&1 || \
  gcloud artifacts repositories create "${REPO}" --location="${REGION}" --repository-format=docker \
    --description="Telix MCP connectors" --quiet

echo "== Service account"
gcloud iam service-accounts describe "${SA_EMAIL}" >/dev/null 2>&1 || \
  gcloud iam service-accounts create "${SA_NAME}" --display-name="MCP connector ${SERVER}" --quiet

echo "== Build"
SHORT_SHA="$(git rev-parse --short HEAD 2>/dev/null || date +%s)"
gcloud builds submit --config template/cloudbuild.yaml \
  --substitutions="_SERVER=${SERVER},_REGION=${REGION},_REPO=${REPO},SHORT_SHA=${SHORT_SHA}" --quiet
IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO}/${SERVER}:${SHORT_SHA}"

echo "== Secrets"
SECRET_FLAGS=()
if [[ -f "${SRV_DIR}/secrets.txt" ]]; then
  # format per line: ENV_VAR=secret-name   (secret must already exist in Secret Manager)
  while IFS='=' read -r var secret; do
    [[ -z "${var}" || "${var}" =~ ^# ]] && continue
    gcloud secrets add-iam-policy-binding "${secret}" --member="serviceAccount:${SA_EMAIL}" \
      --role=roles/secretmanager.secretAccessor --quiet >/dev/null
    SECRET_FLAGS+=("--set-secrets=${var}=${secret}:latest")
  done < "${SRV_DIR}/secrets.txt"
fi

echo "== Deploy"
gcloud run deploy "${SERVICE}" \
  --image="${IMAGE}" --region="${REGION}" --platform=managed \
  --service-account="${SA_EMAIL}" \
  --no-allow-unauthenticated --ingress=all \
  --port=8080 --cpu=1 --memory=1Gi --min-instances=0 --max-instances=3 --timeout=300 \
  --set-env-vars="SERVER_NAME=${SERVER},REQUIRE_AUTH=true" \
  --labels="app=mcp-connector,server=${SERVER},owner=telix-poc" \
  "${SECRET_FLAGS[@]}" --quiet

URL="$(gcloud run services describe "${SERVICE}" --region="${REGION}" --format='value(status.url)')"

echo "== Pin audience to service URL"
gcloud run services update "${SERVICE}" --region="${REGION}" --update-env-vars="AUDIENCE=${URL}" --quiet

echo "== Invoker grants"
for c in "${CALLERS[@]}"; do
  gcloud run services add-iam-policy-binding "${SERVICE}" --region="${REGION}" \
    --member="serviceAccount:${c}" --role=roles/run.invoker --quiet >/dev/null
done

cat <<EOF

DONE  ${SERVICE}
  URL:        ${URL}/mcp
  Health:     ${URL}/healthz
  Image:      ${IMAGE}
  Runtime SA: ${SA_EMAIL}
  Smoke test: template/smoke.sh ${SERVER}
  Register:   template/register.sh ${SERVER}
EOF
