# Sub-Phase 6: Advanced Features (Graph Visualization + Study Groups)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Parent spec:** `docs/superpowers/specs/2026-05-22-trovara-pro-phase2-design.md` (Parts 3.6, 3.7)
**Depends on:** Sub-phase 1 (paywall), Sub-phase 4 (Quiz models), Phase 1 (`KnowledgeGraphService`, `IGraphRepository`).
**Blocks:** none.

**Goal:** Interactive force-directed graph view of the knowledge graph, plus a Study Groups screen that generates shareable deep links for quizzes and shows a local-only leaderboard.

**Architecture:** Two independent views. `GraphVisualizationView` uses the `graphview` package and limits nodes to the top 100 by in-degree when the graph exceeds 200 nodes. `StudyGroupView` reuses `QuizSession` from Sub-phase 4 and generates deep links via the `app_links` package (registered with an intent filter on the Android manifest). Both follow the standard VM pattern; both gate at entry on `ProAccessService`.

**Tech Stack:** Flutter, `graphview: ^1.2.x` (new dep), `app_links: ^3.x` (new dep), `provider`, `easy_localization`, `lucide_icons_flutter`, `patrol_finders`.

---

## File Structure

### Create
- `lib/views/pro/graph_visualization_view.dart`
- `lib/views/pro/graph_visualization_view_model.dart`
- `lib/views/pro/widgets/graph_legend.dart`
- `lib/views/pro/widgets/graph_node_inspector.dart`
- `lib/views/pro/study_group_view.dart`
- `lib/views/pro/study_group_view_model.dart`
- `lib/core/services/share/share_token_service.dart` — generates and parses share tokens
- `patrol_test/views/pro/graph_visualization_view_model_test.dart`
- `patrol_test/views/pro/study_group_view_model_test.dart`
- `patrol_test/core/services/share/share_token_service_test.dart`

### Modify
- `pubspec.yaml` — add `graphview`, `app_links`
- `android/app/src/main/AndroidManifest.xml` — add `<intent-filter>` for `trovara://quiz/...`
- `lib/core/di/service_locator.dart` — register `ShareTokenService`
- `lib/core/route/app_router.dart` — add `/pro/graph`, `/pro/study-group`; handle deep-link route `trovara://quiz/:token`
- `lib/initializer.dart` — initialize `app_links` listener
- `assets/translations/en.json` — `pro.graph.*`, `pro.studygroup.*`
- `assets/translations/km.json` — mirror

---

## Tasks

### Task 1: Add advanced libraries

**Files:** `pubspec.yaml`

- [ ] **Step 1: Add deps**

```yaml
graphview: ^1.2.0
app_links: ^3.5.0
```

- [ ] **Step 2: Resolve + commit**

```bash
flutter pub get
git add pubspec.yaml pubspec.lock
git commit -m "chore(deps): add graphview, app_links for advanced pro features"
```

---

### Task 2: Add i18n keys

**Files:** `assets/translations/en.json`, `km.json`

- [ ] **Step 1: Append blocks**

```json
"graph": {
  "title": "Knowledge graph",
  "edge_semantic": "Semantic",
  "edge_citation": "Citation",
  "edge_hierarchical": "Hierarchical",
  "filter_edges": "Filter edges",
  "showing_top_n": "Showing top {count} nodes by connection count",
  "node_inspector_connections": "Connections: {count}",
  "empty": "No notes connected yet."
},
"studygroup": {
  "title": "Study groups",
  "share_quiz": "Share this quiz",
  "share_copied": "Quiz link copied",
  "leaderboard": "Leaderboard",
  "no_shared_yet": "You haven't shared any quizzes.",
  "your_score": "You: {score}",
  "peer_score": "{name}: {score}"
}
```

- [ ] **Step 2: Mirror in km.json, `/i18n-check`, commit**

```bash
git add assets/translations/
git commit -m "feat(ui): add pro.graph + pro.studygroup localization keys"
```

---

### Task 3: ShareTokenService (TDD)

**Files:**
- Create: `lib/core/services/share/share_token_service.dart`
- Test: `patrol_test/core/services/share/share_token_service_test.dart`

- [ ] **Step 1: Test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/share/share_token_service.dart';
import 'package:trovara/models/quiz_session.dart';

