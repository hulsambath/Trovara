---
name: release-notes
description: Use when preparing a Trovara release — generates an internal dev changelog and a user-facing store description from git history since the last version tag.
allowed-tools: Bash, Read
model: sonnet
---

# Release Notes

Produces two outputs from git history:
1. **Internal changelog** — technical list for the team (commit-level detail)
2. **Store description** — user-facing "What's New" copy for App Store / Play Store (≤ 500 chars)

## Steps

### 1 — Find the base commit (last release)

```bash
# See recent tags
git tag --sort=-creatordate | head -10

# If no tags, find the last version bump commit
git log --oneline --grep="chore.*version\|bump.*version\|release" | head -5
```

### 2 — Extract commit log since last release

```bash
# Replace v1.0.0 with the actual last tag (or a commit SHA)
git log v1.0.0..HEAD --oneline --no-merges
```

Example output:
```
a3f1c2e feat(notes): add Obsidian import adapter
b8d0e11 fix(sync): handle Drive conflict on simultaneous edit
c4a92f7 feat(ui): swipe-to-archive gesture on note card
d1b3089 fix(chat): streaming response truncated on long context
e9c0714 chore(deps): bump objectbox to 4.3.0
```

### 3 — Read current version

```bash
grep '^version:' pubspec.yaml
```

### 4 — Draft the internal changelog

Group by conventional commit type. Include issue/PR references where present.

```markdown
## Trovara 1.1.0 (build 7) — Internal Changelog
_Released: <date>_

### Features
- **Notes import**: Obsidian `.md` vault import via file picker (closes #42)
- **UI**: Swipe-to-archive gesture on note card

### Fixes
- **Sync**: Drive conflict resolution on simultaneous edits from two devices
- **Chat**: Streaming response no longer truncates on long context windows

### Dependencies
- objectbox bumped to 4.3.0
```

### 5 — Draft store-ready "What's New" copy

Rules for store copy:
- ≤ 500 characters (App Store hard limit)
- Plain language — no technical jargon
- Lead with the biggest user benefit
- Bullet list of 3–5 items

```
What's New in Trovara 1.1.0

• Import your Obsidian vault directly — all notes land in Trovara instantly
• Swipe left on any note to archive it in one gesture
• Chat responses now handle long conversations without cutting off
• Faster sync when editing from multiple devices

Bug fixes and performance improvements.
```

### 6 — Verify character count

```bash
echo -n "What's New..." | wc -c   # must be ≤ 500
```

## Commit Type → User-Facing Language

| Commit prefix | Store language |
|---------------|----------------|
| `feat(notes)` | Note-taking improvement |
| `feat(ui)` | Design / gesture update |
| `feat(chat)` | AI chat improvement |
| `feat(sync)` | Sync / backup update |
| `fix(*)` | Bug fix (group minor fixes into one bullet) |
| `chore(deps)` | Omit from store copy |
| `refactor(*)` | Omit from store copy |
| `perf(*)` | "Performance improvements" |

## Rules

- Never include internal commit SHAs or branch names in store copy.
- `chore`, `refactor`, and `test` commits are excluded from store-facing notes.
- Keep store copy in present tense: "Import your vault" not "Added vault import".
- If there are no user-facing changes (all `chore`/`refactor`), write "Bug fixes and stability improvements."
