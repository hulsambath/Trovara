# Sub-Phase 5: Collaborative Features (Comments + Version Snapshots)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Parent spec:** `docs/superpowers/specs/2026-05-22-trovara-pro-phase2-design.md` (Part 3.5)
**Depends on:** Sub-phase 1 (paywall), Phase 1 (`INoteRepository`, `LlmClient`).
**Blocks:** none.

**Goal:** Local-only comments thread + version snapshots for a note, with diff view and LLM-powered feedback digest. Cloud sync of comments is explicitly deferred to Phase 3.

**Architecture:** Two new ObjectBox entities (`NoteComment`, `VersionSnapshot`) and two new repositories. `CollaborativePanelViewModel` orchestrates comment CRUD + snapshot creation/restore. The diff view uses a pure-Dart line-diff utility (no new dep). The "Summarize feedback" button calls `LlmClient.generate(...)` directly via a thin VM method.

**Tech Stack:** Flutter, ObjectBox, `provider`, `easy_localization`, `lucide_icons_flutter`, `patrol_finders`.

---

## File Structure

### Create
- `lib/models/note_comment.dart` — ObjectBox entity
- `lib/models/version_snapshot.dart` — ObjectBox entity
- `lib/core/repository/interfaces/inote_comment_repository.dart`
- `lib/core/repository/interfaces/iversion_snapshot_repository.dart`
- `lib/core/repository/implementations/objectbox_note_comment_repository.dart`
- `lib/core/repository/implementations/objectbox_version_snapshot_repository.dart`
- `lib/views/pro/collaborative_panel_view.dart`
- `lib/views/pro/collaborative_panel_view_model.dart`
- `lib/views/pro/widgets/comment_thread_widget.dart`
- `lib/views/pro/widgets/version_history_widget.dart`
- `lib/views/pro/widgets/snapshot_diff_view.dart`
- `lib/core/services/diff/line_diff.dart` — pure utility (no class state)
- `patrol_test/core/repository/implementations/objectbox_note_comment_repository_test.dart`
- `patrol_test/core/repository/implementations/objectbox_version_snapshot_repository_test.dart`
- `patrol_test/views/pro/collaborative_panel_view_model_test.dart`
- `patrol_test/core/services/diff/line_diff_test.dart`

### Modify
- `lib/core/di/service_locator.dart` — register new repos
- `lib/objectbox-model.json` and `lib/objectbox.g.dart` — **regenerated** via `./scripts/build_runner.sh` (commit both, never hand-edit)
- `lib/core/route/app_router.dart` — NOT needed; panel opens as `Drawer` from `NoteView`
- `lib/views/notes/note_view.dart` — add Drawer + entry icon
- `assets/translations/en.json` — `pro.collaborative.*`
- `assets/translations/km.json` — mirror

---

## Tasks

### Task 1: Add collaborative i18n keys

**Files:** `assets/translations/en.json`, `km.json`

- [ ] **Step 1: Append `pro.collaborative`**

```json
"collaborative": {
  "panel_title": "Collaborate",
  "tab_comments": "Comments",
  "tab_versions": "Versions",
  "comment_hint": "Add a comment…",
  "comment_post": "Post",
  "comment_empty": "No comments yet.",
  "comment_summarize": "Summarize feedback",
  "snapshot_create": "Snapshot now",
  "snapshot_label_hint": "Label (e.g. 'first draft')",
  "snapshot_empty": "No snapshots yet.",
  "snapshot_restore": "Restore",
  "snapshot_diff_title": "Changes since {label}",
  "snapshot_restore_confirm": "Replace current content with this snapshot?",
  "saved_locally": "Saved locally"
}
```

- [ ] **Step 2: Mirror, `/i18n-check`, commit**

```bash
git add assets/translations/
git commit -m "feat(ui): add pro.collaborative localization keys"
```

---

### Task 2: NoteComment + VersionSnapshot entities

