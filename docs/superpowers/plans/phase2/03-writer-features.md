# Sub-Phase 3: Writer Features (Export, Structure, Composition, Projects)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Parent spec:** `docs/superpowers/specs/2026-05-22-trovara-pro-phase2-design.md` (Part 3.3)
**Depends on:** Sub-phase 1 (paywall), Phase 1 (`ExportService`, `IProjectBundleRepository`, `StructureAnalyzerService`).
**Blocks:** none. (Sub-phase 4 quiz UI may share `project_bundle` selectors but does not require this plan first.)

**Goal:** Ship the writer-tier UI surface: format-aware export dialog, drag-drop structure tree, linear composition workspace, and project bundle list/detail views.

**Architecture:** Each view has its own ViewModel. `PdfExportService` and `DocxExportService` are new domain services registered in `ServiceLocator` and composed into `ExportService` (Phase 1) — `ExportService` becomes the single dispatch point for all formats. `ProjectBundleViewModel` is shared between list and detail views via factory parameters. `CompositionWorkspaceView` writes through `INoteRepository.save()` on each edit (debounced).

**Tech Stack:** Flutter, `pdf: ^3.x` (new dep), `docx_template: ^0.4.x` (new dep), `flutter_quill` (existing), `provider`, `easy_localization`, `lucide_icons_flutter`, `patrol_finders`.

---

## File Structure

### Create
- `lib/core/services/export/pdf_export_service.dart`
- `lib/core/services/export/docx_export_service.dart`
- `lib/views/pro/export_dialog_view.dart`
- `lib/views/pro/export_dialog_view_model.dart`
- `lib/views/pro/structure_view.dart`
- `lib/views/pro/structure_view_model.dart`
- `lib/views/pro/composition_workspace_view.dart`
- `lib/views/pro/composition_workspace_view_model.dart`
- `lib/views/pro/project_bundle_list_view.dart`
- `lib/views/pro/project_bundle_detail_view.dart`
- `lib/views/pro/project_bundle_view_model.dart`
- `patrol_test/core/services/export/pdf_export_service_test.dart`
- `patrol_test/core/services/export/docx_export_service_test.dart`
- `patrol_test/views/pro/export_dialog_view_model_test.dart`
- `patrol_test/views/pro/structure_view_model_test.dart`
- `patrol_test/views/pro/composition_workspace_view_model_test.dart`
- `patrol_test/views/pro/project_bundle_view_model_test.dart`

### Modify
- `pubspec.yaml` — add `pdf`, `docx_template`, `path_provider` (likely already present), `share_plus` (for "Open" action)
- `lib/core/di/service_locator.dart` — register PDF + DOCX services; extend `ExportService` constructor
- `lib/core/services/export/export_service.dart` — dispatch to PDF/DOCX
- `lib/core/route/app_router.dart` — add `/pro/export`, `/pro/structure`, `/pro/composition`, `/pro/project/:id`, `/pro/projects`
- `lib/views/notes/note_view.dart` — add Export action
- `assets/translations/en.json` — `pro.writer.*`
- `assets/translations/km.json` — mirror

---

## Tasks

### Task 1: Add export libraries

**Files:** `pubspec.yaml`

- [ ] **Step 1: Add deps**

```yaml
pdf: ^3.10.8
docx_template: ^0.4.0
share_plus: ^7.2.2
```

- [ ] **Step 2: Resolve and commit**

```bash
flutter pub get
git add pubspec.yaml pubspec.lock
git commit -m "chore(deps): add pdf, docx_template, share_plus for writer exports"
```

---

### Task 2: Add writer i18n keys

**Files:** `assets/translations/en.json`, `assets/translations/km.json`

- [ ] **Step 1: Add `pro.writer` block**

