---
name: pr-prep
description: Use when implementation is complete and the branch is ready to open a PR — runs all quality gates and produces the PR description in one pass.
allowed-tools: Bash, Read, Grep, Glob
model: sonnet
---

# PR Prep — Pre-Flight Checklist

Verifies a branch is PR-ready and generates the PR description. Do not open the PR until all blocking gates pass.

## Step 1 — Understand the Branch

```bash
git log develop..HEAD --oneline
git diff develop..HEAD --stat
git diff develop..HEAD --name-only
```

## Step 2 — Run Quality Gates

Run in parallel:

```bash
flutter analyze
flutter test patrol_test
```

**If either fails: stop. Fix first, then resume.**

## Step 3 — Check i18n Parity

```bash
diff <(jq -r '[paths(scalars)|join(".")]|sort|.[]' assets/translations/en.json) \
     <(jq -r '[paths(scalars)|join(".")]|sort|.[]' assets/translations/km.json)
```

Output must be empty. If not: add missing keys to whichever file is behind.

## Step 4 — Check File Sizes

```bash
git diff develop..HEAD --name-only | grep '\.dart$' | grep -v '\.g\.dart$' | while read f; do
  [ -f "$f" ] && echo "$(wc -l < "$f") $f"
done | awk '$1 > 250 {print}'
```

Flag anything over 250. Anything over 300 is a blocker.

## Step 5 — Secrets Scan

```bash
git diff develop..HEAD | grep -E '(api_key|apiKey|password|secret|token)\s*=\s*["'"'"'][^$]'
```

Must be empty. API keys must use `String.fromEnvironment(...)` from `config_constants.dart`.

## Step 6 — Definition of Done Checklist

- [ ] `flutter analyze` — clean
- [ ] `flutter test patrol_test` — all passing
- [ ] i18n parity — diff empty
- [ ] No file over 300 LOC
- [ ] No secrets in diff
- [ ] `*.g.dart` not manually edited (check via `git diff develop..HEAD -- '*.g.dart'`)
- [ ] Tested the golden path manually

## Step 7 — Generate PR Description

```markdown
## What

- [What changed at the user/product level — 2–3 bullets]

## Why

[Motivation — bug report, spec requirement, performance issue]

## How

- [Key architectural decisions or non-obvious implementation choices]

## Test Plan

- [ ] `flutter analyze` — clean
- [ ] `flutter test patrol_test` — all passing
- [ ] Manually tested: [describe golden path]
- [ ] Edge cases: [list non-obvious edge cases]

## Notes for Reviewer

[Anything needing special attention, or known limitations]

---
🤖 Generated with [Claude Code](https://claude.ai/code)
```

Fill from git diff + commit history. Be specific — "add SHA-256 signature check to skip unchanged note chunks" not "improve performance".

## Step 8 — Create the PR

```bash
gh pr create \
  --base develop \
  --title "type(scope): subject" \
  --body "$(cat <<'EOF'
<generated description>
EOF
)"
```

Return the PR URL.

## Summary Report Format

```
## PR Prep — <branch>

### Gates
✅ flutter analyze — clean
✅ flutter test patrol_test — N passed
✅ i18n parity — in sync
✅ File sizes — no violations
✅ No secrets found

### Blockers
(none) — ready to open PR

### PR Description
<description>
```
