---
name: commit
description: Use when the user says "commit", "commit my changes", or types /commit — reads the diff, infers conventional type and scope, confirms the message, then runs the commit.
allowed-tools: Bash
model: sonnet
---

# Commit — Smart Conventional Commit Generator

Generate a precise, scoped commit message following Trovara's convention. Never commit without showing the message first.

## Trovara Commit Convention

```
type(scope): subject

[optional body — only if the why is non-obvious]
```

**Types:**
- `feat` — new user-visible feature
- `fix` — bug fix
- `refactor` — code change with no behavior change
- `test` — adding or fixing tests
- `docs` — documentation only
- `style` — formatting, lint, no logic change
- `chore` — deps, build scripts, CI, generated files

**Scopes:**
- `notes` — note CRUD, editor, content
- `ai` — LLM, embeddings, RAG, prompt builder
- `sync` — Google Drive sync
- `ui` — visual/layout changes with no logic change
- `tags` — tagging system
- `auth` — sign-in, Google auth
- `core` — DI, base classes, routing, initializer
- `deps` — pubspec changes
- `i18n` — translation files

**Subject rules:**
- Lowercase, imperative mood ("add", "fix", "remove" — not "added" or "adds")
- No period at end
- Under 72 characters
- Describes what changes, not what files change

## Step 1 — Read the Diff

Run these in parallel:

```bash
git diff --cached --stat          # staged files
git diff --stat                   # unstaged files
git diff --cached                 # staged content
git diff                          # unstaged content
git status --short                # untracked files
```

## Step 2 — Determine What to Stage

If there are unstaged or untracked changes, evaluate:
- Are they part of the logical change? → stage them
- Are they unrelated WIP? → leave them unstaged, note it to user

Do NOT run `git add -A` blindly. Stage specific files. Never stage `.env`, `*.pem`, `google-services.json`, `GoogleService-Info.plist`, or `pubspec.lock` without explicit user request.

## Step 3 — Draft the Message

Rules for picking type and scope:
- Multiple scopes → pick the dominant one, or use `core` if truly cross-cutting
- UI + logic together → use the logic type (`feat`, `fix`, `refactor`), not `ui`
- Only translation files changed → `chore(i18n)` or `feat(i18n)`
- Only pubspec changed → `chore(deps)`
- Generated files only (*.g.dart) → `chore(core): regenerate ObjectBox bindings`

Body (optional, only when the why is non-obvious):
- One short paragraph
- Explains motivation or constraint, not what the diff shows
- Skip if the subject is self-explanatory

Co-author line — always append:
```
Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

## Step 4 — Show the Message, Then Commit

Present the message exactly as it will appear:

```
feat(ai): add SHA-256 signature check to skip unchanged embeddings

Avoids redundant embedding API calls when note content hasn't changed
since the last sync.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

Ask: "Commit with this message? (y to confirm, or suggest changes)"

On confirmation, run:

```bash
git add <specific files>
git commit -m "$(cat <<'EOF'
<message here>
EOF
)"
```

Then run `git status` to confirm the working tree is clean.

## Step 5 — Handle Hook Failures

If the pre-commit hook blocks the commit:
1. Read the hook's stderr output carefully
2. Fix the reported issue (never use `--no-verify`)
3. Re-stage the fix and create a **new** commit (never `--amend` after a hook failure)

## What Never to Commit

- `.env`, `.env.*`
- `upload_certificate.pem`, `*.p12`, `*.keystore`
- `google-services.json`, `GoogleService-Info.plist`
- `pubspec.lock` (unless explicitly asked — it's gitignored)
- Unrelated WIP changes
