#!/usr/bin/env bash
# PostToolUse (Edit|Write): lint and format-check the file just changed.
# Exit 2 sends the failure back to Claude so it fixes it before moving on.
command -v jq >/dev/null || { echo "post-edit: jq is not installed, so the edit was not linted." >&2; exit 2; }
file=$(jq -r '.tool_input.file_path // empty')
case "$file" in *.lua) ;; *) exit 0 ;; esac
[ -f "$file" ] || exit 0
cd "$(dirname "$0")/../.." || exit 2
out=$( { luacheck "$file" --formatter plain --codes && stylua --check "$file"; } 2>&1 ) || {
  echo "$out" >&2
  exit 2
}
exit 0
