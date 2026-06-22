---
name: code-review
description: Use when reviewing a Trovara code change — checks correctness, MVVM layering, security, performance, i18n parity, file-size limits, and test coverage like a senior engineer.
allowed-tools: Read, Grep, Glob, Bash
model: opus
---

# Code Review

Senior-engineer review of Trovara diffs. Covers correctness, security, architecture, performance, and maintainability in that priority order.

## Step 1 — Understand the Diff

```bash
git diff develop..HEAD --stat         # files changed
git diff develop..HEAD --name-only    # file list
git log develop..HEAD --oneline       # commits
```

Load the area-specific `CLAUDE.md` for every changed directory before commenting.

## Step 2 — Priority Order

Review in this order; stop and report blockers before continuing:

1. **Correctness** — null safety, async races, off-by-one, state mutations
2. **Security** — hardcoded secrets, injection, auth bypass, Drive/Firebase scope
3. **Architecture** — MVVM layering, ServiceLocator misuse, DI violations
4. **Performance** — N+1 ObjectBox queries, unnecessary `notifyListeners` in loops, main-thread blocking
5. **Maintainability** — DRY, KISS, SOLID, file size, test coverage
6. **Readability** — naming, comments, style

## Step 3 — Trovara-Specific Checks

### MVVM Layering (blocker if violated)

- Views use `ViewModelProvider<T>` — no direct service calls from `build()`
- ViewModels extend `BaseViewModel`, inject services via constructor or `ServiceLocator().<getter>`
- Services receive **repository interfaces** (`INoteRepository`), never `ObjectBox*` concretions
- No `ServiceLocator()` calls inside a service constructor

### i18n Parity (blocker)

```bash
diff <(jq -r '[paths(scalars)|join(".")]|sort|.[]' assets/translations/en.json) \
     <(jq -r '[paths(scalars)|join(".")]|sort|.[]' assets/translations/km.json)
```

Must be empty. Any new user-visible string needs a key in both files.

### File Size (blocker above 300)

```bash
git diff develop..HEAD --name-only | grep '\.dart$' | grep -v '\.g\.dart$' | while read f; do
  [ -f "$f" ] && wc -l < "$f" | xargs -I{} echo "{} $f"
done | awk '$1 > 250'
```

Soft limit 250, hard limit 300. Flag files approaching the limit.

### Security Checklist

- [ ] No API keys in source — must use `String.fromEnvironment(...)` from `config_constants.dart`
- [ ] No secrets logged (even at `logger.d` level)
- [ ] Raw JSON decoded from network is validated before use
- [ ] Google Drive scope not widened beyond existing permissions

### Generated Files

- [ ] `*.g.dart` and `objectbox-model.json` not edited manually
- [ ] If entity fields changed, `./scripts/build_runner.sh` was run

### Icons & Theme

- [ ] No `Icons.*` — only `LucideIcons.*` from `lucide_icons_flutter`
- [ ] No `Colors.*` or raw hex — only `Theme.of(context).colorScheme.*`
- [ ] No raw `TextStyle(...)` — only `Theme.of(context).textTheme.*`

### Tests

- [ ] New service has at least one `patrol_test/` test
- [ ] New repository has at least one CRUD test
- [ ] Tests use stub repositories (not real ObjectBox in `patrol_test/`)
- [ ] `patrolTest` wrapper from `test_support.dart`, not from `package:patrol`

## Step 4 — Severity Levels

| Level | Examples |
|-------|---------|
| **Blocker** | API key exposure, MVVM violation, null crash, i18n missing |
| **Major** | N+1 query, untested public API, file over 300 LOC, DI leak |
| **Minor** | DRY violation, unclear naming, unused import |
| **Nitpick** | Trailing whitespace, lint warning |

## Step 5 — Comment Format

For each finding:

> **[Level] Description**  
> File: `path/to/file.dart:line`  
> Problem: what's wrong (cite CLAUDE.md rule if applicable)  
> Impact: why it matters  
> Fix: concrete recommendation

## Step 6 — Summary

```
## Review Summary

### Blockers (must fix before merging)
- ...

### Major
- ...

### Minor / Nitpick
- ...

### ✅ Passes
- flutter analyze
- i18n parity
- file sizes
- MVVM layering
```