**Files:**
- Create: `lib/models/note_comment.dart`
- Create: `lib/models/version_snapshot.dart`

- [ ] **Step 1: Write entities**

```dart
// lib/models/note_comment.dart
import 'package:objectbox/objectbox.dart';

@Entity()
class NoteComment {
  @Id() int id = 0;
  int noteId;
  String text;
  String authorLabel; // "Me" in MVP; cloud sync brings real names
  @Property(type: PropertyType.date) DateTime createdAt;
  NoteComment({
    required this.noteId,
    required this.text,
    required this.authorLabel,
    required this.createdAt,
  });
}
```

```dart
// lib/models/version_snapshot.dart
import 'package:objectbox/objectbox.dart';

@Entity()
class VersionSnapshot {
  @Id() int id = 0;
  int noteId;
  String snapshotContent;
  String label;
  @Property(type: PropertyType.date) DateTime createdAt;
  VersionSnapshot({
    required this.noteId,
    required this.snapshotContent,
    required this.label,
    required this.createdAt,
  });
}
```

- [ ] **Step 2: Regenerate ObjectBox bindings**

Run: `./scripts/build_runner.sh -d`
Expected: `lib/objectbox.g.dart` and `lib/objectbox-model.json` updated.

- [ ] **Step 3: Commit (include generated files)**

```bash
git add lib/models/note_comment.dart lib/models/version_snapshot.dart lib/objectbox.g.dart lib/objectbox-model.json
git commit -m "feat(models): add NoteComment + VersionSnapshot entities"
```

---

### Task 3: Repository interfaces

**Files:**
- Create: `lib/core/repository/interfaces/inote_comment_repository.dart`
- Create: `lib/core/repository/interfaces/iversion_snapshot_repository.dart`

- [ ] **Step 1: Write interfaces**

```dart
// lib/core/repository/interfaces/inote_comment_repository.dart
import 'package:trovara/models/note_comment.dart';

abstract class INoteCommentRepository {
  Future<NoteComment> save(NoteComment comment);
  Future<List<NoteComment>> getForNote(int noteId);
  Future<void> delete(int id);
}
```

```dart
// lib/core/repository/interfaces/iversion_snapshot_repository.dart
import 'package:trovara/models/version_snapshot.dart';

abstract class IVersionSnapshotRepository {
  Future<VersionSnapshot> save(VersionSnapshot snapshot);
  Future<List<VersionSnapshot>> getForNote(int noteId);
  Future<VersionSnapshot?> getById(int id);
  Future<void> delete(int id);
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/repository/interfaces/inote_comment_repository.dart lib/core/repository/interfaces/iversion_snapshot_repository.dart
git commit -m "feat(core): add INoteCommentRepository + IVersionSnapshotRepository interfaces"
```

---

### Task 4: ObjectBox repository implementations (TDD)

**Files:**
- Create: `lib/core/repository/implementations/objectbox_note_comment_repository.dart`
- Create: `lib/core/repository/implementations/objectbox_version_snapshot_repository.dart`
- Test: `patrol_test/core/repository/implementations/objectbox_note_comment_repository_test.dart`
- Test: `patrol_test/core/repository/implementations/objectbox_version_snapshot_repository_test.dart`

- [ ] **Step 1: Write tests** mirroring `objectbox_note_repository_test.dart` pattern (use `ObjectBoxStoreManager` from test fixture, real Store, no mocks).

```dart
test('save then getForNote returns the comment', () async {
  final repo = ObjectBoxNoteCommentRepository();
  final saved = await repo.save(NoteComment(
    noteId: 1, text: 'hi', authorLabel: 'Me', createdAt: DateTime.now(),
  ));
  final fetched = await repo.getForNote(1);
  expect(fetched, hasLength(1));
  expect(fetched.first.id, saved.id);
});
test('delete removes the comment', () async { /* ... */ });
test('getForNote returns ordered by createdAt ascending', () async { /* ... */ });
```

