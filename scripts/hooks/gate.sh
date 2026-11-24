#!/usr/bin/env bash
# Stop and TaskCompleted: the full gate must be green before work counts as done.
# Exit 2 (not 1) so the stop or task completion is blocked, not just reported.
cat >/dev/null # hook input is not needed
cd "$(dirname "$0")/../.." || exit 2
out=$(scripts/check.sh 2>&1) || {
  echo "$out" | tail -n 60 >&2
  echo "Checks failed: fix them before finishing (scripts/check.sh)." >&2
  exit 2
}
exit 0
