#!/usr/bin/env bash
# PubCrawl (MIT) - PubMed / Europe PMC / drug labels / trial search.
# TODO(phase 2): pin to a commit SHA or npm version after review. Source: https://github.com/nickjlamb/pubcrawl
set -euo pipefail
PUBCRAWL_REF="${PUBCRAWL_REF:-main}"   # replace with a SHA, e.g. 1a2b3c4
npm install -g "github:nickjlamb/pubcrawl#${PUBCRAWL_REF}"
