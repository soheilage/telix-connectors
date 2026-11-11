# Public‑data MCP connectors — data‑flow note for Telix InfoSec

**Scope:** ClinicalTrials.gov, PubMed/Europe PMC (PubCrawl), Open Targets. Public scientific databases only.

**What leaves the Telix Google Cloud tenant**
- Only the *search parameters* a user or agent types (e.g. "177Lu PSMA phase 2 Australia"), sent over HTTPS/443 to the public API of the named database.
- No Telix documents, SharePoint content, email or identities are sent to these services. The connectors have no access to any Telix data store.

**Where the connectors run**
- Cloud Run, `europe-west4`, inside Telix's own Google Cloud project (Telix organisation). No public invocation: IAM‑enforced, plus application‑level verification of a Google‑signed identity token whose audience is the service URL.
- Each connector runs under its own service account with no project permissions; licensed‑source credentials (when added) live in Secret Manager and are mounted at runtime only.

**What the tools can do**
- Read‑only (annotated `readOnlyHint=true`). No tool purchases, writes, or modifies anything upstream.
- Upstream code is open source (MIT / Apache‑2.0), pinned to a reviewed commit, built from source in Cloud Build, image stored in Artifact Registry with vulnerability scanning.

**Auditability**
- Every call is logged in Cloud Logging (caller identity, tool name, timestamp); Cloud Trace shows agent → tool spans. Logs stay in the EU project.

**Rollback**
- `gcloud run services delete mcp-<name> --region europe-west4` removes the connector; nothing is persisted.
