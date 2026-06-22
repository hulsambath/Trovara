---
name: reindex
description: Use when you want to manually refresh the Trovara project context snapshot — regenerates context_snapshot.md (branch, recent commits, working tree, untracked files) in the auto-memory directory on demand instead of waiting for the Stop hook.
allowed-tools: Bash
disable-model-invocation: false
---

# Reindex Project Context

Manually runs the same reindex that the `Stop` hook (`.claude/hooks/reindex-context.sh`)
fires automatically. Use this when you want `context_snapshot.md` refreshed *now* —
e.g. right after committing, switching branches, or staging files — without ending
the session.

## What it does

Writes `context_snapshot.md` into the project's auto-memory directory
(`~/.claude/projects/<encoded-project-path>/memory/`) with:

- Current branch + HEAD hash
- Last 10 commits (`git log --oneline -10`)
- Working tree (`git status --short`)
- Untracked files (first 20)

It also adds a pointer to `MEMORY.md` if missing.

## Steps

### 1 — Run the hook script directly

```bash
CLAUDE_PROJECT_DIR="$(git rev-parse --show-toplevel)" \
  bash "$(git rev-parse --show-toplevel)/.claude/hooks/reindex-context.sh"
```

The script is idempotent: a sentinel at `/tmp/trovara-context-reindex` skips the
write when neither HEAD nor the dirty-file count has changed since the last run.

### 2 — Force a rewrite when nothing changed (optional)

If git state is identical but you still want a fresh `Last indexed:` timestamp,
clear the sentinel first:

```bash
rm -f /tmp/trovara-context-reindex
CLAUDE_PROJECT_DIR="$(git rev-parse --show-toplevel)" \
  bash "$(git rev-parse --show-toplevel)/.claude/hooks/reindex-context.sh"
```

### 3 — Confirm the snapshot was written

```bash
MEM="$HOME/.claude/projects/$(git rev-parse --show-toplevel | sed 's|/|-|g')/memory/context_snapshot.md"
head -8 "$MEM"
```

Report the `Last indexed:` line and the current branch back to the user.

## Rules

- Never edit `context_snapshot.md` by hand — always regenerate it via the script so
  format stays consistent with the Stop hook.
- The script is read-only against git (status/log/rev-parse only); it never mutates
  the repo.
- If the script reports no change and the user did not ask to force, that is success —
  the snapshot is already current.