void main() {
  test('encode then decode round-trips a session', () {
    final svc = ShareTokenService();
    final session = QuizSession(
      questions: [QuizQuestion(
        prompt: 'p', options: ['a', 'b'], correctIndex: 0,
        explanation: 'e', sourceNoteId: 1)],
      answers: const [],
      startedAt: DateTime.utc(2026, 1, 1),
    );
    final token = svc.encode(session);
    expect(token, isNotEmpty);
    final decoded = svc.decode(token);
    expect(decoded.questions.first.prompt, 'p');
    expect(decoded.questions.first.correctIndex, 0);
  });

  test('decode rejects malformed tokens', () {
    expect(() => ShareTokenService().decode('not-base64!'),
        throwsA(isA<FormatException>()));
  });

  test('deepLinkFor returns trovara://quiz/<token>', () {
    final svc = ShareTokenService();
    final url = svc.deepLinkFor('abc');
    expect(url, 'trovara://quiz/abc');
  });
}
```

- [ ] **Step 2: Implement**

```dart
// lib/core/services/share/share_token_service.dart
import 'dart:convert';
import 'package:trovara/models/quiz_session.dart';

class ShareTokenService {
  static const _scheme = 'trovara';

  String encode(QuizSession session) {
    final payload = {
      'q': session.questions.map((q) => {
            'p': q.prompt,
            'o': q.options,
            'c': q.correctIndex,
            'e': q.explanation,
            's': q.sourceNoteId,
          }).toList(),
      't': session.startedAt.toIso8601String(),
    };
    return base64UrlEncode(utf8.encode(jsonEncode(payload)));
  }

  QuizSession decode(String token) {
    final bytes = base64Url.decode(token);
    final raw = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final questions = (raw['q'] as List).map((j) {
      final m = j as Map<String, dynamic>;
      return QuizQuestion(
        prompt: m['p'] as String,
        options: List<String>.from(m['o'] as List),
        correctIndex: m['c'] as int,
        explanation: m['e'] as String,
        sourceNoteId: m['s'] as int,
      );
    }).toList();
    return QuizSession(
      questions: questions,
      answers: const [],
      startedAt: DateTime.parse(raw['t'] as String),
    );
  }

  String deepLinkFor(String token) => '$_scheme://quiz/$token';
}
```

- [ ] **Step 3: Verify pass + commit**

```bash
flutter test patrol_test/core/services/share/share_token_service_test.dart
git add lib/core/services/share/ patrol_test/core/services/share/
git commit -m "feat(core): add ShareTokenService for quiz deep-links"
```

---

### Task 4: Register ShareTokenService + Android intent filter

**Files:**
- Modify: `lib/core/di/service_locator.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Lazy getter**

```dart
ShareTokenService? _shareTokenService;
ShareTokenService get shareTokenService => _shareTokenService ??= ShareTokenService();
```

- [ ] **Step 2: Manifest intent filter** (inside `<activity android:name=".MainActivity">`)

```xml
<intent-filter android:autoVerify="false">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="trovara" android:host="quiz" />
</intent-filter>
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/di/service_locator.dart android/app/src/main/AndroidManifest.xml
git commit -m "feat(core): wire ShareTokenService and trovara:// intent filter"
```

---

### Task 5: app_links listener in initializer

**Files:** `lib/initializer.dart`

- [ ] **Step 1: Add listener after `ServiceLocator().initialize()`**

```dart
final appLinks = AppLinks();
appLinks.uriLinkStream.listen((uri) {
  if (uri.scheme == 'trovara' && uri.host == 'quiz') {
    final token = uri.pathSegments.firstOrNull;
    if (token == null) return;
    final session = ServiceLocator().shareTokenService.decode(token);
    rootNavigatorKey.currentContext?.go('/pro/quiz/take', extra: session);
  }
});
```

(Expose `rootNavigatorKey` from `app_router.dart` if not already exposed.)

- [ ] **Step 2: Commit**

```bash
git add lib/initializer.dart lib/core/route/app_router.dart
git commit -m "feat(core): listen for trovara://quiz deep links on startup"
```

---

### Task 6: GraphVisualizationViewModel (TDD)

**Files:**
- Create: `lib/views/pro/graph_visualization_view_model.dart`
- Test: `patrol_test/views/pro/graph_visualization_view_model_test.dart`

- [ ] **Step 1: Test**

```dart
test('load() returns all nodes when count <= 200', () { /* assert vm.nodes.length == graphNodeCount */ });
test('load() returns top 100 by in-degree when count > 200', () { /* assert vm.truncated == true && nodes.length == 100 */ });
test('selectNode(id) populates inspector', () { /* assert vm.inspectorConnections > 0 */ });
test('toggleEdgeTypeFilter("semantic") removes those edges', () { /* assert vm.visibleEdges.where(...).isEmpty */ });
```

- [ ] **Step 2: Implement**

