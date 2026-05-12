---
description: Verify assets/translations/en.json and km.json have identical key sets
---

# i18n Parity Check

Verify that `assets/translations/en.json` and `assets/translations/km.json` contain the **same set of leaf keys** (the values can differ — they're translations).

## Steps

1. Run this Bash one-liner (jq flattens nested keys to dotted paths; `comm` finds the differences):

   ```bash
   en_keys=$(jq -r '[paths(scalars) | join(".")] | sort | .[]' assets/translations/en.json)
   km_keys=$(jq -r '[paths(scalars) | join(".")] | sort | .[]' assets/translations/km.json)
   echo "── Keys in en.json but missing in km.json ──"
   comm -23 <(echo "$en_keys") <(echo "$km_keys")
   echo
   echo "── Keys in km.json but missing in en.json ──"
   comm -13 <(echo "$en_keys") <(echo "$km_keys")
   echo
   en_count=$(echo "$en_keys" | wc -l | tr -d ' ')
   km_count=$(echo "$km_keys" | wc -l | tr -d ' ')
   echo "en.json: $en_count keys"
   echo "km.json: $km_count keys"
   ```

2. **If both diffs are empty**: report ✅ "Translation files in sync (N keys)" and stop.

3. **If there are missing keys**:
   - Show the user the lists of missing keys.
   - For each missing key, **propose** an addition to the deficient file. Use the value from the existing file as a placeholder (e.g., copy the English string into km.json with a `[TRANSLATE]` prefix), or `''` if the user prefers.
   - **Ask the user** whether to apply the additions before editing — do NOT silently insert translation guesses.

4. After any edits, re-run step 1 to confirm parity.

## Notes

- The Stop hook also runs this parity check whenever a translation file is changed in the session.
- Do not delete keys to "fix" parity unless the user explicitly asks — a missing key is almost always an oversight in the other file, not a deletion.
