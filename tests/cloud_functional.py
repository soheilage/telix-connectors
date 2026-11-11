"""Functional check of deployed connectors: one real tool call each, through Cloud Run with an impersonated SA token.
Usage: PROJECT_ID=<id> REGION=europe-west4 python tests/cloud_functional.py [clinicaltrials pubcrawl opentargets]
"""
import asyncio
import json
import os
import subprocess
import sys

from fastmcp import Client
from fastmcp.client.transports import StreamableHttpTransport

PROJECT = os.environ["PROJECT_ID"]
REGION = os.environ.get("REGION", "europe-west4")
TESTER = os.environ.get("TESTER", f"mcp-tester@{PROJECT}.iam.gserviceaccount.com")

CALLS = {
    "clinicaltrials": ("search_trials", {"query": "177Lu PSMA", "country": "Australia", "page_size": 3}),
    "pubcrawl": ("search_pubmed", {"query": "PSMA radioligand therapy mCRPC", "max_results": 3}),
    "opentargets": ("search_entities", {"query_strings": ["FOLH1", "CA9"]}),
}


def sh(cmd):
    return subprocess.check_output(cmd, shell=True, text=True).strip()


async def check(name):
    url = sh(f"gcloud run services describe mcp-{name} --region={REGION} --project={PROJECT} --format='value(status.url)'")
    tok = sh(f"gcloud auth print-identity-token --impersonate-service-account={TESTER} --audiences={url} --include-email 2>/dev/null")
    async with Client(StreamableHttpTransport(f"{url}/mcp", headers={"Authorization": f"Bearer {tok}"})) as c:
        tools = {t.name: t for t in await c.list_tools()}
        tool, args = CALLS[name]
        if tool not in tools:  # tolerate upstream renames: pick first tool containing 'search'
            tool = next((n for n in tools if "search" in n), next(iter(tools)))
            args = {}
        r = await c.call_tool(tool, args, raise_on_error=False)
        text = r.content[0].text if r.content else ""
        print(f"[{name}] {len(tools)} tools; called {tool}({json.dumps(args)}) -> error={r.is_error}; {text[:300].replace(chr(10),' ')}")


async def main(names):
    for n in names:
        try:
            await check(n)
        except Exception as e:  # noqa: BLE001
            print(f"[{n}] FAILED: {e}")


if __name__ == "__main__":
    asyncio.run(main(sys.argv[1:] or list(CALLS)))