- [ ] **Step 2: Implement**

```dart
// lib/core/repository/implementations/objectbox_note_comment_repository.dart
import 'package:objectbox/objectbox.dart';
import 'package:trovara/core/repository/base/objectbox_store_manager.dart';
import 'package:trovara/core/repository/interfaces/inote_comment_repository.dart';
import 'package:trovara/models/note_comment.dart';
import 'package:trovara/objectbox.g.dart';

class ObjectBoxNoteCommentRepository implements INoteCommentRepository {
  Box<NoteComment> get _box => ObjectBoxStoreManager().store.box<NoteComment>();

  @override
  Future<NoteComment> save(NoteComment comment) async {
    comment.id = _box.put(comment);
    return comment;
  }

  @override
  Future<List<NoteComment>> getForNote(int noteId) async {
    final q = _box.query(NoteComment_.noteId.equals(noteId))
        .order(NoteComment_.createdAt)
        .build();
    final results = q.find();
    q.close();
    return results;
  }

  @override
  Future<void> delete(int id) async => _box.remove(id);
}
```

Mirror this pattern for `ObjectBoxVersionSnapshotRepository`.

- [ ] **Step 3: Verify tests pass + commit**

```bash
flutter test patrol_test/core/repository/implementations/objectbox_note_comment_repository_test.dart patrol_test/core/repository/implementations/objectbox_version_snapshot_repository_test.dart
git add lib/core/repository/implementations/ patrol_test/core/repository/implementations/
git commit -m "feat(core): add ObjectBox repos for NoteComment + VersionSnapshot"
```

---

### Task 5: Register in ServiceLocator

**Files:** `lib/core/di/service_locator.dart`

- [ ] **Step 1: Add lazy getters**

```dart
INoteCommentRepository? _commentRepository;
INoteCommentRepository get commentRepository =>
    _commentRepository ??= ObjectBoxNoteCommentRepository();

IVersionSnapshotRepository? _snapshotRepository;
IVersionSnapshotRepository get snapshotRepository =>
    _snapshotRepository ??= ObjectBoxVersionSnapshotRepository();
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/di/service_locator.dart
git commit -m "feat(core): register comment + snapshot repos in ServiceLocator"
```

---

### Task 6: Line-diff utility (TDD)

**Files:**
- Create: `lib/core/services/diff/line_diff.dart`
- Test: `patrol_test/core/services/diff/line_diff_test.dart`

- [ ] **Step 1: Test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/diff/line_diff.dart';

void main() {
  test('identical strings produce no changes', () {
    final result = lineDiff('a\nb', 'a\nb');
    expect(result.where((l) => l.kind != DiffKind.unchanged), isEmpty);
  });
  test('addition produces an added line', () {
    final result = lineDiff('a', 'a\nb');
    expect(result.where((l) => l.kind == DiffKind.added).map((l) => l.text), ['b']);
  });
  test('deletion produces a removed line', () {
    final result = lineDiff('a\nb', 'a');
    expect(result.where((l) => l.kind == DiffKind.removed).map((l) => l.text), ['b']);
  });
}
```

- [ ] **Step 2: Implement using LCS**

```dart
// lib/core/services/diff/line_diff.dart
enum DiffKind { unchanged, added, removed }

class DiffLine {
  final DiffKind kind;
  final String text;
  const DiffLine(this.kind, this.text);
}