```json
"writer": {
  "export_title": "Export",
  "export_format_md": "Markdown",
  "export_format_html": "HTML",
  "export_format_pdf": "PDF",
  "export_format_docx": "Word",
  "export_include_toc": "Include table of contents",
  "export_embed_images": "Embed images",
  "export_preview": "Preview",
  "export_action": "Export",
  "export_done": "Saved to Downloads",
  "export_open": "Open",
  "export_failed": "Export failed: {message}",
  "structure_title": "Structure",
  "structure_cluster_banner": "These {count} notes form a cluster. Create project?",
  "structure_create_project": "Create project",
  "composition_title": "Composition",
  "composition_word_count": "{count} words • ~{minutes} min read",
  "composition_decompose": "Decompose",
  "projects_title": "Projects",
  "projects_create": "Create project",
  "projects_name_hint": "Project name",
  "projects_empty": "No projects yet.",
  "projects_share_link": "Share link",
  "projects_share_copied": "Share link copied"
}
```

- [ ] **Step 2: Mirror in km.json, verify with `/i18n-check`, commit**

```bash
git add assets/translations/
git commit -m "feat(ui): add pro.writer localization keys"
```

---

### Task 3: PdfExportService (TDD)

**Files:**
- Create: `lib/core/services/export/pdf_export_service.dart`
- Test: `patrol_test/core/services/export/pdf_export_service_test.dart`

- [ ] **Step 1: Write the test**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/export/pdf_export_service.dart';
import 'package:trovara/models/note.dart';

void main() {
  test('renderNotes produces non-empty pdf bytes', () async {
    final service = PdfExportService();
    final note = Note()..title = 'Test'..content = '# Hello\n\nBody.';
    final bytes = await service.renderNotes([note], includeToc: true);
    expect(bytes.isNotEmpty, isTrue);
    // PDF magic header is "%PDF"
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('renderNotes with multiple notes includes both titles in output', () async {
    final service = PdfExportService();
    final notes = [
      Note()..title = 'First'..content = 'one',
      Note()..title = 'Second'..content = 'two',
    ];
    final bytes = await service.renderNotes(notes, includeToc: false);
    expect(bytes.isNotEmpty, isTrue);
  });
}
```

- [ ] **Step 2: Verify failure**

Run: `flutter test patrol_test/core/services/export/pdf_export_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
// lib/core/services/export/pdf_export_service.dart
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:trovara/models/note.dart';

class PdfExportService {
  Future<Uint8List> renderNotes(List<Note> notes, {required bool includeToc}) async {
    final doc = pw.Document();
    if (includeToc) {
      doc.addPage(pw.Page(build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Table of Contents', style: pw.TextStyle(fontSize: 24)),
          pw.SizedBox(height: 12),
          for (final n in notes) pw.Text(n.title),
        ],
      )));
    }
    for (final note in notes) {
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(note.title, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Text(note.content ?? ''),
        ],
      ));
    }
    return doc.save();
  }
}
```

- [ ] **Step 4: Verify pass + commit**

```bash
flutter test patrol_test/core/services/export/pdf_export_service_test.dart
git add lib/core/services/export/pdf_export_service.dart patrol_test/core/services/export/pdf_export_service_test.dart
git commit -m "feat(core): add PdfExportService using pdf package"
```

---

### Task 4: DocxExportService (TDD)

**Files:**
- Create: `lib/core/services/export/docx_export_service.dart`
- Test: `patrol_test/core/services/export/docx_export_service_test.dart`

- [ ] **Step 1: Test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/export/docx_export_service.dart';
import 'package:trovara/models/note.dart';

void main() {
  test('renderNotes produces non-empty docx bytes', () async {
    final service = DocxExportService();
    final notes = [Note()..title = 'T'..content = 'body'];
    final bytes = await service.renderNotes(notes);
    expect(bytes.isNotEmpty, isTrue);
    // docx is a zip — magic bytes "PK"
    expect(bytes.take(2).toList(), [0x50, 0x4B]);
  });
}
```

- [ ] **Step 2: Implement**

