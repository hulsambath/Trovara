#!/usr/bin/env bash
# PostToolUse hook: auto-formats .dart files with `dart format` after every edit.
#
# Reads JSON from stdin (Claude Code hook contract):
#   { "tool_name": "...", "tool_input": { "file_path": "..." } }
#
# Exit codes:
#   0 = continue (no output needed on success)
#   non-zero = ignored (we never want to block here)

set -euo pipefail

input="$(cat)"
file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty')"

# Only format .dart files; skip generated files and lib/gen/
if [ -z "$file_path" ]; then
  exit 0
fi

case "$file_path" in
  *.g.dart|*.freezed.dart|*.gr.dart) exit 0 ;;
  */lib/gen/*) exit 0 ;;
esac

if [[ "$file_path" != *.dart ]]; then
  exit 0
fi

if [ ! -f "$file_path" ]; then
  exit 0
fi

dart format --line-length 120 "$file_path" >/dev/null 2>&1 || true

exit 0
