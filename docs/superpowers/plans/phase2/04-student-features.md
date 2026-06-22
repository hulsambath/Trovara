# Sub-Phase 4: Student Features (Quiz Generator → Taking → Results)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Parent spec:** `docs/superpowers/specs/2026-05-22-trovara-pro-phase2-design.md` (Part 3.4)
**Depends on:** Sub-phase 1 (paywall), Phase 1 (`QuizGeneratorService`, `IProjectBundleRepository`).
**Blocks:** Sub-phase 6 (study groups reuse quiz models + share tokens).

**Goal:** Three-step quiz flow — Generator (select notes/projects + count + difficulty) → Taking (one question per page, timer, spaced-repetition re-queue) → Results (score, per-question review, weak-note links, history chart).

**Architecture:** Each step is a separate route with its own VM. State is passed between routes via constructor parameters on push (Quiz session DTOs) — not through a shared singleton. Spaced repetition is in-memory for the active session in MVP (SM-2 storage deferred to Phase 3); incorrect answers append to a re-queue list inside `QuizTakingViewModel`. A new lightweight `QuizSession` value-object groups questions + answers.

**Tech Stack:** Flutter, `provider`, `fl_chart` (already added in Sub-phase 2), `easy_localization`, `lucide_icons_flutter`, `patrol_finders`.

---

## File Structure

### Create

- `lib/views/pro/quiz_generator_view.dart`
- `lib/views/pro/quiz_generator_view_model.dart`
- `lib/views/pro/quiz_taking_view.dart`
- `lib/views/pro/quiz_taking_view_model.dart`
- `lib/views/pro/quiz_results_view.dart`
- `lib/views/pro/quiz_results_view_model.dart`
- `lib/views/pro/widgets/quiz_question_card.dart` — shared question renderer
- `lib/models/quiz_session.dart` — in-memory DTO (not an ObjectBox entity)
- `patrol_test/views/pro/quiz_generator_view_model_test.dart`
- `patrol_test/views/pro/quiz_taking_view_model_test.dart`
- `patrol_test/views/pro/quiz_results_view_model_test.dart`

### Modify

- `lib/core/route/app_router.dart` — register `/pro/quiz/generate`, `/pro/quiz/take`, `/pro/quiz/results`
- `assets/translations/en.json` — `pro.student.*`
- `assets/translations/km.json` — mirror

---

## Tasks

### Task 1: Add student i18n keys

**Files:** `assets/translations/en.json`, `assets/translations/km.json`

- [ ] **Step 1: Append `pro.student` block**

```json
"student": {
  "generator_title": "Generate quiz",
  "generator_select_notes": "Select notes",
  "generator_select_projects": "Select projects",
  "generator_count": "Number of questions",
  "generator_difficulty": "Difficulty",
  "difficulty_mixed": "Mixed",
  "difficulty_easy": "Easy",
  "difficulty_medium": "Medium",
  "difficulty_hard": "Hard",
  "generate_cta": "Generate quiz",
  "generating": "Generating quiz…",
  "generation_failed": "Generation failed: {message}",
  "taking_question_n_of_m": "Question {n} of {m}",
  "submit_answer": "Submit answer",
  "next_question": "Next question",
  "correct": "Correct",
  "incorrect": "Incorrect",
  "explanation": "Explanation",
  "results_score": "You scored {correct} / {total} ({percent}%)",
  "results_review_weak": "Review weak notes",
  "results_take_again": "Take again",
  "results_new_quiz": "New quiz",
  "results_history": "Previous sessions"
}
```

- [ ] **Step 2: Mirror, verify `/i18n-check`, commit**

```bash
git add assets/translations/
git commit -m "feat(ui): add pro.student localization keys"
```

---

### Task 2: QuizSession DTO

**Files:** `lib/models/quiz_session.dart`

- [ ] **Step 1: Define value classes**