```dart
// lib/core/services/export/docx_export_service.dart
import 'dart:typed_data';
import 'package:docx_template/docx_template.dart';
import 'package:trovara/models/note.dart';

class DocxExportService {
  Future<Uint8List> renderNotes(List<Note> notes) async {
    // Use a minimal in-memory template; load real template from assets in follow-up.
    final docx = await DocxTemplate.fromBytes(_blankTemplateBytes());
    final content = Content();
    for (final note in notes) {
      content
        ..add(TextContent('title', note.title))
        ..add(TextContent('body', note.content ?? ''));
    }
    final bytes = await docx.generate(content);
    return Uint8List.fromList(bytes ?? const []);
  }

  // Minimal blank .docx as base64 in a separate asset would be cleaner; inline placeholder for MVP.
  Uint8List _blankTemplateBytes() {
    throw UnimplementedError('Provide assets/templates/blank.docx and load via rootBundle');
  }
}
```

> Before completing this task, add `assets/templates/blank.docx` (a 1-page Word doc with `{title}` and `{body}` merge fields) and replace `_blankTemplateBytes` with `rootBundle.load(...)`. Test must run against the asset.

- [ ] **Step 3: Verify pass + commit**

```bash
git add lib/core/services/export/docx_export_service.dart patrol_test/core/services/export/docx_export_service_test.dart assets/templates/blank.docx
git commit -m "feat(core): add DocxExportService using docx_template"
```

---

### Task 5: Wire PDF + DOCX into ExportService + ServiceLocator

**Files:**
- Modify: `lib/core/services/export/export_service.dart`
- Modify: `lib/core/di/service_locator.dart`

- [ ] **Step 1: Extend ExportService**

Add constructor params for the new services and a `Future<Uint8List> export(List<Note>, ExportFormat, {opts...})` dispatcher that routes to existing Markdown/HTML logic or the new PDF/DOCX services.

- [ ] **Step 2: Update ServiceLocator**

```dart
PdfExportService? _pdfExportService;
PdfExportService get pdfExportService => _pdfExportService ??= PdfExportService();

DocxExportService? _docxExportService;
DocxExportService get docxExportService => _docxExportService ??= DocxExportService();
```

Update the `exportService` getter to pass PDF + DOCX services into the constructor.

- [ ] **Step 3: Run all export tests + commit**

```bash
flutter test patrol_test/core/services/export/
git add lib/core/services/export/export_service.dart lib/core/di/service_locator.dart
git commit -m "feat(core): wire PDF + DOCX into ExportService dispatcher"
```

---

### Task 6: ExportDialogViewModel (TDD)

**Files:**
- Create: `lib/views/pro/export_dialog_view_model.dart`
- Test: `patrol_test/views/pro/export_dialog_view_model_test.dart`

- [ ] **Step 1: Test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/export/export_service.dart';
import 'package:trovara/views/pro/export_dialog_view_model.dart';
import 'package:trovara/models/note.dart';

class _FakeExport extends ExportService { /* implement just what's used */ }

void main() {
  test('selectFormat updates state and clears previous error', () { /* ... */ });
  test('export() calls service with selected format and toggles', () async { /* ... */ });
  test('export() failure sets errorMessage', () async { /* ... */ });
}
```

- [ ] **Step 2: Implement**

```dart
// lib/views/pro/export_dialog_view_model.dart
import 'package:trovara/core/base/base_view_model.dart';
import 'package:trovara/core/services/export/export_service.dart';
import 'package:trovara/models/note.dart';

enum ExportFormat { markdown, html, pdf, docx }

class ExportDialogViewModel extends BaseViewModel {
  ExportDialogViewModel({required ExportService service, required this.notes})
      : _service = service;

  final ExportService _service;
  final List<Note> notes;

  ExportFormat _format = ExportFormat.markdown;
  bool _includeToc = false;
  bool _embedImages = true;
  bool _isExporting = false;
  String? _savedPath;
  String? _errorMessage;

