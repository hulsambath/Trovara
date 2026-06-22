---
name: add-translation
description: Use when inserting a new i18n key into Trovara's locale files — adds the key to both en.json and km.json under the correct nested path and verifies parity.
allowed-tools: Read, Edit, Bash
model: sonnet
---

# Add Translation Key

Inserts a new i18n key into `assets/translations/en.json` **and** `assets/translations/km.json` with identical structure, then verifies parity.

## Key Naming Conventions

| Rule | Example |
|------|---------|
| Nested by feature domain | `"notes": { "empty_state": "..." }` |
| Snake_case leaf keys | `empty_state`, `error_cancelled`, `cta_purchase` |
| Parameterized values use `{param}` | `"error_generic": "Error: {message}"` |
| Dot-notation in code | `tr('notes.empty_state')` |

## Steps

### 1 — Identify the correct nesting path

Read the relevant section in `assets/translations/en.json`:
```bash
cat assets/translations/en.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('<domain>', {}), indent=2))"
```

Choose the right parent key (e.g., `notes`, `pro.paywall`, `msg.update`). Add a new domain key only if the feature is truly new.

### 2 — Add the key to `assets/translations/en.json`

Insert under the matching domain object. Maintain alphabetical order within a group where possible.

Example — adding `notes.filter_by_tag`:
```json
"notes": {
  "empty_state": "No notes yet",
  "filter_by_tag": "Filter by tag",   ← new key
  "search_placeholder": "Search notes"
}
```

### 3 — Add the same key to `assets/translations/km.json` with Khmer translation

```json
"notes": {
  "empty_state": "មិនទាន់មានកំណត់ចំណាំ",
  "filter_by_tag": "ត្រងតាមស្លាក",   ← same key, Khmer value
  "search_placeholder": "ស្វែងរកកំណត់ចំណាំ"
}
```

If you do not have a Khmer translation, use a placeholder and flag it:
```json
"filter_by_tag": "[TODO: translate] Filter by tag"
```

### 4 — Verify parity

```bash
en_keys=$(jq -r '[paths(scalars) | join(".")] | sort | .[]' assets/translations/en.json)
km_keys=$(jq -r '[paths(scalars) | join(".")] | sort | .[]' assets/translations/km.json)
echo "── In en.json but missing in km.json ──"
comm -23 <(echo "$en_keys") <(echo "$km_keys")
echo "── In km.json but missing in en.json ──"
comm -13 <(echo "$en_keys") <(echo "$km_keys")
```

Both diffs must be empty. You can also run the `/i18n-check` command.

### 5 — Use in code

```dart
import 'package:easy_localization/easy_localization.dart';

// Simple key
Text(tr('notes.filter_by_tag'))

// Parameterized key
Text(tr('pro.billing.error_generic', namedArgs: {'message': e.toString()}))
```

## Rules

- A key added to `en.json` must exist in `km.json` with the same dotted path — always.
- Never add a key at the top level; always nest under a domain.
- Never use camelCase for keys — snake_case only.
- Do not import `AppLocalizations` directly — always use `tr()` from `easy_localization`.
- The Stop hook runs `/i18n-check` automatically; parity mismatches will block the session.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Key added to en.json but forgotten in km.json | Run parity check before finishing |
| camelCase key (`filterByTag`) | Use snake_case (`filter_by_tag`) |
| Top-level key with no domain grouping | Nest under existing or new domain object |
| Hardcoded string in widget instead of `tr()` | Replace with `tr('domain.key')` |
| Named param mismatch (`{msg}` vs `namedArgs: {'message': ...}`) | Param name in JSON and `namedArgs` key must match exactly |
