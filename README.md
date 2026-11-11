# telix-connectors — Partner Runbook (Niveus / NTT)

Purpose: expose public‑data MCP servers (ClinicalTrials.gov, PubMed/PubCrawl, Open Targets — later PatSnap,
Article Galaxy) to **Telix's Gemini Enterprise (GE)** tenant, in the EU, with no production Telix data in scope.

This repo gives you one reusable image + three scripts. **Follow the steps in order.** Steps marked
**🔒 TELIX TENANT** need an action or confirmation from a Telix administrator (Jellen Mattens / Vincent Ho) —
do not improvise around them; raise them in the project channel.

Reference deployment (Google Argolis, project `eg-telix`) is documented in [`docs/reference-deployment.md`](docs/reference-deployment.md).

---

## 0. Before you start

| Item | Value for Telix | How to confirm |
|---|---|---|
| GCP project hosting the GE app | `<TELIX_PROJECT_ID>` | Console → Gemini Enterprise → Apps → note project |
| Region for connectors | `europe-west4` | agreed (EU data residency) |
| GE app location | `eu` multi‑region | Gemini Enterprise → Apps → app details |
| Your role on the project | `roles/run.admin`, `roles/cloudbuild.builds.editor`, `roles/artifactregistry.admin`, `roles/iam.serviceAccountAdmin`, `roles/secretmanager.admin`, `roles/agentregistry.editor`, `roles/discoveryengine.admin` | `gcloud projects get-iam-policy <TELIX_PROJECT_ID> --flatten=bindings[].members --filter=bindings.members:you@…` |
| Tools on your laptop | `gcloud` (≥ 540), `git`, `curl`, `python3` | `gcloud version` |

**🔒 TELIX TENANT — confirm before step 1**
- [ ] **T0.1 Org policy (blocking).** GE blocks custom MCP connectors by default via the managed constraint
  `discoveryengine.managed.disableCustomMcpServerConnector` — it was **enforced** in our reference project too.
  A Telix **Organization Policy Administrator** (`roles/orgpolicy.policyAdmin`) sets a project‑level override:
  ```bash
  gcloud services enable orgpolicy.googleapis.com --project=<TELIX_PROJECT_ID>      # wait ~1 min after enabling
  cat > /tmp/ge_mcp_policy.yaml <<EOF
  name: projects/<TELIX_PROJECT_ID>/policies/discoveryengine.managed.disableCustomMcpServerConnector
  spec:
    rules:
    - enforce: false
  EOF
  gcloud org-policies set-policy /tmp/ge_mcp_policy.yaml --project=<TELIX_PROJECT_ID> --billing-project=<TELIX_PROJECT_ID>
  gcloud org-policies describe discoveryengine.managed.disableCustomMcpServerConnector --project=<TELIX_PROJECT_ID> --effective   # expect: enforce: false
  ```
  If `set-policy` says `SERVICE_DISABLED` right after enabling the API, wait a minute and retry.
- [ ] **T0.2 Egress.** Outbound HTTPS (443) from Cloud Run in `europe-west4` to `clinicaltrials.gov`, `eutils.ncbi.nlm.nih.gov`, `www.ebi.ac.uk`, `api.platform.opentargets.org` is allowed (Telix confirmed open egress for the PoC on 2026‑10‑2x; re‑confirm if VPC‑SC or Secure Web Proxy was added since).
- [ ] **T0.3 Scope sign‑off.** Vincent Ho has seen [`docs/infosec-dataflow.md`](docs/infosec-dataflow.md) (what leaves the tenant: query strings only).

---

## 1. Clone and configure (5 min)

```bash
git clone https://github.com/soheilage/telix-connectors.git && cd telix-connectors
gcloud auth login            # your Telix‑project identity
export PROJECT_ID=<TELIX_PROJECT_ID> REGION=europe-west4 REGISTRY_LOCATION=eu
gcloud config set project $PROJECT_ID
```

## 2. Deploy a connector (10–15 min each)

Start with `clinicaltrials` (no credentials, in‑house code — fastest to get a green light).

```bash
template/deploy.sh clinicaltrials
```
What it does: enables APIs → creates Artifact Registry repo `mcp-connectors` → creates service account
`mcp-clinicaltrials@…` (no project roles) → Cloud Build → Cloud Run `mcp-clinicaltrials`
(private, EU, 0–3 instances) → pins `AUDIENCE` to the service URL. It prints the `…/mcp` URL — **record it**.

For PubCrawl / Open Targets first pin the upstream commit in `servers/<name>/install.sh` (see `SOURCES.md`),
and for PubCrawl create the optional secret:
```bash
gcloud secrets create ncbi-api-key --replication-policy=automatic
printf '%s' "<KEY>" | gcloud secrets versions add ncbi-api-key --data-file=-
template/deploy.sh pubcrawl
```

## 3. Smoke test with your own identity (2 min)

```bash
template/smoke.sh clinicaltrials
```
`smoke.sh` impersonates the `mcp-tester` service account created by `deploy.sh` (user accounts cannot mint
audience‑bound identity tokens). Expected: `serverInfo {'name': 'clinicaltrials', …}`,
`4 tools: search_trials, get_trial, trial_locations, trials_by_sponsor`, and `servers/clinicaltrials/tools.json` written.
`/healthz` may report 404 through the Cloud Run front end — ignore; the MCP endpoint is what matters.
If `initialize` returns `401`: `AUDIENCE` env ≠ URL (re‑run `deploy.sh`) or the tester SA lacks `roles/run.invoker`.