```dart
// lib/models/quiz_session.dart
enum QuizDifficulty { mixed, easy, medium, hard }

class QuizQuestion {
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final int sourceNoteId;
  const QuizQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.sourceNoteId,
  });
}

class QuizAnswer {
  final int questionIndex;
  final int selectedIndex;
  final bool correct;
  const QuizAnswer(this.questionIndex, this.selectedIndex, this.correct);
}

class QuizSession {
  final List<QuizQuestion> questions;
  final List<QuizAnswer> answers;
  final DateTime startedAt;
  const QuizSession({
    required this.questions,
    required this.answers,
    required this.startedAt,
  });
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/models/quiz_session.dart
git commit -m "feat(models): add QuizSession DTO (in-memory)"
```

---

### Task 3: QuizGeneratorViewModel (TDD)

**Files:**

- Create: `lib/views/pro/quiz_generator_view_model.dart`
- Test: `patrol_test/views/pro/quiz_generator_view_model_test.dart`

- [ ] **Step 1: Test**

```dart
// Exercise: select notes, set count + difficulty, generate, success, failure, timeout, cancel.
test('generate() success populates session and clears isGenerating', () async { /* ... */ });
test('generate() failure sets errorMessage', () async { /* ... */ });
test('cancel() during generation aborts and clears isGenerating', () async { /* ... */ });
test('selectedNoteIds toggle add/remove', () { /* ... */ });
```

- [ ] **Step 2: Implement**

```dart
// lib/views/pro/quiz_generator_view_model.dart
import 'dart:async';
import 'package:trovara/core/base/base_view_model.dart';
import 'package:trovara/core/services/quiz/quiz_generator_service.dart';
import 'package:trovara/models/quiz_session.dart';

class QuizGeneratorViewModel extends BaseViewModel {
  QuizGeneratorViewModel({required QuizGeneratorService service}) : _service = service;

  final QuizGeneratorService _service;

  final Set<int> _noteIds = {};
  final Set<int> _projectIds = {};
  int _count = 10;
  QuizDifficulty _difficulty = QuizDifficulty.mixed;
  bool _isGenerating = false;
  String? _errorMessage;
  QuizSession? _session;
  Completer<void>? _cancel;

  Set<int> get selectedNoteIds => _noteIds;
  Set<int> get selectedProjectIds => _projectIds;
  int get count => _count;
  QuizDifficulty get difficulty => _difficulty;
  bool get isGenerating => _isGenerating;
  String? get errorMessage => _errorMessage;
  QuizSession? get session => _session;

  void toggleNote(int id) {
    _noteIds.contains(id) ? _noteIds.remove(id) : _noteIds.add(id);
    notifyListeners();
  }
  void toggleProject(int id) {
    _projectIds.contains(id) ? _projectIds.remove(id) : _projectIds.add(id);
    notifyListeners();
  }
  void setCount(int v) { _count = v; notifyListeners(); }
  void setDifficulty(QuizDifficulty d) { _difficulty = d; notifyListeners(); }

  Future<void> generate() async {
    _isGenerating = true; _errorMessage = null; _session = null;
    _cancel = Completer<void>();
    notifyListeners();
    try {
      final questions = await _service.generate(
        noteIds: _noteIds.toList(),
        projectIds: _projectIds.toList(),
        count: _count,
        difficulty: _difficulty,
      ).timeout(const Duration(seconds: 15));
      if (_cancel?.isCompleted ?? false) return;
      _session = QuizSession(questions: questions, answers: const [], startedAt: DateTime.now());
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isGenerating = false; notifyListeners();
    }
  }

  void cancel() {
    if (_cancel != null && !_cancel!.isCompleted) _cancel!.complete();
    _isGenerating = false; notifyListeners();
  }
}
```

> If `QuizGeneratorService.generate(...)` does not yet accept these parameters in Phase 1, add an overload that does — do not branch on `null`s in this VM.

- [ ] **Step 3: Verify pass + commit**

```bash
git add lib/views/pro/quiz_generator_view_model.dart patrol_test/views/pro/quiz_generator_view_model_test.dart
git commit -m "feat(pro): add QuizGeneratorViewModel"
```

