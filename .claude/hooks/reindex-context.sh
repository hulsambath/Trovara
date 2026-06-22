#!/usr/bin/env bash
# Async Stop hook: writes context_snapshot.md to the project's auto-memory
# directory whenever the git state changes (new commit or dirty-tree change).
#
# Runs async (fire-and-forget) so it never delays /clear or normal stop events.
# A sentinel file at /tmp/trovara-context-reindex prevents redundant writes
# when nothing in the repo has actually changed.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" || exit 0

git rev-parse --git-dir >/dev/null 2>&1 || exit 0

HEAD_HASH="$(git rev-parse HEAD 2>/dev/null || echo 'none')"
DIRTY_COUNT="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
STATE_KEY="${HEAD_HASH}:${DIRTY_COUNT}"
SENTINEL="/tmp/trovara-context-reindex"

LAST_STATE=""; [ -f "$SENTINEL" ] && LAST_STATE="$(cat "$SENTINEL")"
[ "$STATE_KEY" = "$LAST_STATE" ] && exit 0

MEMORY_DIR="$HOME/.claude/projects/$(printf '%s' "$PROJECT_DIR" | sed 's|/|-|g')/memory"
mkdir -p "$MEMORY_DIR" 2>/dev/null || exit 0

BRANCH="$(git branch --show-current 2>/dev/null || echo 'detached')"

{
  printf -- '---\n'
  printf 'name: context-snapshot\n'
  printf 'description: Auto-updated git state — branch, recent commits, pending changes. Refreshed on every Stop/clear when git state changes.\n'
  printf 'metadata:\n'
  printf '  type: project\n'
  printf -- '---\n\n'
  printf 'Last indexed: %s\n\n' "$(date '+%Y-%m-%d %H:%M')"
  printf '## Branch\n`%s @ %s`\n\n' "$BRANCH" "$HEAD_HASH"
  printf '## Recent Commits\n```\n'
  git log --oneline -10 2>/dev/null || true
  printf '```\n\n'
  printf '## Working Tree\n```\n'
  git status --short 2>/dev/null || true
  printf '```\n\n'
  printf '## Untracked Files\n```\n'
  git ls-files --others --exclude-standard 2>/dev/null | head -20 || true
  printf '```\n'
} > "${MEMORY_DIR}/context_snapshot.md"

# Add pointer to MEMORY.md index if not already present
if [ -f "${MEMORY_DIR}/MEMORY.md" ] && ! grep -q 'context_snapshot' "${MEMORY_DIR}/MEMORY.md" 2>/dev/null; then
  printf '\n- [Context Snapshot](context_snapshot.md) — Auto-updated git state, recent commits, pending changes\n' >> "${MEMORY_DIR}/MEMORY.md"
fi

printf '%s' "$STATE_KEY" > "$SENTINEL"
exit 0