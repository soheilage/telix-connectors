# Reference deployment (Google Argolis sandbox, project `eg-telix`)

Google ran the full runbook once in a sandbox so the partner can compare outputs step by step.
**Nothing in this project is Telix's; Telix's deployment must be done in Telix's own EU project.**

| Step | Command | Observed output |
|---|---|---|
| 0 | `gcloud services list --enabled` | `run`, `cloudbuild`, `artifactregistry`, `agentregistry`, `discoveryengine`, `aiplatform` already on; `secretmanager` enabled by `deploy.sh` |
| 2 | `template/deploy.sh clinicaltrials` | AR repo `mcp-connectors` created · SA `mcp-clinicaltrials@eg-telix.iam.gserviceaccount.com` · image `europe-west4-docker.pkg.dev/eg-telix/mcp-connectors/clinicaltrials:<sha>` · Cloud Run `mcp-clinicaltrials` (europe-west4, private) · `AUDIENCE` pinned to both URL forms · tester SA `mcp-tester@…` |
| 3 | `template/smoke.sh clinicaltrials` | `health ok` · `serverInfo` · `4 tools` · `tools.json` written |
| 4 | `template/register.sh clinicaltrials` | service `mcp-clinicaltrials` visible in `gcloud agent-registry mcp-servers list --location=eu` |
| 5 | `deploy.sh … --allow-caller service-<n>@gcp-sa-discoveryengine…` | `roles/run.invoker` on the service |
| 6–7 | GE console | see README (Telix tenant steps) |

Service URLs for `eg-telix` (for comparison only):
- `https://mcp-clinicaltrials-258595268849.europe-west4.run.app/mcp`
- `https://mcp-clinicaltrials-uwqbodycxa-ez.a.run.app/mcp` (legacy form; both are accepted as token audiences)

## Local test without any cloud (what we ran before deploying)
```bash
uv venv && . .venv/bin/activate && uv pip install -r template/proxy/requirements.txt "mcp>=1.10"
bash tests/e2e_local.sh
# 4 tools … search_trials("177Lu PSMA", country=Australia) → total=26, incl. NCT06520345 (177Lu-TLX591)
# auth: no-token → 401, bad-token → 401
```

## Known gotchas we hit
- `gcloud auth print-identity-token --audiences=` is **not** available for user accounts → `smoke.sh` impersonates the `mcp-tester` service account (deploy.sh grants you `serviceAccountTokenCreator` on it).
- Cloud Run returns the legacy `*.a.run.app` URL as `status.url`; GE may call the deterministic `*-<project-number>.<region>.run.app` URL → the proxy accepts both audiences.
- Missing `requests` dependency broke `google-auth` token verification on first local run → fixed in `requirements.txt`.