---

### Task 4: QuizGeneratorView

**Files:** `lib/views/pro/quiz_generator_view.dart`

- [ ] **Step 1: Write the view**

`Scaffold` with a `ListView` body: `CheckboxListTile`s for notes/projects (paged if more than 50), `Slider` for count, `SegmentedButton<QuizDifficulty>`, `FilledButton`. On success, `context.go('/pro/quiz/take', extra: vm.session)`.

- [ ] **Step 2: Commit**

```bash
git add lib/views/pro/quiz_generator_view.dart
git commit -m "feat(pro): add QuizGeneratorView UI"
```

---

### Task 5: QuizTakingViewModel (TDD with spaced repetition)

**Files:**

- Create: `lib/views/pro/quiz_taking_view_model.dart`
- Test: `patrol_test/views/pro/quiz_taking_view_model_test.dart`

- [ ] **Step 1: Test**

```dart
test('submitAnswer with correct index records correct answer and advances', () { /* ... */ });
test('submitAnswer with wrong index re-queues question to end', () { /* ... */ });
test('completes when re-queue is empty and all questions answered correctly', () { /* ... */ });
test('score = correct / unique-questions, not / total-attempts', () { /* ... */ });
test('timer ticks down and emits onExpire on zero', () async { /* ... */ });
```

- [ ] **Step 2: Implement**

```dart
// lib/views/pro/quiz_taking_view_model.dart
import 'dart:async';
import 'package:trovara/core/base/base_view_model.dart';
import 'package:trovara/models/quiz_session.dart';

class QuizTakingViewModel extends BaseViewModel {
  QuizTakingViewModel({required QuizSession session, Duration? perQuestion})
      : _session = session,
        _perQuestion = perQuestion,
        _queue = List<int>.generate(session.questions.length, (i) => i);

  final QuizSession _session;
  final Duration? _perQuestion;
  final List<int> _queue;
  final List<QuizAnswer> _answers = [];
  int _correctCount = 0;
  Timer? _timer;
  int _secondsLeft = 0;
  bool _revealed = false;
  int? _selected;

  int get totalUnique => _session.questions.length;
  int get questionNumber => totalUnique - _queue.length + 1;
  int? get currentIndex => _queue.isEmpty ? null : _queue.first;
  QuizQuestion? get currentQuestion =>
      currentIndex == null ? null : _session.questions[currentIndex!];
  bool get isComplete => _queue.isEmpty;
  bool get revealed => _revealed;
  int? get selected => _selected;
  int get secondsLeft => _secondsLeft;
  int get correctCount => _correctCount;
  List<QuizAnswer> get answers => List.unmodifiable(_answers);

  void select(int i) { if (!_revealed) { _selected = i; notifyListeners(); } }

  void submitAnswer() {
    if (_selected == null || isComplete) return;
    final idx = _queue.first;
    final correct = _session.questions[idx].correctIndex == _selected;
    _answers.add(QuizAnswer(idx, _selected!, correct));
    if (correct) {
      _correctCount++;
      _queue.removeAt(0);
    } else {
      _queue.removeAt(0);
      _queue.add(idx); // re-queue
    }
    _revealed = true;
    notifyListeners();
  }

  void next() {
    _revealed = false; _selected = null;
    if (_perQuestion != null) _startTimer();
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = _perQuestion!.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _secondsLeft--;
      if (_secondsLeft <= 0) { submitAnswer(); _timer?.cancel(); }
      notifyListeners();
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
}
```

- [ ] **Step 3: Verify pass + commit**

```bash
git add lib/views/pro/quiz_taking_view_model.dart patrol_test/views/pro/quiz_taking_view_model_test.dart
git commit -m "feat(pro): add QuizTakingViewModel with spaced-repetition re-queue"
```

---

### Task 6: QuizTakingView + QuizQuestionCard widget

**Files:**

- Create: `lib/views/pro/quiz_taking_view.dart`
- Create: `lib/views/pro/widgets/quiz_question_card.dart`