## 4. Register in Agent Registry (1 min)

```bash
template/register.sh clinicaltrials
gcloud agent-registry mcp-servers list --project=$PROJECT_ID --location=eu
```
Registration is metadata only (discovery/governance); it does not grant access. The script strips fastmcp's
`_meta` from the tool spec (Agent Registry rejects it) and registers with `protocolBinding=jsonrpc`.

## 5. Grant Gemini Enterprise permission to call the connector

GE invokes the Cloud Run URL with a Google‑signed identity token from the **Discovery Engine service agent** of the GE project.

```bash
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
GE_SA="service-${PROJECT_NUMBER}@gcp-sa-discoveryengine.iam.gserviceaccount.com"
template/deploy.sh clinicaltrials --allow-caller "$GE_SA"     # idempotent; adds roles/run.invoker
```

**🔒 TELIX TENANT — confirm**
- [ ] **T5.1** The service agent exists: `gcloud iam service-accounts describe "$GE_SA"` (it is created when the GE app was first made; if missing, open the GE app page once in the console, or ask Google to trigger it).
- [ ] **T5.2** If Telix uses a *different* project for the GE app than for the connectors, use **that** project's number for `GE_SA`, and ask Google to confirm cross‑project invocation is in scope for the PoC.

## 6. Add the connector to the Telix GE app (console, 5 min)

**🔒 TELIX TENANT — performed by a GE admin (Jellen) with you on a call**
1. Google Cloud console → **Gemini Enterprise** → **Apps** → click the Telix app.
2. **Connected data stores** → **+ New data store**.
3. Under **MCP servers** choose **Custom MCP Server**.
4. **MCP Server URL** = the `https://mcp-clinicaltrials-….run.app/mcp` from step 2.
   **Authentication** = *Google identity / caller token* (the connector verifies the token; do **not** choose OAuth 2.0 — there is no IdP for public data).
   Transport must be *Streamable HTTP* (SSE is not supported).
5. Save. Open the new data store → **Actions** → toggle **ON** the 4 tools (new custom‑MCP actions are off by default; max 100 per server).
6. Confirm in the data store page that the tool list matches `servers/clinicaltrials/tools.json`.
- [ ] **T6.1** Screenshot of the data store with actions enabled → PoC folder.
- [ ] **T6.2** If the *Custom MCP Server* tile is missing or greyed out → T0.1 (org policy) is not lifted or the project lacks `discoveryengine.admin` for the signed‑in admin.

## 7. Verify from a Telix user account (5 min)

**🔒 TELIX TENANT — a Telix researcher (David Han / Iva Kulic) runs this in the GE web app**
1. New chat → prompt: *"Using the ClinicalTrials connector, list recruiting phase 2/3 trials of 177Lu‑PSMA in Australia and summarise sponsors."*
2. Expect tool calls to `search_trials` and a table with NCT ids (e.g. NCT06520345 — Telix's own TLX591 study).
3. Agent Designer → new agent → *Tools & Integrations* → authorise the connector → save as **"Radiopharma Evidence Agent"** → share with the R&D group.
- [ ] **T7.1** Prompt + result screenshot saved; any "permission denied" → go back to step 5.

## 8. Hand‑over record

Append a row to [`docs/deployments.md`](docs/deployments.md): connector, URL, image SHA, date, who verified in GE.
Then repeat steps 2–7 for `pubcrawl` and `opentargets`.

---

## Adding a licensed source later (PatSnap, Article Galaxy)
1. Copy `servers/_template_licensed_stdio` (self‑hosted, e.g. PatSnap) or `servers/_template_licensed_remote`
   (vendor‑hosted HTTP, e.g. Article Galaxy) to `servers/<name>`.
2. Put credentials in Secret Manager; list them in `servers/<name>/secrets.txt` (`ENV=secret-name`).
3. **🔒 TELIX TENANT** — David Han confirms with the vendor that API/MCP access is permitted under Telix's licence; Vincent confirms the credential is scoped read‑only.
4. Steps 2–8 above.

## Layout
```
template/   Dockerfile · proxy/server.py (stdio|remote → Google‑authenticated streamable‑HTTP) · deploy.sh · smoke.sh · register.sh · cloudbuild.yaml
servers/    clinicaltrials (reference, in‑house) · pubcrawl · opentargets · _template_licensed_{stdio,remote}
docs/       infosec-dataflow.md · checklist.md · reference-deployment.md · deployments.md
tests/      e2e_local.sh · local_client.py   (run locally without any cloud: see docs/reference-deployment.md)
```

## Troubleshooting
| Symptom | Cause / fix |
|---|---|
| `smoke.sh` → 401 | caller lacks `roles/run.invoker`, or `AUDIENCE` env ≠ service URL (re‑run `deploy.sh`) |
| 403 | `ALLOWED_PRINCIPALS` set and caller not listed |
| GE shows no tools after adding | actions toggled off (step 6.5); or server returned >100 tools |
| Cloud Run cold start > 10 s on first call | expected at min‑instances 0; set `--min-instances=1` for demo days |
| Upstream errors (429) from NCBI | add `NCBI_API_KEY` secret (PubCrawl) |