```dart
// lib/views/pro/graph_visualization_view_model.dart
import 'package:trovara/core/base/base_view_model.dart';
import 'package:trovara/core/services/graph/knowledge_graph_service.dart';
import 'package:trovara/models/graph_edge.dart';
import 'package:trovara/models/graph_node.dart';

class GraphVisualizationViewModel extends BaseViewModel {
  GraphVisualizationViewModel({required KnowledgeGraphService graph}) : _graph = graph;
  static const int _displayCap = 100;
  static const int _truncateThreshold = 200;

  final KnowledgeGraphService _graph;

  List<GraphNode> _nodes = const [];
  List<GraphEdge> _edges = const [];
  bool _truncated = false;
  int? _selectedNodeId;
  final Set<String> _hiddenEdgeTypes = {};

  List<GraphNode> get nodes => _nodes;
  List<GraphEdge> get visibleEdges =>
      _edges.where((e) => !_hiddenEdgeTypes.contains(e.type)).toList();
  bool get truncated => _truncated;
  int? get selectedNodeId => _selectedNodeId;
  Set<String> get hiddenEdgeTypes => _hiddenEdgeTypes;

  int inspectorConnections(int nodeId) =>
      _edges.where((e) => e.sourceNoteId == nodeId || e.targetNoteId == nodeId).length;

  Future<void> load() async {
    final allNodes = await _graph.allNodes();
    final allEdges = await _graph.allEdges();
    _truncated = allNodes.length > _truncateThreshold;
    if (_truncated) {
      final degree = <int, int>{};
      for (final e in allEdges) {
        degree[e.targetNoteId] = (degree[e.targetNoteId] ?? 0) + 1;
      }
      allNodes.sort((a, b) =>
          (degree[b.noteId] ?? 0).compareTo(degree[a.noteId] ?? 0));
      _nodes = allNodes.take(_displayCap).toList();
      final keepIds = _nodes.map((n) => n.noteId).toSet();
      _edges = allEdges
          .where((e) => keepIds.contains(e.sourceNoteId) && keepIds.contains(e.targetNoteId))
          .toList();
    } else {
      _nodes = allNodes;
      _edges = allEdges;
    }
    notifyListeners();
  }

  void selectNode(int nodeId) { _selectedNodeId = nodeId; notifyListeners(); }

  void toggleEdgeTypeFilter(String type) {
    _hiddenEdgeTypes.contains(type)
        ? _hiddenEdgeTypes.remove(type)
        : _hiddenEdgeTypes.add(type);
    notifyListeners();
  }
}
```

> Verify `KnowledgeGraphService.allNodes()` and `allEdges()` exist; if not, add thin wrappers over `IGraphRepository`.

- [ ] **Step 3: Pass + commit**

```bash
git add lib/views/pro/graph_visualization_view_model.dart patrol_test/views/pro/graph_visualization_view_model_test.dart
git commit -m "feat(pro): add GraphVisualizationViewModel with top-100 cap"
```

---

### Task 7: GraphVisualizationView + legend + inspector

**Files:**
- Create: `lib/views/pro/graph_visualization_view.dart`
- Create: `lib/views/pro/widgets/graph_legend.dart`
- Create: `lib/views/pro/widgets/graph_node_inspector.dart`

- [ ] **Step 1: Build GraphLegend** — small `Card` with three color swatches mapping to `pro.graph.edge_*`.

