# Sub-Phase 2: Researcher Features (Research Panel + 3 Tabs)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Parent spec:** `docs/superpowers/specs/2026-05-22-trovara-pro-phase2-design.md` (Part 3.2)
**Depends on:** Sub-phase 1 (paywall gating), Phase 1 (`KnowledgeGraphService`, `VectorSearchService`, `IGraphRepository`).
**Blocks:** none.

**Goal:** Ship the toggleable research sidebar with three tabs — Semantic Explorer, Connection Inspector, Statistics Dashboard — wired into `NoteView` via an app-bar icon.

**Architecture:** A single `ResearchPanelViewModel` owns the shared graph-query state (current query, selected note id, filters). Three stateless tab widgets read slices of that state via `context.watch`. The panel is accessible from `NoteView` AppBar; on Pro lock it shows a "Pro feature" overlay that links to `/pro/paywall`. Stats use the `fl_chart` package; CSV export reuses the existing `ExportService` (Phase 1).

**Tech Stack:** Flutter, `provider`, `fl_chart` (new dep), `easy_localization`, `lucide_icons_flutter`, `patrol_finders`.

---

## File Structure

### Create
- `lib/views/notes/research_panel_view.dart` — TabBar shell
- `lib/views/notes/research_panel_view_model.dart` — shared state
- `lib/views/notes/widgets/semantic_explorer_widget.dart`
- `lib/views/notes/widgets/connection_inspector_widget.dart`
- `lib/views/notes/widgets/statistics_dashboard_widget.dart`
- `patrol_test/views/notes/research_panel_view_model_test.dart`

### Modify
- `pubspec.yaml` — add `fl_chart: ^0.69.0` (or latest stable)
- `lib/core/route/app_router.dart` — add `/pro/research` route
- `lib/views/notes/note_view.dart` — add app-bar icon button
- `assets/translations/en.json` — `pro.researcher.*`
- `assets/translations/km.json` — mirror

---

## Tasks

### Task 1: Add fl_chart dependency

**Files:** `pubspec.yaml`

- [ ] **Step 1: Add dependency**

Under `dependencies:` add `fl_chart: ^0.69.0` (verify latest stable on pub.dev before committing).

- [ ] **Step 2: Resolve**

Run: `flutter pub get`
Expected: clean resolve.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(deps): add fl_chart for statistics dashboard"
```

---

### Task 2: Add researcher localization keys

**Files:** `assets/translations/en.json`, `assets/translations/km.json`

- [ ] **Step 1: Append `pro.researcher` block to en.json**

```json
"researcher": {
  "panel_title": "Research",
  "tab_explorer": "Explorer",
  "tab_inspector": "Inspector",
  "tab_stats": "Stats",
  "search_hint": "Search related notes…",
  "empty_explorer": "No related notes found. Try a broader query.",
  "filter_date": "Date",
  "filter_tag": "Tag",
  "filter_project": "Project",
  "inspector_referenced_by": "Referenced by ({count})",
  "inspector_references": "References ({count})",
  "edge_semantic": "Semantic",
  "edge_citation": "Citation",
  "edge_hierarchical": "Hierarchical",
  "stats_top_concepts": "Top concepts",
  "stats_citations": "Citation frequency",
  "stats_density": "Research density",
  "stats_export_csv": "Export as CSV",
  "pro_lock_banner": "Unlock Pro to use Research"
}
```

- [ ] **Step 2: Mirror in km.json** (translate or copy English placeholders — coordinate with translator before release).

- [ ] **Step 3: Verify**

Run: `/i18n-check`
Expected: parity.

- [ ] **Step 4: Commit**

```bash
git add assets/translations/
git commit -m "feat(ui): add pro.researcher localization keys"
```

---

### Task 3: ResearchPanelViewModel (TDD)

**Files:**
- Create: `lib/views/notes/research_panel_view_model.dart`
- Test: `patrol_test/views/notes/research_panel_view_model_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// patrol_test/views/notes/research_panel_view_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/graph/knowledge_graph_service.dart';
import 'package:trovara/views/notes/research_panel_view_model.dart';
// Plus fakes for KnowledgeGraphService + VectorSearchService.

// Build a fake KnowledgeGraphService that returns canned semantic results
// and canned connections for a noteId. (Inline a _FakeGraphService class.)