  ExportFormat get format => _format;
  bool get includeToc => _includeToc;
  bool get embedImages => _embedImages;
  bool get isExporting => _isExporting;
  String? get savedPath => _savedPath;
  String? get errorMessage => _errorMessage;

  void selectFormat(ExportFormat f) {
    _format = f; _errorMessage = null; notifyListeners();
  }
  void toggleToc(bool v) { _includeToc = v; notifyListeners(); }
  void toggleEmbedImages(bool v) { _embedImages = v; notifyListeners(); }

  Future<void> export() async {
    _isExporting = true; _errorMessage = null; notifyListeners();
    try {
      _savedPath = await _service.exportToFile(
        notes,
        format: _format,
        includeToc: _includeToc,
        embedImages: _embedImages,
      );
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isExporting = false; notifyListeners();
  }
}
```

- [ ] **Step 3: Verify pass + commit**

```bash
git add lib/views/pro/export_dialog_view_model.dart patrol_test/views/pro/export_dialog_view_model_test.dart
git commit -m "feat(pro): add ExportDialogViewModel"
```

---

### Task 7: ExportDialogView (BottomSheet)

**Files:** `lib/views/pro/export_dialog_view.dart`

- [ ] **Step 1: Write the dialog**

Use `showModalBottomSheet` callable as `ExportDialogView.show(context, notes)`. Layout: segmented format selector → toggles → preview + export buttons. On success, `ScaffoldMessenger.showSnackBar` with "Open" action that calls `share_plus`.

(Concrete code mirrors paywall pattern from Sub-phase 1.)

- [ ] **Step 2: Commit**

```bash
git add lib/views/pro/export_dialog_view.dart
git commit -m "feat(pro): add ExportDialogView BottomSheet"
```

---

### Task 8: StructureViewModel + StructureView (TDD)

**Files:**
- Create: `lib/views/pro/structure_view_model.dart`
- Create: `lib/views/pro/structure_view.dart`
- Test: `patrol_test/views/pro/structure_view_model_test.dart`

- [ ] **Step 1: Write VM test** (loads hierarchy, reorders, accepts/dismisses cluster suggestion)

- [ ] **Step 2: Implement VM** — depends on `StructureAnalyzerService` (Phase 1)

```dart
class StructureViewModel extends BaseViewModel {
  StructureViewModel({required StructureAnalyzerService analyzer, required INoteRepository notes})
      : _analyzer = analyzer, _notes = notes;
  // load(), reorder(int oldIndex, int newIndex), createProjectFromCluster(...)
}
```

- [ ] **Step 3: Build StructureView** — `ReorderableListView` with drag handles, cluster suggestion banner.

- [ ] **Step 4: Commit**

```bash
git add lib/views/pro/structure_view.dart lib/views/pro/structure_view_model.dart patrol_test/views/pro/structure_view_model_test.dart
git commit -m "feat(pro): add StructureView with drag-drop and cluster suggestions"
```

---

### Task 9: CompositionWorkspaceViewModel + View

**Files:**
- Create: `lib/views/pro/composition_workspace_view_model.dart`
- Create: `lib/views/pro/composition_workspace_view.dart`
- Test: `patrol_test/views/pro/composition_workspace_view_model_test.dart`

- [ ] **Step 1: VM test** — load project notes, compute word count + reading time, write-through on edit (debounced 500ms).

- [ ] **Step 2: Implement VM**

```dart
class CompositionWorkspaceViewModel extends BaseViewModel {
  // notes: List<Note>, wordCount, readingTimeMinutes
  // onEdit(int noteId, String content) — debounced save via INoteRepository
}
```

Reading time formula: `(wordCount / 200).ceil()`.

- [ ] **Step 3: Build view** — `ListView` of inline Quill blocks per note.

- [ ] **Step 4: Commit**

```bash
git add lib/views/pro/composition_workspace_view.dart lib/views/pro/composition_workspace_view_model.dart patrol_test/views/pro/composition_workspace_view_model_test.dart
git commit -m "feat(pro): add CompositionWorkspaceView linear project editor"
```

---

### Task 10: ProjectBundleViewModel + List + Detail views

**Files:**
- Create: `lib/views/pro/project_bundle_view_model.dart`
- Create: `lib/views/pro/project_bundle_list_view.dart`
- Create: `lib/views/pro/project_bundle_detail_view.dart`
- Test: `patrol_test/views/pro/project_bundle_view_model_test.dart`

- [ ] **Step 1: VM test** — load projects, create, delete, share-token gen, reorder notes within project.

- [ ] **Step 2: Implement VM** using `IProjectBundleRepository` (Phase 1).

```dart
class ProjectBundleViewModel extends BaseViewModel {
  // projects, selectedProject, notesInProject
  // loadProjects(), create(String name), delete(int id), reorder(...), generateShareLink(int id)
}
```

- [ ] **Step 3: Build list + detail views.** List = `ListView` + FAB. Detail = `ReorderableListView` + "Share Link" button copying to clipboard via `Clipboard.setData`.

- [ ] **Step 4: Commit**

```bash
git add lib/views/pro/project_bundle_view_model.dart lib/views/pro/project_bundle_list_view.dart lib/views/pro/project_bundle_detail_view.dart patrol_test/views/pro/project_bundle_view_model_test.dart
git commit -m "feat(pro): add ProjectBundle list + detail views with share links"
```

---

### Task 11: Wire routes + NoteView export action

**Files:**
- Modify: `lib/core/route/app_router.dart`
- Modify: `lib/views/notes/note_view.dart`

- [ ] **Step 1: Register routes**

```dart
GoRoute(path: '/pro/export', builder: (_, __) => const ExportDialogView()),
GoRoute(path: '/pro/structure', builder: (_, __) => const StructureView()),
GoRoute(path: '/pro/composition', builder: (_, __) => const CompositionWorkspaceView()),
GoRoute(path: '/pro/projects', builder: (_, __) => const ProjectBundleListView()),
GoRoute(
  path: '/pro/project/:id',
  builder: (context, state) => ProjectBundleDetailView(
    projectId: int.parse(state.pathParameters['id']!),
  ),
),
```

- [ ] **Step 2: Add Export action to NoteView AppBar** with Pro gate (same pattern as Sub-phase 2 Task 8).

- [ ] **Step 3: Commit**

```bash
git add lib/core/route/app_router.dart lib/views/notes/note_view.dart
git commit -m "feat(pro): register writer routes and NoteView export action"
```

---

### Task 12: Hook "Export as CSV" in StatisticsDashboardWidget

**Files:** `lib/views/notes/widgets/statistics_dashboard_widget.dart`, `lib/views/notes/research_panel_view_model.dart`

- [ ] **Step 1: Add `Future<void> exportStatsAsCsv()` to `ResearchPanelViewModel`** delegating to `ExportService.toCsv`.

- [ ] **Step 2: Wire the button's `onPressed` from Sub-phase 2 Task 6 to the new VM method.**

- [ ] **Step 3: Commit**

```bash
git add lib/views/notes/widgets/statistics_dashboard_widget.dart lib/views/notes/research_panel_view_model.dart
git commit -m "feat(notes): wire stats CSV export to ExportService"
```

---

## Self-Review Checklist

- [ ] `flutter analyze` clean.
- [ ] `flutter test patrol_test/core/services/export/ patrol_test/views/pro/` passes.
- [ ] `/i18n-check` parity.
- [ ] No file in `lib/views/pro/` exceeds 300 LOC (split into widget files if needed).
- [ ] `PdfExportService` and `DocxExportService` each stay under 300 LOC.
- [ ] Export flows save to a writable location; SnackBar "Open" action works.
- [ ] All buttons / inputs gated on Pro via VM-level checks where appropriate.

## Out of Scope

- HTML preview's full WebView styling polish (functional MVP only).
- Cloud-hosted share links (current implementation generates local tokens for Sub-phase 6 study groups).