- [ ] **Step 2: Build GraphNodeInspector** — bottom sheet showing connection count + top connections (use VM's `inspectorConnections` + a `graph.topConnectionsFor(nodeId)` method).

- [ ] **Step 3: Build GraphVisualizationView** using `graphview`'s `GraphView` widget inside an `InteractiveViewer`. Map edge types to `colorScheme.primary` (semantic), `tertiary` (citation), `secondary` (hierarchical). Show "Showing top 100 nodes" `MaterialBanner` when `vm.truncated`. Tap node → `selectNode(id)` → bottom sheet.

```dart
// Sketch of the build method, not the full file:
final graph = Graph();
for (final n in vm.nodes) {
  graph.addNode(Node.Id(n.noteId));
}
for (final e in vm.visibleEdges) {
  graph.addEdge(Node.Id(e.sourceNoteId), Node.Id(e.targetNoteId));
}
return InteractiveViewer(
  constrained: false,
  child: GraphView(
    graph: graph,
    algorithm: FruchtermanReingoldAlgorithm(),
    builder: (node) => _NodeChip(noteId: node.key!.value as int),
  ),
);
```

- [ ] **Step 4: Commit**

```bash
git add lib/views/pro/graph_visualization_view.dart lib/views/pro/widgets/graph_legend.dart lib/views/pro/widgets/graph_node_inspector.dart
git commit -m "feat(pro): add GraphVisualizationView with force-directed layout"
```

---

### Task 8: StudyGroupViewModel + View

**Files:**
- Create: `lib/views/pro/study_group_view_model.dart`
- Create: `lib/views/pro/study_group_view.dart`
- Test: `patrol_test/views/pro/study_group_view_model_test.dart`

- [ ] **Step 1: VM test** — share link generation, clipboard copy via fake clipboard, peer score listing (empty in MVP).

- [ ] **Step 2: Implement VM**

```dart
class StudyGroupViewModel extends BaseViewModel {
  StudyGroupViewModel({required ShareTokenService share}) : _share = share;
  final ShareTokenService _share;

  String? _lastLink;
  String? get lastLink => _lastLink;

  Future<void> shareQuiz(QuizSession session) async {
    final token = _share.encode(session);
    _lastLink = _share.deepLinkFor(token);
    await Clipboard.setData(ClipboardData(text: _lastLink!));
    notifyListeners();
  }

  // MVP: leaderboard returns empty; cloud-backed comparison deferred to Phase 3.
  List<({String name, int score})> get leaderboard => const [];
}
```

- [ ] **Step 3: Build view** — list of shared links (in MVP just shows `_lastLink`), "Share this quiz" button (requires an incoming `QuizSession` via constructor or route extra), leaderboard placeholder section.

- [ ] **Step 4: Commit**

```bash
git add lib/views/pro/study_group_view.dart lib/views/pro/study_group_view_model.dart patrol_test/views/pro/study_group_view_model_test.dart
git commit -m "feat(pro): add StudyGroupView with share-link generation"
```

---

### Task 9: Register routes + wire entry points

**Files:** `lib/core/route/app_router.dart`, `lib/views/main_view.dart`

- [ ] **Step 1: Register routes**

```dart
GoRoute(path: '/pro/graph', builder: (_, __) => const GraphVisualizationView()),
GoRoute(path: '/pro/study-group', builder: (_, __) => const StudyGroupView()),
```

- [ ] **Step 2: Add entry points** in the Insights tab or a Pro menu. Both gated behind `ProAccessService`.

- [ ] **Step 3: Manual end-to-end smoke test**

1. Create 5 notes with some shared content → KnowledgeGraphService produces edges.
2. Open `/pro/graph` → see nodes + edges → tap node → inspector.
3. Generate quiz from Sub-phase 4 → tap "Share" in StudyGroup → link copied.
4. Paste link in a terminal: `adb shell am start -W -a android.intent.action.VIEW -d "trovara://quiz/<token>"`.
5. App opens directly into the quiz-taking view.

- [ ] **Step 4: Commit**

```bash
git add lib/core/route/app_router.dart lib/views/main_view.dart
git commit -m "feat(pro): register graph + study-group routes and entry points"
```

---

## Self-Review Checklist

- [ ] `flutter analyze` clean.
- [ ] `flutter test patrol_test/views/pro/graph_visualization_view_model_test.dart patrol_test/views/pro/study_group_view_model_test.dart patrol_test/core/services/share/share_token_service_test.dart` passes.
- [ ] `/i18n-check` parity.
- [ ] Deep link `trovara://quiz/<token>` launches the app and routes to `/pro/quiz/take`.
- [ ] Graph view caps at 100 nodes when graph has more than 200 nodes; "Showing top 100 nodes" banner visible.
- [ ] No file in `lib/views/pro/graph_*` or `lib/views/pro/widgets/graph_*` exceeds 300 LOC.
- [ ] All edge colors use `theme.colorScheme.*`; legend matches.

## Out of Scope

- Cloud-backed leaderboard with real peer scores (Phase 3 cloud sync).
- iOS universal links (deferred with iOS variant).
- Custom canvas graph renderer (using `graphview` package per spec).
- Server-side share token validation (links are purely client-side payloads).

---

## Phase 2 Wrap-Up

After this sub-phase merges, run the full Phase 2 acceptance pass:

- [ ] `flutter analyze` clean across all of `lib/`.
- [ ] `flutter test patrol_test/` — all green; no regressions in the 255 Phase 1 tests.
- [ ] `/i18n-check` reports parity.
- [ ] Manual smoke: unlock paywall → researcher → writer → student → collaborative → graph → study-group flows all work end-to-end.
- [ ] All performance targets in Part 6 of the spec are met (manually verified or instrumented).