void main() {
  // ... see plan-suite README for shared fakes; instantiate VM directly.

  test('search() populates results and notifies', () async {
    // Arrange fake returning 2 results
    // Act vm.search('quantum')
    // Assert vm.results.length == 2 && vm.isLoading == false
  });

  test('search() empty query clears results', () async {
    // ... call search('') and expect results == []
  });

  test('selectNote(noteId) loads in/out edges into inspector state', () async {
    // ... call vm.selectNote(42); expect vm.incomingEdges + outgoingEdges populated
  });

  test('loadStatistics() returns top concepts and citation counts', () async {
    // ... expect vm.topConcepts.length <= 20
  });
}
```

(Flesh out the test bodies using the same patterns as Phase 1 `KnowledgeGraphService` tests in `patrol_test/core/services/graph/`. Reuse those fakes — do not invent new ones.)

- [ ] **Step 2: Run to verify failure**

Run: `flutter test patrol_test/views/notes/research_panel_view_model_test.dart`
Expected: FAIL — class does not exist.

- [ ] **Step 3: Write the ViewModel**

```dart
// lib/views/notes/research_panel_view_model.dart
import 'package:trovara/core/base/base_view_model.dart';
import 'package:trovara/core/services/graph/knowledge_graph_service.dart';
import 'package:trovara/models/graph_edge.dart';
import 'package:trovara/models/note.dart';

class SemanticResult {
  final Note note;
  final double score;
  const SemanticResult(this.note, this.score);
}

class TopConcept {
  final String label;
  final int connections;
  const TopConcept(this.label, this.connections);
}

class ResearchPanelViewModel extends BaseViewModel {
  ResearchPanelViewModel({required KnowledgeGraphService graph}) : _graph = graph;

  final KnowledgeGraphService _graph;

  // Explorer
  String _query = '';
  List<SemanticResult> _results = const [];
  bool _isSearching = false;

  // Inspector
  int? _selectedNoteId;
  List<GraphEdge> _incoming = const [];
  List<GraphEdge> _outgoing = const [];

  // Stats
  List<TopConcept> _topConcepts = const [];
  Map<String, int> _citationCounts = const {};

  String get query => _query;
  List<SemanticResult> get results => _results;
  bool get isSearching => _isSearching;
  int? get selectedNoteId => _selectedNoteId;
  List<GraphEdge> get incomingEdges => _incoming;
  List<GraphEdge> get outgoingEdges => _outgoing;
  List<TopConcept> get topConcepts => _topConcepts;
  Map<String, int> get citationCounts => _citationCounts;

  Future<void> search(String query) async {
    _query = query.trim();
    if (_query.isEmpty) {
      _results = const [];
      notifyListeners();
      return;
    }
    _isSearching = true;
    notifyListeners();
    _results = await _graph.semanticSearch(_query);
    _isSearching = false;
    notifyListeners();
  }

  Future<void> selectNote(int noteId) async {
    _selectedNoteId = noteId;
    final edges = await _graph.edgesForNote(noteId);
    _incoming = edges.where((e) => e.targetNoteId == noteId).toList();
    _outgoing = edges.where((e) => e.sourceNoteId == noteId).toList();
    notifyListeners();
  }

  Future<void> loadStatistics() async {
    _topConcepts = await _graph.topConnectedConcepts(limit: 20);
    _citationCounts = await _graph.citationFrequency();
    notifyListeners();
  }
}
```

> If `KnowledgeGraphService` does not expose `semanticSearch`, `edgesForNote`, `topConnectedConcepts`, or `citationFrequency`, add thin wrappers on the service that compose existing Phase 1 methods. Do **not** call repositories directly from the ViewModel.

- [ ] **Step 4: Run tests**

Run: `flutter test patrol_test/views/notes/research_panel_view_model_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/views/notes/research_panel_view_model.dart patrol_test/views/notes/research_panel_view_model_test.dart
git commit -m "feat(notes): add ResearchPanelViewModel for explorer/inspector/stats"
```

---

### Task 4: SemanticExplorerWidget

**Files:** `lib/views/notes/widgets/semantic_explorer_widget.dart`

- [ ] **Step 1: Write the widget**

```dart
// lib/views/notes/widgets/semantic_explorer_widget.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:trovara/views/notes/research_panel_view_model.dart';

class SemanticExplorerWidget extends StatefulWidget {
  const SemanticExplorerWidget({super.key});
  @override
  State<SemanticExplorerWidget> createState() => _State();
}

