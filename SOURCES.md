# Upstream sources

| Connector | Upstream | Licence | Pinned ref | External endpoints reached | Credentials |
|---|---|---|---|---|---|
| clinicaltrials | in‑house (`servers/clinicaltrials/ctgov_mcp.py`) | Apache‑2.0 (this repo) | n/a | `clinicaltrials.gov/api/v2` | none |
| pubcrawl | https://github.com/nickjlamb/pubcrawl | MIT | **TODO pin SHA** | `eutils.ncbi.nlm.nih.gov`, `ebi.ac.uk/europepmc`, FDA/EMA/MHRA label sources | optional `NCBI_API_KEY` |
| opentargets | https://github.com/opentargets/platform-mcp | Apache‑2.0 | **TODO pin SHA** | `api.platform.opentargets.org` | none |
| patsnap (later) | https://github.com/patsnap/mcp | Apache‑2.0 | TODO | PatSnap API | Telix client id/secret |
| articlegalaxy (later) | vendor‑hosted (Research Solutions) | commercial | n/a | vendor endpoint | Telix API token; confirm MCP/API terms |

Review rule: before pinning, read the upstream's tool list and confirm every tool is read‑only;
if any tool writes (e.g. "purchase paper"), disable it via the proxy allow‑list before exposing in GE.
