# Connector hand‑over checklist (Niveus / NTT)

- [ ] Upstream reviewed; tools confirmed read‑only; commit SHA pinned in `servers/<name>/install.sh`
- [ ] `SOURCES.md` row added (licence, endpoints, credentials)
- [ ] Secrets created in Secret Manager (`servers/<name>/secrets.txt` names match)
- [ ] `template/deploy.sh <name>` succeeded; URL recorded
- [ ] `template/smoke.sh <name>` lists tools; `tools.json` committed
- [ ] `template/register.sh <name>` → visible in `gcloud agent-registry mcp-servers list --location=eu`
- [ ] GE: custom MCP server added (Google caller token); `roles/run.invoker` granted to GE identity
- [ ] Test prompt executed in GE by a Telix user; screenshot saved to PoC folder
- [ ] Antigravity `mcp.json` updated in workshop repo (optional)
- [ ] `docs/infosec-dataflow.md` updated if endpoints changed; shared with Vincent Ho