class _State extends State<SemanticExplorerWidget> {
  final _controller = TextEditingController();

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ResearchPanelViewModel>();
    final theme = Theme.of(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: tr('pro.researcher.search_hint'),
            prefixIcon: const Icon(LucideIcons.search),
            suffixIcon: IconButton(
              icon: const Icon(LucideIcons.arrowRight),
              onPressed: () => vm.search(_controller.text),
            ),
          ),
          onSubmitted: vm.search,
        ),
      ),
      if (vm.isSearching) const LinearProgressIndicator(),
      Expanded(
        child: vm.results.isEmpty
            ? Center(child: Text(tr('pro.researcher.empty_explorer'),
                style: theme.textTheme.bodyMedium))
            : ListView.separated(
                itemCount: vm.results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final r = vm.results[i];
                  return ListTile(
                    title: Text(r.note.title),
                    subtitle: Text('${(r.score * 100).toStringAsFixed(0)}%'),
                    onTap: () {
                      vm.selectNote(r.note.id);
                      context.push('/note?title=${Uri.encodeComponent(r.note.title)}');
                    },
                  );
                },
              ),
      ),
    ]);
  }
}
```

- [ ] **Step 2: Run analyze**

Run: `flutter analyze lib/views/notes/widgets/semantic_explorer_widget.dart`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add lib/views/notes/widgets/semantic_explorer_widget.dart
git commit -m "feat(notes): add SemanticExplorerWidget for research panel"
```

---

### Task 5: ConnectionInspectorWidget

**Files:** `lib/views/notes/widgets/connection_inspector_widget.dart`

- [ ] **Step 1: Write the widget**

```dart
// lib/views/notes/widgets/connection_inspector_widget.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trovara/models/graph_edge.dart';
import 'package:trovara/views/notes/research_panel_view_model.dart';

class ConnectionInspectorWidget extends StatelessWidget {
  const ConnectionInspectorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ResearchPanelViewModel>();
    if (vm.selectedNoteId == null) {
      return Center(
        child: Text(tr('pro.researcher.empty_explorer'),
            style: Theme.of(context).textTheme.bodyMedium),
      );
    }
    return ListView(children: [
      ExpansionTile(
        title: Text(tr('pro.researcher.inspector_referenced_by',
            namedArgs: {'count': vm.incomingEdges.length.toString()})),
        children: vm.incomingEdges.map(_edgeTile).toList(),
      ),
      ExpansionTile(
        title: Text(tr('pro.researcher.inspector_references',
            namedArgs: {'count': vm.outgoingEdges.length.toString()})),
        children: vm.outgoingEdges.map(_edgeTile).toList(),
      ),
    ]);
  }

  Widget _edgeTile(GraphEdge edge) => ListTile(
        title: Text('Note #${edge.targetNoteId}'), // resolve title via VM helper if exposed
        trailing: _EdgeChip(type: edge.type),
      );
}

class _EdgeChip extends StatelessWidget {
  const _EdgeChip({required this.type});
  final String type;
  @override
  Widget build(BuildContext context) {
    final key = switch (type) {
      'semantic' => 'pro.researcher.edge_semantic',
      'citation' => 'pro.researcher.edge_citation',
      _ => 'pro.researcher.edge_hierarchical',
    };
    return Chip(label: Text(tr(key)));
  }
}
```

> If resolving `targetNoteId → title` requires a new VM method, add `String titleFor(int noteId)` to `ResearchPanelViewModel` and a backing cache built during `selectNote`.

- [ ] **Step 2: Commit**

```bash
git add lib/views/notes/widgets/connection_inspector_widget.dart
git commit -m "feat(notes): add ConnectionInspectorWidget for research panel"
```

---

### Task 6: StatisticsDashboardWidget

**Files:** `lib/views/notes/widgets/statistics_dashboard_widget.dart`

- [ ] **Step 1: Write the widget using fl_chart BarChart**

