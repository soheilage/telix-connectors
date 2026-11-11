#!/usr/bin/env bash
# PubCrawl (MIT) - PubMed / Europe PMC / drug labels / trial search. https://github.com/nickjlamb/pubcrawl
# Pinned: npm @pharmatools/pubcrawl 2.8.0  (git fb8da65, reviewed 2026-11-10; all tools read-only)
set -euo pipefail
PUBCRAWL_VERSION="${PUBCRAWL_VERSION:-2.8.0}"
npm install -g --no-audit --no-fund "@pharmatools/pubcrawl@${PUBCRAWL_VERSION}"
command -v pubcrawl