List<DiffLine> lineDiff(String a, String b) {
  final aLines = a.split('\n');
  final bLines = b.split('\n');
  final m = aLines.length, n = bLines.length;
  final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      dp[i][j] = aLines[i - 1] == bLines[j - 1]
          ? dp[i - 1][j - 1] + 1
          : (dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1]);
    }
  }
  final result = <DiffLine>[];
  var i = m, j = n;
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && aLines[i - 1] == bLines[j - 1]) {
      result.insert(0, DiffLine(DiffKind.unchanged, aLines[i - 1])); i--; j--;
    } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
      result.insert(0, DiffLine(DiffKind.added, bLines[j - 1])); j--;
    } else {
      result.insert(0, DiffLine(DiffKind.removed, aLines[i - 1])); i--;
    }
  }
  return result;
}
```

- [ ] **Step 3: Commit**

```bash
flutter test patrol_test/core/services/diff/line_diff_test.dart
git add lib/core/services/diff/ patrol_test/core/services/diff/
git commit -m "feat(core): add lineDiff LCS utility for snapshot diffing"
```

---

### Task 7: CollaborativePanelViewModel (TDD)

**Files:**
- Create: `lib/views/pro/collaborative_panel_view_model.dart`
- Test: `patrol_test/views/pro/collaborative_panel_view_model_test.dart`

- [ ] **Step 1: Test**

Cover: load (comments + snapshots), post comment, delete comment, create snapshot, restore snapshot, summarize feedback (LLM call mocked).

- [ ] **Step 2: Implement**

```dart
// lib/views/pro/collaborative_panel_view_model.dart
import 'package:trovara/core/base/base_view_model.dart';
import 'package:trovara/core/repository/interfaces/inote_comment_repository.dart';
import 'package:trovara/core/repository/interfaces/iversion_snapshot_repository.dart';
import 'package:trovara/core/repository/interfaces/note_repository.dart';
import 'package:trovara/core/services/ai/llm_client.dart';
import 'package:trovara/models/note_comment.dart';
import 'package:trovara/models/version_snapshot.dart';

class CollaborativePanelViewModel extends BaseViewModel {
  CollaborativePanelViewModel({
    required this.noteId,
    required INoteCommentRepository comments,
    required IVersionSnapshotRepository snapshots,
    required INoteRepository notes,
    required LlmClient llm,
  })  : _comments = comments, _snapshots = snapshots, _notes = notes, _llm = llm;

  final int noteId;
  final INoteCommentRepository _comments;
  final IVersionSnapshotRepository _snapshots;
  final INoteRepository _notes;
  final LlmClient _llm;

  List<NoteComment> _commentList = const [];
  List<VersionSnapshot> _snapshotList = const [];
  String? _digest;
  bool _digestLoading = false;

  List<NoteComment> get comments => _commentList;
  List<VersionSnapshot> get snapshots => _snapshotList;
  String? get digest => _digest;
  bool get isDigesting => _digestLoading;

  Future<void> load() async {
    _commentList = await _comments.getForNote(noteId);
    _snapshotList = await _snapshots.getForNote(noteId);
    notifyListeners();
  }

  Future<void> postComment(String text) async {
    final created = await _comments.save(NoteComment(
      noteId: noteId, text: text, authorLabel: 'Me', createdAt: DateTime.now(),
    ));
    _commentList = [..._commentList, created];
    notifyListeners();
  }

  Future<void> deleteComment(int id) async {
    await _comments.delete(id);
    _commentList = _commentList.where((c) => c.id != id).toList();
    notifyListeners();
  }

  Future<void> createSnapshot(String label) async {
    final note = await _notes.getById(noteId);
    if (note == null) return;
    final snap = await _snapshots.save(VersionSnapshot(
      noteId: noteId, snapshotContent: note.content ?? '',
      label: label, createdAt: DateTime.now(),
    ));
    _snapshotList = [..._snapshotList, snap];
    notifyListeners();
  }

  Future<void> restoreSnapshot(int snapshotId) async {
    final snap = await _snapshots.getById(snapshotId);
    final note = await _notes.getById(noteId);
    if (snap == null || note == null) return;
    note.content = snap.snapshotContent;
    await _notes.save(note);
    notifyListeners();
  }

