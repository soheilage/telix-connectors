# Generic image: Python proxy + Node (for npx-based MCP servers) + uv.
# Build with:  docker build -f template/Dockerfile --build-arg SERVER=<name> .
FROM python:3.12-slim

ARG SERVER
ENV PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1 PORT=8080 NODE_MAJOR=20

RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates git \
 && curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && pip install --no-cache-dir uv \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY template/proxy/requirements.txt /app/proxy/requirements.txt
RUN pip install --no-cache-dir -r /app/proxy/requirements.txt
COPY template/proxy/server.py /app/proxy/server.py

# Per-server payload: install.sh pins the upstream MCP server; server.env sets UPSTREAM_*.
COPY servers/${SERVER}/ /app/server/
RUN chmod +x /app/server/install.sh && /app/server/install.sh

RUN useradd -m -u 1000 mcp && chown -R mcp:mcp /app
USER mcp

HEALTHCHECK CMD curl -fsS http://localhost:${PORT}/healthz || exit 1
CMD ["sh", "-c", "set -a; . /app/server/server.env; set +a; exec python /app/proxy/server.py"]
