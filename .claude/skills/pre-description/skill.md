---
name: pre-description
description: Use when about to open a PR or write a branch summary — generates a structured PR description from the git diff between the current branch and develop.
allowed-tools: Bash, Read
model: sonnet
---

# Pre-Description — PR Summary Generator

Generates a Trovara-specific PR description from git history. Run before `pr-prep` if you only need the description without the full quality-gate pass.

## Steps

### 1 — Collect the diff

```bash
git log develop..HEAD --oneline --no-merges
git diff develop..HEAD --stat
git diff develop..HEAD --name-only
```

### 2 — Read changed CLAUDE.md files (optional but useful for context)

If the diff touches `lib/views/` → read `lib/views/CLAUDE.md`.  
If it touches `lib/core/services/ai/` → read `lib/core/services/ai/CLAUDE.md`.

### 3 — Produce the description

```markdown
## What

- [User-visible change 1]
- [User-visible change 2]

## Why

[The motivation — a bug report, a spec requirement, a product decision]

## How

- [Key implementation choice — e.g., "Uses SHA-256 signatures in EmbeddingService to skip unchanged note chunks"]
- [Non-obvious architectural decision — e.g., "RagService now streams tokens via a Dart Stream<String> instead of buffering the full response"]

## Test Plan

- [ ] `flutter analyze` — clean
- [ ] `flutter test patrol_test` — passing
- [ ] Manually tested: [golden-path scenario]
- [ ] Edge cases: [list if applicable]

## Notes for Reviewer

[Files that deserve extra attention, known limitations, follow-up tickets]

---
🤖 Generated with [Claude Code](https://claude.ai/code)
```

### 4 — Commit type → "What" language mapping

| Commit prefix | "What" bullet language |
|---------------|----------------------|
| `feat(notes)` | New notes capability |
| `feat(ui)` | UI / gesture update |
| `feat(chat)` | AI chat improvement |
| `feat(sync)` | Sync / backup update |
| `fix(*)` | Bug fix — group minor fixes into one bullet |
| `refactor(*)` | Internal cleanup — omit from "What", include in "How" |
| `chore(deps)` | Omit entirely unless the bump fixes a user-facing bug |
| `perf(*)` | Performance improvement |

## Rules

- "What" bullets describe user or product impact — not implementation.
- "How" bullets describe architectural decisions — not what the code does line-by-line.
- Never copy commit messages verbatim — synthesize them.
- Scope to commits on this branch only (`develop..HEAD`).
