#!/usr/bin/env bash
# PreToolUse hook: blocks Edit/Write/MultiEdit on generated files.
#
# Reads JSON from stdin (Copilot Code hook contract):
#   { "tool_name": "...", "tool_input": { "file_path": "..." } }
#
# Exit codes:
#   0 = allow
#   2 = block (stderr is sent back to Copilot as a system reminder)

set -euo pipefail

input="$(cat)"
file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty')"

if [ -z "$file_path" ]; then
  exit 0
fi

basename="$(basename "$file_path")"

case "$basename" in
  *.g.dart|*.freezed.dart|*.gr.dart|objectbox-model.json)
    cat >&2 <<EOF
❌ Blocked: $file_path is a generated file.

Edit the source instead:
  • *.g.dart / *.freezed.dart   → edit the @Entity / @freezed source class
  • objectbox.g.dart            → edit a class in lib/models/, then run:
                                    ./scripts/build_runner.sh
  • objectbox-model.json        → never hand-edit; it is rewritten by build_runner

If you genuinely need to bypass this (e.g., debugging build_runner itself),
ask the user to disable the block-generated-edits.sh hook temporarily.
EOF
    exit 2
    ;;
esac

# Also block edits inside lib/gen/ (flutter_gen output)
case "$file_path" in
  */lib/gen/*)
    cat >&2 <<EOF
❌ Blocked: $file_path is in lib/gen/ (flutter_gen output).
Add the asset to pubspec.yaml under flutter.assets and let flutter_gen regenerate.
EOF
    exit 2
    ;;
esac

exit 0
