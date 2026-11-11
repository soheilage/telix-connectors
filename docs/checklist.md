# Connector hand‑over checklist (Niveus / NTT)

Tick per connector. The three public connectors are pre‑reviewed and pinned; the first three boxes only apply to new sources.

- [ ] (new source only) upstream reviewed, all tools read‑only, version pinned in `servers/<name>/install.sh`
- [ ] (new source only) `SOURCES.md` row added; `docs/infosec-dataflow.md` endpoint table updated and shared with Vincent Ho
- [ ] (new source only) secrets created in Secret Manager; names match `servers/<name>/secrets.txt`
- [ ] 🔒 T0.1 org policy effective `enforce: false` (Telix Org Policy Admin)
- [ ] `template/deploy.sh <name>` finished with `DONE`; URL recorded
- [ ] `template/smoke.sh <name>` lists the expected tools (4 / 14 / 5); `servers/<name>/tools.json` committed
- [ ] `template/register.sh <name>` → listed by `gcloud agent-registry mcp-servers list --location=eu`
- [ ] 🔒 GE app: Custom MCP Server data store added with the real `…run.app/mcp` URL; **Reload custom actions** OK; **Enable actions** → all tools
- [ ] 🔒 GE web app: connector visible under **Custom MCP** in the connector picker; test prompt answered with a tool call
- [ ] Screenshots committed: `docs/evidence/<name>-actions.png`, `docs/evidence/<name>-chat.png`
- [ ] Row added to `docs/deployments.md`
