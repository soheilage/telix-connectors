"""Local MCP client: list tools and run one ClinicalTrials.gov query against the proxy.
Usage: python tests/local_client.py http://localhost:8080/mcp [id-token]
"""
import asyncio
import json
import sys

from fastmcp import Client
from fastmcp.client.transports import StreamableHttpTransport


async def main(url: str, token: str | None):
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    async with Client(StreamableHttpTransport(url, headers=headers)) as c:
        tools = await c.list_tools()
        print(f"{len(tools)} tools: {[t.name for t in tools]}")
        if any(t.name == "search_trials" for t in tools):
            r = await c.call_tool("search_trials", {"query": "177Lu PSMA", "country": "Australia", "page_size": 3})
            data = json.loads(r.content[0].text)
            print(f"total={data['total']}")
            for s in data["studies"]:
                print(f" - {s['nct_id']} [{s['status']}] {s['title'][:80]}")


if __name__ == "__main__":
    asyncio.run(main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None))
