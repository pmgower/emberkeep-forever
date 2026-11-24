#!/usr/bin/env bash
# Stop and TaskCompleted: the full gate must be green before work counts as done.
# Exit 2 (not 1) so the stop or task completion is blocked, not just reported.
input=$(cat)
cd "$(dirname "$0")/../.." || exit 2
for tool in jq luacheck stylua busted lua5.1; do
  command -v "$tool" >/dev/null || { echo "gate: $tool is not installed, so nothing was checked." >&2; exit 2; }
done
out=$(scripts/check.sh 2>&1) || {
  echo "$out" | tail -n 60 >&2
  echo "Checks failed: fix them before finishing (scripts/check.sh)." >&2
  # A Stop that was already blocked once gets through with the failure shown, so
  # a gate that can't pass here can't trap the session. TaskCompleted never does.
  if [ "$(echo "$input" | jq -r '.hook_event_name // empty')" = "Stop" ] &&
    [ "$(echo "$input" | jq -r '.stop_hook_active // false')" = "true" ]; then
    exit 0
  fi
  exit 2
}
exit 0
