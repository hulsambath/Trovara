---
description: List every .dart file in lib/ that violates File_Organization_Rules.md (over-LOC or multi-class)
---

# Audit File Sizes & Class Counts

Scan `lib/` for violations of `docs/style_guide/File_Organization_Rules.md` and report a punch list with refactor recipes.

## Steps

1. Run this Bash one-liner to gather the data (excludes generated files; applies the per-folder limits from the rule):

   ```bash
   {
     echo "── Over-LOC violations (limit: 300; models 400; tests 500) ──"
     find lib -name "*.dart" \
       ! -name "*.g.dart" ! -name "*.freezed.dart" ! -name "*.gr.dart" \
       ! -path "*/gen/*" \
       -print0 | while IFS= read -r -d '' f; do
         loc=$(wc -l < "$f" | tr -d ' ')
         limit=300
         case "$f" in
           lib/models/*) limit=400 ;;
         esac
         if [ "$loc" -gt "$limit" ]; then
           printf "%5d  (limit %d)  %s\n" "$loc" "$limit" "$f"
         fi
       done | sort -rn
     echo
     echo "── Multi-class files (>1 public top-level class/abstract/mixin/enum) ──"
     find lib -name "*.dart" \
       ! -name "*.g.dart" ! -name "*.freezed.dart" ! -name "*.gr.dart" \
       ! -path "*/gen/*" \
       -print0 | while IFS= read -r -d '' f; do
         count=$(grep -cE "^(class|abstract class|mixin|enum) [A-Z]" "$f")
         if [ "$count" -gt 1 ]; then
           printf "%2d  %s\n" "$count" "$f"
         fi
       done | sort -rn
   }
   ```

2. **For each over-LOC file**, suggest the matching refactor recipe from `File_Organization_Rules.md`:
   - View widget file → R1
   - Service/repository → R2
   - ViewModel → R3 (extract a service)
   - Multiple data classes → R4
   - Big switch over an enum/strategy → R5
   - Multiple models/enums → R6

3. **For each multi-class file**, look at the classes and decide:
   - Are the secondary classes legitimate co-residents (enum/exception/sealed for the primary, or private `_Helper` < 30 lines)? → mark as ✅ acceptable, no action.
   - Otherwise → mark as needing a split, suggest target filenames.

## Report format

```
# File-size audit — <date>

## Over the 300 LOC limit (Blocking)
- `lib/core/services/notes/note_service.dart` — 1564 / 300 → Recipe R2: split into note_service.dart (orchestration), note_sorting.dart, note_tag_indexer.dart
- `lib/views/search/search_content.dart` — 882 / 300 → Recipe R1: extract widgets/search_filters.dart, widgets/search_results.dart, widgets/search_empty.dart
- `lib/core/services/ai/llm_client.dart` — 667 / 300 → Recipe R5: split _providers/{gemini,openai,openrouter}_provider.dart

## Multi-class files needing a split
- `lib/core/storage/google_drive_auth_storage.dart` — 5 classes; GoogleDriveSession should move to its own file.
- `lib/core/services/ai/llm_client.dart` — 4 classes; provider strategies should move to _providers/ (overlaps with R5 above).

## Multi-class files (acceptable co-residence)
- `lib/core/services/ai/rag_service.dart` — 3 classes (RagService + RagQueryException + RagResult sealed). All bound to the service. ✅
- `lib/core/import/import_adapter.dart` — 3 classes (NoteImportAdapter abstract + ImportedNote + ImportResult). All form the adapter contract. ✅

## Summary
- Blocking: N files over LOC, M files multi-class
- Acceptable: K co-residence cases
- Total `.dart` files scanned: T
```

## Notes

- Do NOT propose fixes longer than one sentence — this is a punch list.
- Do NOT auto-refactor files. The user picks which ones to address and when.
- Run periodically (e.g., before PRs) to keep drift under control.
