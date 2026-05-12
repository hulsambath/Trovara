#!/usr/bin/env bash
# Stop hook: runs final quality checks before Claude ends its turn.
#   1. flutter analyze on changed .dart files (errors block; warnings allowed)
#   2. i18n parity check if translation files changed
#
# Reads JSON from stdin (Stop hook contract):
#   { "stop_hook_active": bool, "session_id": "...", ... }
#
# Exit codes:
#   0 = allow stop
#   2 = block stop (stderr sent to Claude so it can fix and continue)

set -uo pipefail

input="$(cat)"
stop_hook_active="$(printf '%s' "$input" | jq -r '.stop_hook_active // false')"

# Avoid infinite loops: if we already blocked once this turn, let it stop.
if [ "$stop_hook_active" = "true" ]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

# Bail early if we are not in a git repo.
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

# Collect changed .dart files (staged + unstaged + untracked).
mapfile -t changed_dart < <(
  {
    git diff --name-only --diff-filter=ACMR -- '*.dart'
    git diff --cached --name-only --diff-filter=ACMR -- '*.dart'
    git ls-files --others --exclude-standard -- '*.dart'
  } | sort -u | grep -v -E '\.(g|freezed|gr)\.dart$' | grep -v '/lib/gen/' || true
)

issues=()

# ───────────────────────────── flutter analyze ─────────────────────────────
if [ "${#changed_dart[@]}" -gt 0 ]; then
  echo "🔍 Running flutter analyze on ${#changed_dart[@]} changed .dart file(s)..." >&2
  if ! analyze_output="$(flutter analyze --no-pub "${changed_dart[@]}" 2>&1)"; then
    # Flutter analyze exits non-zero on info/warning too, so check for "error •"
    if echo "$analyze_output" | grep -qE 'error •'; then
      issues+=("flutter analyze found errors:")
      issues+=("$analyze_output")
    fi
  fi
fi

# ───────────────────────────── i18n parity check ─────────────────────────────
mapfile -t changed_i18n < <(
  {
    git diff --name-only --diff-filter=ACMR -- 'assets/translations/*.json'
    git diff --cached --name-only --diff-filter=ACMR -- 'assets/translations/*.json'
    git ls-files --others --exclude-standard -- 'assets/translations/*.json'
  } | sort -u || true
)

if [ "${#changed_i18n[@]}" -gt 0 ] \
    && [ -f "assets/translations/en.json" ] \
    && [ -f "assets/translations/km.json" ]; then
  echo "🌍 Checking en.json / km.json key parity..." >&2
  # Recursively flatten keys with jq, then diff
  en_keys="$(jq -r '[paths(scalars) | join(".")] | sort | .[]' assets/translations/en.json 2>/dev/null || true)"
  km_keys="$(jq -r '[paths(scalars) | join(".")] | sort | .[]' assets/translations/km.json 2>/dev/null || true)"
  missing_in_km="$(comm -23 <(echo "$en_keys") <(echo "$km_keys"))"
  missing_in_en="$(comm -13 <(echo "$en_keys") <(echo "$km_keys"))"
  if [ -n "$missing_in_km" ] || [ -n "$missing_in_en" ]; then
    issues+=("i18n parity broken between en.json and km.json:")
    [ -n "$missing_in_km" ] && issues+=("Missing in km.json:" "$missing_in_km")
    [ -n "$missing_in_en" ] && issues+=("Missing in en.json:" "$missing_in_en")
  fi
fi

# ───────────────────────────── Result ─────────────────────────────
if [ "${#issues[@]}" -gt 0 ]; then
  {
    echo "🛑 Stop blocked — fix the following before ending the turn:"
    echo
    for line in "${issues[@]}"; do
      echo "$line"
    done
    echo
    echo "(Per CLAUDE.md § Definition of Done: a change is not done until analyze passes and i18n keys are in parity.)"
  } >&2
  exit 2
fi

exit 0
