---
name: pr-prep
description: Use when implementation is complete and the branch is ready to open a PR — runs all quality gates and produces the PR description in one pass.
allowed-tools: Bash, Read, Grep, Glob
model: sonnet
---

# PR Prep — Pre-Flight Checklist

Systematically verify a branch is PR-ready, then generate the PR description. This replaces the mental overhead of remembering every pre-PR step.

## Step 1 — Understand the Branch

Run in parallel:

```bash
git log develop..HEAD --oneline          # commits on this branch
git diff develop..HEAD --stat            # files changed
git diff develop..HEAD --name-only       # file list for targeted review
```

Identify:
- What feature/fix this branch delivers
- Which CLAUDE.md areas are touched (views, core, ai, etc.)

## Step 2 — Run Build & Test

Run in parallel:

```bash
flutter analyze
flutter test patrol_test
```

**If either fails**: stop. Fix the failures before continuing. A PR with red gates is not ready.

Report:
```
✅ flutter analyze — clean
✅ flutter test patrol_test — N tests passed
```

or block with specific errors.

## Step 3 — Style Review

Invoke the `style-reviewer` subagent on the changed files:

```
Agent(subagent_type: "style-reviewer", prompt: "Review files changed on this branch vs develop: <file list from Step 1>")
```

Report the punch list. **Blocking violations must be fixed before the PR is opened.** Warnings can be noted in the PR description as known items.

## Step 4 — Definition of Done Checklist

Check each item against the branch diff:

- [ ] `flutter analyze` passes (Step 2)
- [ ] `flutter test patrol_test` passes (Step 2)
- [ ] All new user-visible strings exist in **both** `en.json` AND `km.json`
  ```bash
  # Verify parity
  diff <(jq -r '[paths(scalars) | join(".")] | sort | .[]' assets/translations/en.json) \
       <(jq -r '[paths(scalars) | join(".")] | sort | .[]' assets/translations/km.json)
  ```
- [ ] New ObjectBox entities have had `./scripts/build_runner.sh` run (check no `*.g.dart` is stale)
- [ ] No new file exceeds 300 LOC
  ```bash
  git diff develop..HEAD --name-only | grep '\.dart$' | grep -v '\.g\.dart$' | while read f; do
    [ -f "$f" ] && loc=$(wc -l < "$f") && [ "$loc" -gt 300 ] && echo "$loc $f"
  done
  ```
- [ ] No blocking style violations (Step 3)
- [ ] No hardcoded secrets (API keys, tokens, passwords)

If any item fails, report it and stop. Do not generate the PR description until all blocking items are resolved.

## Step 5 — Generate PR Description

Once all checks pass, generate the description using this template:

```markdown
## What

<!-- 2-3 bullet points: what changed at the user/product level -->
- 

## Why

<!-- The motivation — a bug report, a spec requirement, a performance issue -->

## How

<!-- Key architectural decisions, non-obvious implementation choices -->
- 

## Test Plan

- [ ] `flutter analyze` — clean
- [ ] `flutter test patrol_test` — all passing
- [ ] Manually tested: <describe the golden path you tested>
- [ ] Edge cases covered: <list any non-obvious edge cases>

## Notes for Reviewer

<!-- Anything the reviewer should pay special attention to, or known limitations -->

---
🤖 Generated with [Claude Code](https://claude.ai/code)
```

Fill each section from the git diff and commit history. Be specific — "add SHA-256 signature check to EmbeddingService to skip unchanged chunks" not "improve performance".

## Step 6 — Create the PR

Ask: "Ready to open the PR? (y to create via gh, or n to review description first)"

On confirmation:

```bash
gh pr create \
  --base develop \
  --title "<type(scope): subject from commits>" \
  --body "$(cat <<'EOF'
<generated description>
EOF
)"
```

Return the PR URL.

## Summary Report Format

```
# PR Prep — feat/my-branch

## Gates
✅ flutter analyze — clean
✅ flutter test patrol_test — 47 passed
✅ i18n parity — en.json and km.json in sync
✅ File sizes — no violations
⚠️  Style review — 1 warning (noted in PR description)

## Definition of Done
✅ All items passed

## PR Description
<generated description>

## Next Step
Run `gh pr create` or confirm above to open the PR.
```