  Future<void> summarizeFeedback() async {
    if (_commentList.isEmpty) return;
    _digestLoading = true; notifyListeners();
    final joined = _commentList.map((c) => '- ${c.text}').join('\n');
    _digest = await _llm.generate('Summarize this feedback concisely:\n$joined');
    _digestLoading = false; notifyListeners();
  }
}
```

- [ ] **Step 3: Verify pass + commit**

```bash
git add lib/views/pro/collaborative_panel_view_model.dart patrol_test/views/pro/collaborative_panel_view_model_test.dart
git commit -m "feat(pro): add CollaborativePanelViewModel"
```

---

### Task 8: Widget split (comments thread + version history + diff view)

**Files:**
- Create: `lib/views/pro/widgets/comment_thread_widget.dart`
- Create: `lib/views/pro/widgets/version_history_widget.dart`
- Create: `lib/views/pro/widgets/snapshot_diff_view.dart`

- [ ] **Step 1: CommentThreadWidget** — `ListView` of comments + `TextField` + post button + "Summarize feedback" `OutlinedButton`. Show `_digest` in `Card` when non-null.

- [ ] **Step 2: VersionHistoryWidget** — `ListView` of snapshots, "Snapshot now" `FloatingActionButton`, tap snapshot → push `SnapshotDiffView`.

- [ ] **Step 3: SnapshotDiffView** — uses `lineDiff` from Task 6. Renders each `DiffLine` colored: added (green tint via `theme.colorScheme.tertiaryContainer`), removed (red via `theme.colorScheme.errorContainer`), unchanged (default). Restore button with `showDialog` confirmation.

- [ ] **Step 4: Commit**

```bash
git add lib/views/pro/widgets/comment_thread_widget.dart lib/views/pro/widgets/version_history_widget.dart lib/views/pro/widgets/snapshot_diff_view.dart
git commit -m "feat(pro): add collaborative panel widgets (comments, versions, diff)"
```

---

### Task 9: CollaborativePanelView Drawer + NoteView entry

**Files:**
- Create: `lib/views/pro/collaborative_panel_view.dart`
- Modify: `lib/views/notes/note_view.dart`

- [ ] **Step 1: Build the Drawer**

`Scaffold` with `DefaultTabController(length: 2)` and `TabBar` (Comments / Versions). Wrapped in `ViewModelProvider<CollaborativePanelViewModel>`.

- [ ] **Step 2: Attach as endDrawer in NoteView**

Add `endDrawer: CollaborativePanelView(noteId: currentNoteId)` and a `LucideIcons.messageSquare` icon in the AppBar that opens it via `Scaffold.of(context).openEndDrawer()`. Gate behind `ProAccessService`.

- [ ] **Step 3: Manual smoke test**

Create note → snapshot → edit note → reopen drawer → see snapshot → tap → diff view shows changes → restore works.

- [ ] **Step 4: Commit**

```bash
git add lib/views/pro/collaborative_panel_view.dart lib/views/notes/note_view.dart
git commit -m "feat(pro): wire CollaborativePanelView as endDrawer in NoteView"
```

---

## Self-Review Checklist

- [ ] `flutter analyze` clean.
- [ ] `flutter test patrol_test/core/repository/implementations/objectbox_note_comment_repository_test.dart patrol_test/core/repository/implementations/objectbox_version_snapshot_repository_test.dart patrol_test/views/pro/collaborative_panel_view_model_test.dart patrol_test/core/services/diff/line_diff_test.dart` passes.
- [ ] `/i18n-check` parity.
- [ ] No file in `lib/views/pro/widgets/` exceeds 300 LOC.
- [ ] `lib/objectbox.g.dart` and `lib/objectbox-model.json` committed (never hand-edited).
- [ ] Snapshot restore writes through `INoteRepository.save()` — view does not touch it directly.

## Out of Scope

- Cloud sync of comments (Phase 3).
- Multi-author identification (everyone is "Me" in MVP).
- Quill-aware diff (line-based diff on raw text MVP; richer view deferred).