- [ ] **Step 1: Build question card** — `RadioListTile` options, colored feedback after reveal (green / red), explanation text, "Submit"/"Next" button.

- [ ] **Step 2: Build view** — `PageView` driven by VM, top `LinearProgressIndicator` for progress, optional `CircularProgressIndicator` for timer.

On complete → `context.go('/pro/quiz/results', extra: vm.session.copyWith(answers: vm.answers))`.

- [ ] **Step 3: Commit**

```bash
git add lib/views/pro/quiz_taking_view.dart lib/views/pro/widgets/quiz_question_card.dart
git commit -m "feat(pro): add QuizTakingView with timer + progress"
```

---

### Task 7: QuizResultsViewModel + View

**Files:**

- Create: `lib/views/pro/quiz_results_view_model.dart`
- Create: `lib/views/pro/quiz_results_view.dart`
- Test: `patrol_test/views/pro/quiz_results_view_model_test.dart`

- [ ] **Step 1: VM test** — score calc, weak-note grouping (sourceNoteIds of incorrect answers, distinct), historical chart data (Phase 3: persisted; MVP returns `[]`).

- [ ] **Step 2: Implement VM**

```dart
class QuizResultsViewModel extends BaseViewModel {
  QuizResultsViewModel(this.session);
  final QuizSession session;
  int get totalUnique => session.questions.length;
  int get correctCount => session.answers.where((a) => a.correct).length;
  int get scorePercent => (correctCount * 100 / totalUnique).round();
  List<int> get weakNoteIds {
    final incorrect = session.answers.where((a) => !a.correct);
    return {for (final a in incorrect) session.questions[a.questionIndex].sourceNoteId}.toList();
  }
}
```

- [ ] **Step 3: Build results view** — score card, per-question `ListView` (green/red), weak-notes section with tappable links to `/note?title=...`, "Take again" + "New quiz" FAB options. Performance chart placeholder (`fl_chart BarChart` with empty data in MVP).

- [ ] **Step 4: Commit**

```bash
git add lib/views/pro/quiz_results_view.dart lib/views/pro/quiz_results_view_model.dart patrol_test/views/pro/quiz_results_view_model_test.dart
git commit -m "feat(pro): add QuizResultsView with score + weak notes"
```

---

### Task 8: Register quiz routes

**Files:** `lib/core/route/app_router.dart`

- [ ] **Step 1: Add routes**

```dart
GoRoute(path: '/pro/quiz/generate', builder: (_, __) => const QuizGeneratorView()),
GoRoute(
  path: '/pro/quiz/take',
  builder: (context, state) => QuizTakingView(session: state.extra as QuizSession),
),
GoRoute(
  path: '/pro/quiz/results',
  builder: (context, state) => QuizResultsView(session: state.extra as QuizSession),
),
```

- [ ] **Step 2: Add quiz entry point** to wherever appropriate (e.g., MainView Insights tab or a Pro menu). Gate behind ProAccessService.

- [ ] **Step 3: Manual smoke test**

Launch app → generate quiz (1 note, 3 questions) → take it (answer all) → see results.

- [ ] **Step 4: Commit**

```bash
git add lib/core/route/app_router.dart lib/views/main_view.dart
git commit -m "feat(pro): register /pro/quiz/* routes and entry point"
```

---

## Self-Review Checklist

- [ ] `flutter analyze` clean.
- [ ] `flutter test patrol_test/views/pro/quiz_*` passes.
- [ ] `/i18n-check` parity.
- [ ] Spaced repetition re-queues incorrect answers (verified manually with a 2-question deck).
- [ ] No file in `lib/views/pro/quiz_*` exceeds 300 LOC.
- [ ] Timer disposes on view pop (no leak warnings in console).
- [ ] All buttons gated on Pro at entry.

## Out of Scope

- Persistent quiz history (`fl_chart` history chart shows empty MVP).
- SM-2 algorithm implementation (deferred to Phase 3).
- Share-quiz link generation — moved to Sub-phase 6 (study groups).
