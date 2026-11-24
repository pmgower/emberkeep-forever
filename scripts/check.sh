#!/usr/bin/env bash
# The full gate. The Stop and TaskCompleted hooks and CI all run exactly this.
set -uo pipefail
cd "$(dirname "$0")/.."
status=0
run() { echo "== $*"; "$@" || status=1; }
run luacheck . --formatter plain --codes
# Core is the domain: Lua 5.1 only, no WoW API, so busted can test all of it.
run luacheck Kinfolk/Core --no-config --std lua51 --ignore 212 --formatter plain --codes
run stylua --check .
run busted --output=utfTerminal
run lua5.1 scripts/toc-check.lua Kinfolk/Kinfolk.toc
exit $status
