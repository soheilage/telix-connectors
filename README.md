# telix-connectors

Deployment template for exposing **MCP servers to Gemini Enterprise** (Telix PoC).
One generic image wraps any upstream MCP server (stdio or remote HTTP) as a private,
Google‑authenticated **streamable‑HTTP** endpoint on **Cloud Run (europe-west4)**,
then registers it in **Agent Registry** and adds it to GE as a *Custom MCP Server*.

```
template/            # reusable: Dockerfile, proxy, deploy/register/smoke scripts
servers/<name>/      # per‑server: install.sh (pinned upstream), server.env, [secrets.txt]
  clinicaltrials/    # in‑house FastMCP server over ClinicalTrials.gov API v2 (reference impl.)
  pubcrawl/          # PubMed / Europe PMC / drug labels (MIT)                [phase 2: pin SHA]
  opentargets/       # Open Targets Platform (Apache‑2.0)                    [phase 2: pin SHA]
  _template_licensed_remote/   # vendor‑hosted HTTP MCP + token (e.g. Article Galaxy)
  _template_licensed_stdio/    # self‑hosted stdio MCP + creds (e.g. PatSnap)
docs/                # InfoSec data‑flow note, checklist
```

## Defaults
| Setting | Value |
|---|---|
| Project | `eg-telix` (override `PROJECT_ID`) |
| Region | `europe-west4`; registry location `eu` |
| Ingress | Cloud Run `--no-allow-unauthenticated`; app also verifies Google ID token (`AUDIENCE` = service URL) |
| Identity | one service account per connector, no project roles |
| Secrets | Secret Manager only (`servers/<name>/secrets.txt` → `--set-secrets`) |
| Tools | read‑only (`readOnlyHint`) |

## Runbook (per connector)
```bash
# 0. prerequisites: gcloud auth login; gcloud config set project eg-telix; git clone <repo>; cd telix-connectors
# 1. (licensed sources only) create secrets first
gcloud secrets create ncbi-api-key --replication-policy=automatic && printf '%s' "$KEY" | gcloud secrets versions add ncbi-api-key --data-file=-
# 2. build + deploy (creates AR repo, SA, Cloud Run service; pins AUDIENCE)
template/deploy.sh clinicaltrials --allow-caller <GE-service-agent-or-agent-SA>
# 3. smoke test with your identity; writes servers/<name>/tools.json
template/smoke.sh clinicaltrials
# 4. register in Agent Registry (uses tools.json if present)
template/register.sh clinicaltrials
# 5. Gemini Enterprise: admin → tools / custom MCP server → URL = <service>/mcp, auth = Google caller token.
#    Grant roles/run.invoker on the service to the identity GE uses (re‑run deploy.sh with --allow-caller).
# 6. Antigravity (optional): add to mcp.json as remote server; use `gcloud auth print-identity-token --audiences=<URL>`.
```

## Adding a new connector
1. `cp -r servers/_template_licensed_stdio servers/<name>` (or `_licensed_remote`).
2. Edit `install.sh` (pin a commit SHA), `server.env` (`UPSTREAM_CMD` **or** `UPSTREAM_URL`), `secrets.txt`.
3. Add the upstream to `SOURCES.md` (licence, URL, SHA, data it reaches).
4. Run steps 2–5 above.

## Local test (no cloud)
```bash
uv venv && . .venv/bin/activate && uv pip install -r template/proxy/requirements.txt mcp
REQUIRE_AUTH=false UPSTREAM_CMD="python servers/clinicaltrials/ctgov_mcp.py" python template/proxy/server.py
# other terminal:
python tests/local_client.py http://localhost:8080/mcp
```

## Modes
- **A – stdio upstream** (`UPSTREAM_CMD`): proxy spawns the server as a subprocess, maintains MCP sessions over HTTP.
- **B – remote upstream** (`UPSTREAM_URL` + `UPSTREAM_TOKEN`/`UPSTREAM_HEADERS`): proxy forwards; useful when the vendor is already streamable‑HTTP but uses API keys / 2LO that GE cannot speak natively.

See `docs/infosec-dataflow.md` for what leaves the tenant (query strings to public APIs only).
