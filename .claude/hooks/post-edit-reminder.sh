#!/usr/bin/env bash
# PostToolUse hook: prints a non-blocking reminder when the edit
# touches files that need follow-up work.
#
# Exit codes:
#   0 = continue (stdout is shown to Claude as a system reminder)
#   non-zero = ignored (we never want to block here)

set -euo pipefail

input="$(cat)"
file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty')"

if [ -z "$file_path" ]; then
  exit 0
fi

# Edited an ObjectBox @Entity → build_runner needed
if [[ "$file_path" == */lib/models/* ]] && [[ "$file_path" == *.dart ]]; then
  echo "📦 lib/models/ edited — run \`./scripts/build_runner.sh\` to regenerate ObjectBox bindings before the next \`flutter run\`."
fi

# Edited a translation file → run /i18n-check
if [[ "$file_path" == */assets/translations/*.json ]]; then
  echo "🌍 Translation file edited — run \`/i18n-check\` to verify en.json and km.json are in sync."
fi

# Created a new view directory layout? (heuristic: *_view.dart in a fresh folder)
if [[ "$file_path" == */lib/views/*_view.dart ]]; then
  echo "📐 View edited — verify it follows docs/style_guide/Views_Style_Guide.md (folder layout, part files, ViewModelProvider)."
fi

# Touched a service or repository → run logic tests
if [[ "$file_path" == */lib/core/services/* ]] || [[ "$file_path" == */lib/core/repository/* ]]; then
  echo "🧪 Core service/repository edited — run \`flutter test patrol_test\` before declaring done."
fi

# File-size guard (per docs/style_guide/File_Organization_Rules.md)
# Hard limit: 300 LOC. Models exempt up to 400. Tests exempt up to 500. Generated files skipped.
if [[ "$file_path" == *.dart ]] \
    && [[ "$file_path" != *.g.dart ]] \
    && [[ "$file_path" != *.freezed.dart ]] \
    && [[ "$file_path" != *.gr.dart ]] \
    && [[ "$file_path" != */lib/gen/* ]] \
    && [ -f "$file_path" ]; then
  loc=$(wc -l < "$file_path" | tr -d ' ')
  limit=300
  recipe_hint="extract widgets to widgets/, helpers to a sub-folder, or business logic to a service"
  case "$file_path" in
    */lib/models/*)         limit=400; recipe_hint="split into mixins or extract value objects" ;;
    */patrol_test/*|*/test/*|*/integration_test/*) limit=500; recipe_hint="split by behavior (parsing_test.dart, serialization_test.dart)" ;;
    */_view.dart)           limit=40 ;;   # view file should be tiny
    */_content.dart)        limit=200 ;;  # content soft limit
    */widgets/*.dart)       limit=150 ;;  # widget soft limit
  esac
  if [ "$loc" -gt "$limit" ]; then
    echo "📏 File-size warning: $file_path is $loc lines (limit $limit)."
    echo "   See docs/style_guide/File_Organization_Rules.md → $recipe_hint."
  fi
fi

exit 0
