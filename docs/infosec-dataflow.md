# Public‑data MCP connectors — data‑flow note for Telix InfoSec

**Scope:** ClinicalTrials.gov, PubMed / Europe PMC (PubCrawl), Open Targets. Public scientific databases only.

**What leaves the Telix Google Cloud tenant**
- Only the *search parameters* a user or agent types (e.g. "177Lu PSMA phase 2 Australia"), sent over HTTPS/443 to the public API of the named database.
- No Telix documents, SharePoint content, email or user identities are sent to these services. The connectors have no access to any Telix data store.

**Where the connectors run**
- Cloud Run, `europe-west4`, inside Telix's own Google Cloud project. The services are private (`--no-allow-unauthenticated`): only the Gemini Enterprise service agent of the project and a named test identity hold `roles/run.invoker`. Gemini Enterprise authenticates with a Google‑signed OIDC token that Cloud Run IAM validates.
- Each connector runs under its own service account with no project permissions. Licensed‑source credentials (when added later) live in Secret Manager and are mounted at runtime only.

**What the tools can do**
- Read‑only (annotated `readOnlyHint=true`). No tool purchases, writes or modifies anything upstream.
- Upstream code is open source (MIT / Apache‑2.0), pinned to a reviewed version, built from source in Cloud Build; images stored in Artifact Registry with vulnerability scanning.

**Auditability**
- Every call is logged in Cloud Logging (caller identity, tool name, timestamp); Cloud Trace shows agent → tool spans. Logs stay in the EU project.

**Rollback**
- `gcloud run services delete mcp-<name> --region europe-west4` removes a connector; nothing is persisted.

| Connector | External endpoints | Credentials |
|---|---|---|
| clinicaltrials | `clinicaltrials.gov/api/v2` | none |
| pubcrawl | `eutils.ncbi.nlm.nih.gov`, `www.ebi.ac.uk` (Europe PMC), public FDA/EMA/MHRA label pages | optional NCBI API key (rate limit only) |
| opentargets | `api.platform.opentargets.org` | none |