```dart
// lib/views/notes/widgets/statistics_dashboard_widget.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:trovara/views/notes/research_panel_view_model.dart';

class StatisticsDashboardWidget extends StatefulWidget {
  const StatisticsDashboardWidget({super.key});
  @override
  State<StatisticsDashboardWidget> createState() => _State();
}

class _State extends State<StatisticsDashboardWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ResearchPanelViewModel>().loadStatistics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ResearchPanelViewModel>();
    final theme = Theme.of(context);
    return ListView(padding: const EdgeInsets.all(12), children: [
      Text(tr('pro.researcher.stats_top_concepts'), style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      SizedBox(
        height: 220,
        child: BarChart(BarChartData(
          barGroups: [
            for (var i = 0; i < vm.topConcepts.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: vm.topConcepts[i].connections.toDouble(),
                  color: theme.colorScheme.primary,
                ),
              ]),
          ],
        )),
      ),
      const SizedBox(height: 16),
      Text(tr('pro.researcher.stats_citations'), style: theme.textTheme.titleMedium),
      for (final entry in vm.citationCounts.entries)
        ListTile(
          dense: true,
          title: Text(entry.key),
          trailing: Text('${entry.value}'),
        ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        icon: const Icon(LucideIcons.download),
        label: Text(tr('pro.researcher.stats_export_csv')),
        onPressed: () { /* delegate to ExportService via VM in follow-up */ },
      ),
    ]);
  }
}
```

> The "Export as CSV" button stub is intentional — wire it to `ExportService.toCsv(...)` when Sub-phase 3 lands. Mark with a `// TODO(sub-phase-3)` comment **only if** the spec change predates it.

- [ ] **Step 2: Commit**

```bash
git add lib/views/notes/widgets/statistics_dashboard_widget.dart
git commit -m "feat(notes): add StatisticsDashboardWidget with fl_chart bar chart"
```

---

### Task 7: ResearchPanelView shell + route

**Files:**
- Create: `lib/views/notes/research_panel_view.dart`
- Modify: `lib/core/route/app_router.dart`

- [ ] **Step 1: Write the panel**

```dart
// lib/views/notes/research_panel_view.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trovara/core/base/view_model_provider.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/views/notes/research_panel_view_model.dart';
import 'package:trovara/views/notes/widgets/connection_inspector_widget.dart';
import 'package:trovara/views/notes/widgets/semantic_explorer_widget.dart';
import 'package:trovara/views/notes/widgets/statistics_dashboard_widget.dart';

class ResearchPanelView extends StatelessWidget {
  const ResearchPanelView({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelProvider<ResearchPanelViewModel>(
      create: (_) => ResearchPanelViewModel(graph: ServiceLocator().knowledgeGraphService),
      child: const _Shell(),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('pro.researcher.panel_title')),
          bottom: TabBar(tabs: [
            Tab(text: tr('pro.researcher.tab_explorer')),
            Tab(text: tr('pro.researcher.tab_inspector')),
            Tab(text: tr('pro.researcher.tab_stats')),
          ]),
        ),
        body: const TabBarView(children: [
          SemanticExplorerWidget(),
          ConnectionInspectorWidget(),
          StatisticsDashboardWidget(),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 2: Register route**

In `app_router.dart`:

```dart
GoRoute(
  path: '/pro/research',
  name: 'research',
  builder: (context, state) => const ResearchPanelView(),
),
```

- [ ] **Step 3: Commit**

```bash
git add lib/views/notes/research_panel_view.dart lib/core/route/app_router.dart
git commit -m "feat(notes): add ResearchPanelView shell + /pro/research route"
```

---

### Task 8: Wire NoteView app-bar icon with Pro gate

**Files:** `lib/views/notes/note_view.dart`

- [ ] **Step 1: Add icon to NoteView AppBar**

```dart
IconButton(
  icon: const Icon(LucideIcons.telescope),
  tooltip: tr('pro.researcher.panel_title'),
  onPressed: () {
    final pro = ServiceLocator().proAccessService;
    if (!pro.isProUnlocked) {
      context.push('/pro/paywall');
    } else {
      context.push('/pro/research');
    }
  },
),
```

- [ ] **Step 2: Manually verify**

Launch staging app → open a note → tap telescope icon → paywall (locked) or research panel (unlocked).

- [ ] **Step 3: Commit**

```bash
git add lib/views/notes/note_view.dart
git commit -m "feat(notes): add research panel entry point in NoteView"
```

---

## Self-Review Checklist

- [ ] `flutter analyze` clean.
- [ ] `flutter test patrol_test/views/notes/` passes.
- [ ] `/i18n-check` parity.
- [ ] No widget file exceeds 300 LOC (split further if needed).
- [ ] All icons from `lucide_icons_flutter`.
- [ ] No `colorScheme` colors hardcoded.
- [ ] Pro gate works: locked → paywall; unlocked → panel.

## Out of Scope

- "Export as CSV" wiring — completed in Sub-phase 3 (Writer).
- Inline graph thumbnails — full graph viz is Sub-phase 6.
