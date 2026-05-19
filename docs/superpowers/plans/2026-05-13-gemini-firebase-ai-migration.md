# Gemini Firebase AI Migration Implementation Plan

> **For agentic workers:** Before executing, invoke skill `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans`. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `google_generative_ai` (API key required) with `firebase_ai` (Gemini Developer API free tier via Firebase project auth) across `LlmClient` and `EmbeddingService`.

**Architecture:** Two private provider classes in `_providers/` own all `firebase_ai` import surface; `LlmClient` and `EmbeddingService` delegate to them, keeping their own files under 300 LOC. `ServiceLocator` makes Firebase Gemini the default when no OpenAI/OpenRouter key is configured.

**Tech Stack:** `firebase_ai` (replaces `google_generative_ai`), Dart 3.8 records, existing `firebase_core: ^4.4.0`.

**Spec:** `docs/superpowers/specs/2026-05-13-gemini-agent-migration-design.md`

---

## File Map

| Action | File | Result |
|---|---|---|
| MODIFY | `pubspec.yaml` | swap packages |
| CREATE | `lib/core/services/ai/embedding_chunker.dart` | chunking + signature logic extracted from EmbeddingService |
| CREATE | `lib/core/services/ai/_providers/firebase_gemini_embedding_provider.dart` | Firebase AI embedding |
| MODIFY | `lib/core/services/ai/embedding_service.dart` | use chunker + provider, remove Gemini SDK + fallback chains |
| CREATE | `lib/core/services/ai/_providers/firebase_gemini_llm_provider.dart` | Firebase AI generation |
| MODIFY | `lib/core/services/ai/llm_client.dart` | use Firebase provider, remove Gemini helpers + fallbacks |
| MODIFY | `lib/core/di/service_locator.dart` | Firebase Gemini as default path |
| MODIFY | `lib/constants/config_constants.dart` | deprecate unused Gemini key constants |
| CREATE | `patrol_test/core/services/embedding_chunker_test.dart` | tests for extracted chunker |

---

## Before You Start

Enable Gemini Developer API in Firebase Console for both projects:
- Firebase Console → select project → **Build → AI** → enable **Gemini Developer API**
- Repeat for staging and prod projects
- No changes to `google-services.json` or `GoogleService-Info.plist` are needed

---

## Task 1: Swap packages in pubspec.yaml

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Remove `google_generative_ai`, add `firebase_ai`**

In `pubspec.yaml`, under `dependencies:`, remove:
```yaml
  google_generative_ai: ^0.4.7
```
Add:
```yaml
  firebase_ai: ^2.1.0
```

> If `flutter pub get` reports a version conflict with `firebase_core: ^4.4.0`, check https://pub.dev/packages/firebase_ai for the latest version compatible with your firebase_core version and use that instead.

- [ ] **Step 2: Run pub get**

```bash
flutter pub get
```

Expected: resolves without error. Ignore compilation errors — imports still reference `google_generative_ai` in source files; those are fixed in later tasks.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(deps): replace google_generative_ai with firebase_ai"
```

---

## Task 2: Extract EmbeddingChunker

Extract chunking and signature logic from `EmbeddingService` into a standalone static helper. This is required to bring `embedding_service.dart` under the 300-LOC hard limit.

**Files:**
- Create: `lib/core/services/ai/embedding_chunker.dart`
- Create: `patrol_test/core/services/embedding_chunker_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `patrol_test/core/services/embedding_chunker_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/ai/embedding_chunker.dart';
import '../test_support.dart';

void main() {
  // ── chunkText ──────────────────────────────────────────────────────────────

  group('EmbeddingChunker.chunkText', () {
    patrolTest('short text returns single chunk', ($) async {
      final chunks = EmbeddingChunker.chunkText('Hello world');
      expect(chunks, hasLength(1));
      expect(chunks.first, 'Hello world');
    });

    patrolTest('empty text returns empty list', ($) async {
      expect(EmbeddingChunker.chunkText(''), isEmpty);
    });

    patrolTest('long text produces multiple chunks with overlap', ($) async {
      final text = 'A' * 2500;
      final chunks = EmbeddingChunker.chunkText(text);
      expect(chunks.length, greaterThan(1));
      // Chunks are non-empty
      for (final c in chunks) {
        expect(c, isNotEmpty);
      }
    });

    patrolTest('is deterministic', ($) async {
      const text = 'Same input text for determinism test.';
      expect(EmbeddingChunker.chunkText(text), equals(EmbeddingChunker.chunkText(text)));
    });
  });

  // ── buildEmbeddingInput ───────────────────────────────────────────────────

  group('EmbeddingChunker.buildEmbeddingInput', () {
    patrolTest('empty title returns chunk only', ($) async {
      expect(EmbeddingChunker.buildEmbeddingInput(title: '', chunkText: 'body'), 'body');
    });

    patrolTest('non-empty title prepends Title: header', ($) async {
      final result = EmbeddingChunker.buildEmbeddingInput(title: 'My Note', chunkText: 'body text');
      expect(result, startsWith('Title: My Note\n\n'));
      expect(result, contains('body text'));
    });
  });

  // ── computeContentSignature ───────────────────────────────────────────────

  group('EmbeddingChunker.computeContentSignature', () {
    patrolTest('same inputs produce same signature', ($) async {
      final inputs = ['chunk one', 'chunk two'];
      final a = EmbeddingChunker.computeContentSignature(inputs, modelName: 'model-v1');
      final b = EmbeddingChunker.computeContentSignature(inputs, modelName: 'model-v1');
      expect(a, equals(b));
    });

    patrolTest('different model name produces different signature', ($) async {
      final inputs = ['chunk one'];
      final a = EmbeddingChunker.computeContentSignature(inputs, modelName: 'model-v1');
      final b = EmbeddingChunker.computeContentSignature(inputs, modelName: 'model-v2');
      expect(a, isNot(equals(b)));
    });

    patrolTest('different inputs produce different signature', ($) async {
      final a = EmbeddingChunker.computeContentSignature(['aaa'], modelName: 'm');
      final b = EmbeddingChunker.computeContentSignature(['bbb'], modelName: 'm');
      expect(a, isNot(equals(b)));
    });
  });
}
```

- [ ] **Step 2: Run tests — expect FAIL (class not found)**

```bash
flutter test patrol_test/core/services/embedding_chunker_test.dart
```

Expected: compile error — `EmbeddingChunker` not found.

- [ ] **Step 3: Create `EmbeddingChunker`**

Create `lib/core/services/ai/embedding_chunker.dart`:

```dart
import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Static helpers for chunking note text and computing content signatures.
///
/// Extracted from [EmbeddingService] to keep that class under 300 LOC.
/// All methods are pure (no side effects) — safe to call from tests without
/// any service setup.
class EmbeddingChunker {
  static const int maxChunkChars = 2000;
  static const int overlapChars = 200;

  EmbeddingChunker._();

  /// Build the embedding-input string sent to the API for one chunk.
  ///
  /// When [title] is non-empty, prepends `Title: <title>\n\n` so the model
  /// knows which note the chunk belongs to.
  static String buildEmbeddingInput({required String title, required String chunkText}) {
    if (title.isEmpty) return chunkText;
    return 'Title: $title\n\n$chunkText';
  }

  /// Split [text] into overlapping chunks of at most [maxChunkChars] characters.
  ///
  /// Prefers breaking at sentence boundaries (`. `) or newlines to avoid
  /// splitting mid-sentence. Returns an empty list for empty input.
  static List<String> chunkText(String text) {
    if (text.isEmpty) return const [];
    if (text.length <= maxChunkChars) return [text];

    final chunks = <String>[];
    int start = 0;

    while (start < text.length) {
      int end = start + maxChunkChars;
      if (end >= text.length) {
        final chunk = text.substring(start).trim();
        if (chunk.isNotEmpty) chunks.add(chunk);
        break;
      }

      final segment = text.substring(start, end);
      final lastPeriod = segment.lastIndexOf('. ');
      final lastNewline = segment.lastIndexOf('\n');
      final halfChunk = maxChunkChars ~/ 2;

      int breakPoint = -1;
      if (lastPeriod > halfChunk) breakPoint = lastPeriod + 1;
      if (lastNewline > halfChunk && lastNewline > breakPoint) breakPoint = lastNewline;

      if (breakPoint > 0) end = start + breakPoint + 1;

      final chunk = text.substring(start, end).trim();
      if (chunk.isNotEmpty) chunks.add(chunk);
      start = end - overlapChars;
    }

    return chunks.where((c) => c.isNotEmpty).toList();
  }

  /// Compute a deterministic SHA-256 signature over [embeddingInputs].
  ///
  /// Includes [modelName] so that upgrading the model automatically
  /// invalidates old signatures. Used by [EmbeddingService.isNoteStale].
  static String computeContentSignature(
    List<String> embeddingInputs, {
    required String modelName,
    int maxChunk = maxChunkChars,
    int overlap = overlapChars,
  }) {
    final buffer = StringBuffer()
      ..writeln('model=$modelName')
      ..writeln('maxChunk=$maxChunk')
      ..writeln('overlap=$overlap');
    for (final input in embeddingInputs) {
      buffer
        ..writeln('---')
        ..writeln(input.replaceAll('\r\n', '\n').trim());
    }
    return sha256.convert(utf8.encode(buffer.toString())).toString();
  }
}
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
flutter test patrol_test/core/services/embedding_chunker_test.dart
```

Expected: all 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/ai/embedding_chunker.dart \
        patrol_test/core/services/embedding_chunker_test.dart
git commit -m "refactor(ai): extract EmbeddingChunker from EmbeddingService"
```

---

## Task 3: Create FirebaseGeminiEmbeddingProvider

**Files:**
- Create: `lib/core/services/ai/_providers/firebase_gemini_embedding_provider.dart`

- [ ] **Step 1: Create the provider**

Create `lib/core/services/ai/_providers/firebase_gemini_embedding_provider.dart`:

```dart
import 'package:firebase_ai/firebase_ai.dart';
import 'package:logger/logger.dart';

/// Embedding provider backed by Firebase AI (Gemini Developer API, free tier).
///
/// Uses [FirebaseAI.googleAI()] — no API key required. Firebase project
/// config (google-services.json / GoogleService-Info.plist) provides auth.
/// Requires [Firebase.initializeApp()] to have been called first
/// (guaranteed by initializer.dart).
class FirebaseGeminiEmbeddingProvider {
  static const String defaultModel = 'text-embedding-004';

  final String modelName;
  final Logger _logger = Logger();

  FirebaseGeminiEmbeddingProvider({this.modelName = defaultModel});

  /// Generate an embedding vector for [text].
  ///
  /// Returns `null` on any API error so [EmbeddingService] can queue the
  /// note for retry without crashing.
  Future<List<double>?> embed(String text) async {
    try {
      final model = FirebaseAI.googleAI().generativeModel(model: modelName);
      final result = await model.embedContent(Content.text(text));
      return result.embedding.values.toList(growable: false);
    } catch (e) {
      _logger.e('FirebaseGemini embedding error: $e');
      return null;
    }
  }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/core/services/ai/_providers/firebase_gemini_embedding_provider.dart
```

Expected: no errors. (If `firebase_ai` types are unresolved, re-check Task 1 pub get output.)

- [ ] **Step 3: Commit**

```bash
git add lib/core/services/ai/_providers/firebase_gemini_embedding_provider.dart
git commit -m "feat(ai): add FirebaseGeminiEmbeddingProvider"
```

---

## Task 4: Refactor EmbeddingService

Remove `google_generative_ai`, delegate to `EmbeddingChunker` and `FirebaseGeminiEmbeddingProvider`. The Gemini-blocked fallback chain (~86 LOC) is deleted entirely — Firebase AI routes through Firebase infra, no geo-restrictions.

**Files:**
- Modify: `lib/core/services/ai/embedding_service.dart`

- [ ] **Step 1: Verify existing tests pass before touching the file**

```bash
flutter test patrol_test/core/services/embedding_service_test.dart
```

Expected: all tests pass. If any fail, fix them before continuing.

- [ ] **Step 2: Replace the file header (imports + fields + constructor)**

Replace everything from line 1 to the end of the constructor with:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:trovara/constants/config_constants.dart';
import 'package:trovara/core/repository/interfaces/embedding_repository.dart';
import 'package:trovara/core/services/ai/_providers/firebase_gemini_embedding_provider.dart';
import 'package:trovara/core/services/ai/embedding_chunker.dart';
import 'package:trovara/core/services/notes/text_parser_service.dart';
import 'package:trovara/models/note.dart';
import 'package:trovara/models/note_embedding.dart';

enum EmbeddingProvider { openAiCompatible, gemini }

/// Converts note content into vector embeddings and persists them locally.
///
/// The Gemini path uses [FirebaseGeminiEmbeddingProvider] (no API key).
/// The OpenAI-compatible path uses HTTP with a configured API key.
class EmbeddingService {
  static const String defaultBaseUrl = 'https://openrouter.ai/api/v1';
  static const String defaultEmbeddingModel = 'openai/text-embedding-3-large';
  static const String defaultGeminiEmbeddingModel = FirebaseGeminiEmbeddingProvider.defaultModel;

  final IEmbeddingRepository _embeddingRepository;
  final EmbeddingProvider _provider;
  final String _apiKey;
  final String _modelName;
  final String _baseUrl;
  final String? _siteUrl;
  final String? _appName;
  final Logger _logger = Logger();

  http.Client? _client;
  FirebaseGeminiEmbeddingProvider? _geminiProvider;
  bool _isInitialized = false;

  EmbeddingApiException? _lastError;
  EmbeddingApiException? get lastError => _lastError;

  final List<Note> _pendingQueue = [];

  EmbeddingService({
    required IEmbeddingRepository embeddingRepository,
    EmbeddingProvider provider = EmbeddingProvider.gemini,
    String apiKey = '',
    String modelName = defaultGeminiEmbeddingModel,
    String baseUrl = defaultBaseUrl,
    String? siteUrl,
    String? appName,
  })  : _embeddingRepository = embeddingRepository,
        _provider = provider,
        _apiKey = apiKey,
        _modelName = modelName,
        _baseUrl = baseUrl,
        _siteUrl = siteUrl,
        _appName = appName;

  bool get isAvailable {
    if (!_isInitialized) return false;
    if (_provider == EmbeddingProvider.gemini) return true;
    return _apiKey.isNotEmpty;
  }

  int get pendingCount => _pendingQueue.length;
```

- [ ] **Step 3: Replace `initialize()`**

Replace the existing `initialize()` method body with:

```dart
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _embeddingRepository.initialize();

    switch (_provider) {
      case EmbeddingProvider.gemini:
        _geminiProvider = FirebaseGeminiEmbeddingProvider(modelName: _modelName);
      case EmbeddingProvider.openAiCompatible:
        if (_apiKey.isEmpty) {
          _logger.w('EmbeddingService: No API key — embedding disabled');
          return;
        }
        _client = http.Client();
    }

    _isInitialized = true;
    _logger.i('EmbeddingService initialized ($_provider, model=$_modelName)');
  }
```

- [ ] **Step 4: Replace `_generateEmbedding()`**

Replace the entire `_generateEmbedding()` method (and the Gemini-blocked fallback chain) with:

```dart
  Future<List<double>?> _generateEmbedding(String text) async {
    try {
      if (_provider == EmbeddingProvider.gemini) {
        final result = await _geminiProvider!.embed(text);
        if (result != null) _lastError = null;
        return result;
      }

      if (_client == null) return null;

      final uri = Uri.parse('$_baseUrl/embeddings');
      final res = await _client!.post(
        uri,
        headers: _buildHeaders(),
        body: jsonEncode({'model': _modelName, 'input': text}),
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        _lastError = EmbeddingApiException.fromHttp(statusCode: res.statusCode, body: res.body);
        _logger.e('Embedding API error (${res.statusCode}): ${_lastError!.message}');
        return null;
      }

      _lastError = null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      final data = decoded['data'];
      if (data is! List || data.isEmpty) return null;
      final first = data.first;
      if (first is! Map) return null;
      final embedding = first['embedding'];
      if (embedding is! List) return null;
      return embedding.map((e) => (e as num).toDouble()).toList(growable: false);
    } catch (e) {
      _lastError = EmbeddingApiException(statusCode: null, message: e.toString());
      _logger.e('Embedding API error: $e');
      return null;
    }
  }
```

- [ ] **Step 5: Update delegation methods to use EmbeddingChunker**

Replace the private `_buildEmbeddingInput`, `_chunkText`, and their public wrappers with thin delegations:

```dart
  // ── Public delegation to EmbeddingChunker ─────────────────────────────────

  List<String> chunkText(String text) => EmbeddingChunker.chunkText(text);

  List<String> buildEmbeddingInputs(Note note) {
    final title = note.title.trim();
    final content = TextParserService.parseQuillContent(note.contentJson).trim();
    final textForChunking = content.isEmpty ? title : content;
    if (textForChunking.isEmpty) return [];
    return EmbeddingChunker.chunkText(textForChunking)
        .map((chunk) => content.isEmpty
            ? chunk
            : EmbeddingChunker.buildEmbeddingInput(title: title, chunkText: chunk))
        .toList();
  }

  static String computeContentSignature(
    List<String> embeddingInputs, {
    required String modelName,
    int maxChunkChars = EmbeddingChunker.maxChunkChars,
    int overlapChars = EmbeddingChunker.overlapChars,
  }) =>
      EmbeddingChunker.computeContentSignature(
        embeddingInputs,
        modelName: modelName,
        maxChunk: maxChunkChars,
        overlap: overlapChars,
      );
```

- [ ] **Step 6: Update the `embedNote()` guard**

In `embedNote()`, the `if (!isAvailable)` block currently reads:
```dart
if (!isAvailable) {
  if (_apiKey.isNotEmpty) {
    _addToPendingQueue(note);
  }
  return;
}
```

Replace with:
```dart
if (!isAvailable) return;
```

The pending queue is now populated only when `_generateEmbedding()` returns `null` (which happens on actual API failure), not when the service is unconfigured.

- [ ] **Step 7: Run all embedding tests**

```bash
flutter test patrol_test/core/services/embedding_service_test.dart \
             patrol_test/core/services/embedding_chunker_test.dart
```

Expected: all tests pass.

- [ ] **Step 8: Commit**

```bash
git add lib/core/services/ai/embedding_service.dart
git commit -m "refactor(ai): migrate EmbeddingService to firebase_ai, extract chunker"
```

---

## Task 5: Create FirebaseGeminiLlmProvider

**Files:**
- Create: `lib/core/services/ai/_providers/firebase_gemini_llm_provider.dart`

- [ ] **Step 1: Create the provider**

Create `lib/core/services/ai/_providers/firebase_gemini_llm_provider.dart`:

```dart
import 'package:firebase_ai/firebase_ai.dart';
import 'package:logger/logger.dart';

/// One prior conversation turn passed to [FirebaseGeminiLlmProvider].
///
/// Using a Dart record avoids importing [LlmChatMessage] from llm_client.dart
/// (which would create a circular dependency).
typedef ChatTurn = ({String role, String content});

/// LLM generation backed by Firebase AI (Gemini Developer API, free tier).
///
/// Uses [FirebaseAI.googleAI()] — no API key required. Requires
/// [Firebase.initializeApp()] to have been called before any method (done by
/// initializer.dart before ServiceLocator is wired).
class FirebaseGeminiLlmProvider {
  static const String defaultModel = 'gemini-1.5-flash';

  final String modelName;
  final double temperature;
  final double topP;
  final int maxOutputTokens;
  final Logger _logger = Logger();

  FirebaseGeminiLlmProvider({
    this.modelName = defaultModel,
    required this.temperature,
    required this.topP,
    required this.maxOutputTokens,
  });

  // ── Internal helpers ───────────────────────────────────────────────────────

  GenerativeModel _buildModel(String systemPrompt) {
    final sys = systemPrompt.trim();
    return FirebaseAI.googleAI().generativeModel(
      model: modelName,
      systemInstruction: sys.isEmpty ? null : Content.system(sys),
      generationConfig: GenerationConfig(
        temperature: temperature,
        topP: topP,
        maxOutputTokens: maxOutputTokens,
      ),
    );
  }

  List<Content> _buildContents(List<ChatTurn> history, String userMessage) {
    final contents = <Content>[];
    for (final turn in history) {
      if (turn.role.trim().toLowerCase() == 'assistant') {
        contents.add(Content('model', [TextPart(turn.content)]));
      } else {
        contents.add(Content.text(turn.content));
      }
    }
    contents.add(Content.text(userMessage));
    return contents;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Non-streaming generation. Returns `'No response generated.'` on empty response.
  Future<String> generateWithMessages({
    required String systemPrompt,
    required List<ChatTurn> history,
    required String userMessage,
  }) async {
    final model = _buildModel(systemPrompt);
    final contents = _buildContents(history, userMessage);
    final res = await model.generateContent(contents);
    final text = res.text ?? '';
    if (text.isEmpty) {
      _logger.w('FirebaseGemini: empty response');
      return 'No response generated.';
    }
    _logger.d('FirebaseGemini generated ${text.length} chars');
    return text;
  }

  /// Streaming generation. Yields token deltas as they arrive.
  Stream<String> generateStreamWithMessages({
    required String systemPrompt,
    required List<ChatTurn> history,
    required String userMessage,
  }) async* {
    final model = _buildModel(systemPrompt);
    final contents = _buildContents(history, userMessage);
    await for (final res in model.generateContentStream(contents)) {
      final text = res.text ?? '';
      if (text.isNotEmpty) yield text;
    }
  }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/core/services/ai/_providers/firebase_gemini_llm_provider.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/core/services/ai/_providers/firebase_gemini_llm_provider.dart
git commit -m "feat(ai): add FirebaseGeminiLlmProvider"
```

---

## Task 6: Refactor LlmClient

Remove all `google_generative_ai` usage. The 12 Gemini helper methods and the two "Gemini blocked" fallback chains (~451 LOC combined) are deleted. `LlmClient` delegates the Gemini path to `FirebaseGeminiLlmProvider`.

**Files:**
- Modify: `lib/core/services/ai/llm_client.dart`

- [ ] **Step 1: Verify existing rag tests pass before touching the file**

```bash
flutter test patrol_test/core/services/rag_service_test.dart
```

Expected: all tests pass.

- [ ] **Step 2: Replace imports and enum**

Replace the top of `llm_client.dart` (through the end of the `LlmChatMessage` class) with:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:trovara/core/services/ai/_providers/firebase_gemini_llm_provider.dart';

export 'package:trovara/core/services/ai/_providers/firebase_gemini_llm_provider.dart'
    show ChatTurn;

enum LlmProvider { openAiCompatible, gemini }

/// One prior turn for [LlmClient.generateWithMessages].
/// Roles must be `user` or `assistant`.
class LlmChatMessage {
  final String role;
  final String content;

  const LlmChatMessage({required this.role, required this.content});
}
```

- [ ] **Step 3: Replace class declaration, fields, and constructor**

Replace the `LlmClient` class opening through the end of the constructor with:

```dart
/// Provider-agnostic LLM client.
///
/// Gemini path: delegates to [FirebaseGeminiLlmProvider] (no API key).
/// OpenAI-compatible path: plain HTTP using [_apiKey].
class LlmClient {
  static const String defaultBaseUrl = 'https://openrouter.ai/api/v1';
  static const String defaultModel = 'openai/gpt-3.5-turbo';
  static const String defaultGeminiModel = FirebaseGeminiLlmProvider.defaultModel;
  static const double defaultTemperature = 0.3;
  static const double defaultTopP = 0.8;
  static const int defaultMaxOutputTokens = 1024;

  final LlmProvider _provider;
  final String _apiKey;
  final String _modelName;
  final String _baseUrl;
  final String? _siteUrl;
  final String? _appName;
  final double _temperature;
  final double _topP;
  final int _maxOutputTokens;
  final Logger _logger = Logger();

  http.Client? _client;
  FirebaseGeminiLlmProvider? _geminiProvider;
  bool _isInitialized = false;

  LlmClient({
    LlmProvider provider = LlmProvider.gemini,
    String apiKey = '',
    String modelName = defaultGeminiModel,
    String baseUrl = defaultBaseUrl,
    String? siteUrl,
    String? appName,
    double temperature = defaultTemperature,
    double topP = defaultTopP,
    int maxOutputTokens = defaultMaxOutputTokens,
  })  : _provider = provider,
        _apiKey = apiKey,
        _modelName = modelName,
        _baseUrl = baseUrl,
        _siteUrl = siteUrl,
        _appName = appName,
        _temperature = temperature,
        _topP = topP,
        _maxOutputTokens = maxOutputTokens;

  bool get isAvailable {
    if (!_isInitialized) return false;
    if (_provider == LlmProvider.gemini) return true;
    return _apiKey.isNotEmpty;
  }

  LlmProvider get provider => _provider;
  String get modelName => _modelName;
```

- [ ] **Step 4: Replace `initialize()`**

```dart
  Future<void> initialize() async {
    if (_isInitialized) return;

    switch (_provider) {
      case LlmProvider.gemini:
        _geminiProvider = FirebaseGeminiLlmProvider(
          modelName: _modelName,
          temperature: _temperature,
          topP: _topP,
          maxOutputTokens: _maxOutputTokens,
        );
      case LlmProvider.openAiCompatible:
        if (_apiKey.isEmpty) {
          _logger.w('LlmClient: No API key — generation disabled');
          return;
        }
        _client = http.Client();
    }

    _isInitialized = true;
    _logger.i('LlmClient initialized ($_provider, model=$_modelName)');
  }
```

- [ ] **Step 5: Replace `generate()` and `generateWithMessages()`**

```dart
  Future<String> generate(String prompt) =>
      generateWithMessages(systemPrompt: '', history: const [], userMessage: prompt);

  Future<String> generateWithMessages({
    required String systemPrompt,
    required List<LlmChatMessage> history,
    required String userMessage,
  }) async {
    if (!isAvailable) throw StateError('LlmClient is not initialized or API key is missing');

    final msg = userMessage.trim();
    if (msg.isEmpty) return 'No response generated.';

    try {
      if (_provider == LlmProvider.gemini) {
        final turns = history.map((m) => (role: m.role, content: m.content)).toList();
        return await _geminiProvider!.generateWithMessages(
          systemPrompt: systemPrompt,
          history: turns,
          userMessage: msg,
        );
      }

      final uri = Uri.parse('$_baseUrl/chat/completions');
      final res = await _client!.post(
        uri,
        headers: _buildHeaders(),
        body: jsonEncode({
          'model': _modelName,
          'messages': _openAiMessagesJson(systemPrompt: systemPrompt, history: history, userMessage: msg),
          'temperature': _temperature,
          'top_p': _topP,
          'max_tokens': _maxOutputTokens,
        }),
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw _parseApiError(statusCode: res.statusCode, body: res.body);
      }

      final decoded = jsonDecode(res.body);
      final choices = (decoded is Map<String, dynamic>) ? decoded['choices'] : null;
      if (choices is! List || choices.isEmpty) return 'No response generated.';
      final message = (choices.first as Map)['message'];
      final content = (message is Map) ? message['content'] : null;
      final text = content?.toString() ?? '';
      if (text.isEmpty) return 'No response generated.';
      _logger.d('LLM generated ${text.length} chars');
      return text;
    } catch (e) {
      if (_provider == LlmProvider.gemini) throw _wrapFirebaseException(e);
      _logger.e('LLM generation error: $e');
      rethrow;
    }
  }
```

- [ ] **Step 6: Replace `generateStream()` and `generateStreamWithMessages()`**

```dart
  Stream<String> generateStream(String prompt) =>
      generateStreamWithMessages(systemPrompt: '', history: const [], userMessage: prompt);

  Stream<String> generateStreamWithMessages({
    required String systemPrompt,
    required List<LlmChatMessage> history,
    required String userMessage,
  }) async* {
    if (!isAvailable) throw StateError('LlmClient is not initialized or API key is missing');

    final msg = userMessage.trim();
    if (msg.isEmpty) return;

    try {
      if (_provider == LlmProvider.gemini) {
        final turns = history.map((m) => (role: m.role, content: m.content)).toList();
        yield* _geminiProvider!.generateStreamWithMessages(
          systemPrompt: systemPrompt,
          history: turns,
          userMessage: msg,
        );
        return;
      }

      final uri = Uri.parse('$_baseUrl/chat/completions');
      final req = http.Request('POST', uri)
        ..headers.addAll(_buildHeaders())
        ..body = jsonEncode({
          'model': _modelName,
          'messages': _openAiMessagesJson(systemPrompt: systemPrompt, history: history, userMessage: msg),
          'temperature': _temperature,
          'top_p': _topP,
          'max_tokens': _maxOutputTokens,
          'stream': true,
        });

      final streamed = await _client!.send(req);
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        final body = await streamed.stream.bytesToString();
        throw _parseApiError(statusCode: streamed.statusCode, body: body);
      }

      final lines = streamed.stream.transform(utf8.decoder).transform(const LineSplitter());
      await for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || !trimmed.startsWith('data:')) continue;
        final data = trimmed.substring('data:'.length).trim();
        if (data == '[DONE]') break;
        dynamic chunk;
        try {
          chunk = jsonDecode(data);
        } catch (_) {
          continue;
        }
        if (chunk is! Map) continue;
        final choices = chunk['choices'];
        if (choices is! List || choices.isEmpty) continue;
        final delta = (choices.first as Map)['delta'];
        final content = (delta is Map) ? delta['content'] : null;
        final text = content?.toString() ?? '';
        if (text.isNotEmpty) yield text;
      }
    } catch (e) {
      if (_provider == LlmProvider.gemini) throw _wrapFirebaseException(e);
      _logger.e('LLM streaming error: $e');
      rethrow;
    }
  }
```

- [ ] **Step 7: Replace private helpers**

Delete all Gemini-specific private methods (`_isGeminiModelNotFound`, `_isGeminiStreamingNotSupported`, `_isGeminiAuthError`, `_isGeminiQuotaError`, `_normalizeGeminiModelName`, `_wrapGeminiException`, `_resolveGeminiModelForGeneration`, `_newGeminiModel`, `_geminiConversationContents`, `_generateGeminiWithContents`) and replace with just the OpenAI helpers and the new Firebase exception wrapper:

```dart
  List<Map<String, dynamic>> _openAiMessagesJson({
    required String systemPrompt,
    required List<LlmChatMessage> history,
    required String userMessage,
  }) {
    final messages = <Map<String, dynamic>>[];
    final sys = systemPrompt.trim();
    if (sys.isNotEmpty) messages.add({'role': 'system', 'content': sys});
    for (final h in history) {
      messages.add({'role': h.role, 'content': h.content});
    }
    messages.add({'role': 'user', 'content': userMessage});
    return messages;
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{'Authorization': 'Bearer $_apiKey', 'Content-Type': 'application/json'};
    if (_siteUrl != null && _siteUrl.trim().isNotEmpty) headers['HTTP-Referer'] = _siteUrl.trim();
    if (_appName != null && _appName.trim().isNotEmpty) headers['X-Title'] = _appName.trim();
    return headers;
  }

  LlmApiException _parseApiError({required int statusCode, required String body}) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        final err = decoded['error'] as Map;
        return LlmApiException(
          statusCode: statusCode,
          message: err['message']?.toString() ?? 'Unknown error',
          type: err['type']?.toString(),
          code: err['code']?.toString(),
        );
      }
    } catch (_) {}
    final truncated = body.length > 500 ? '${body.substring(0, 500)}…' : body;
    return LlmApiException(statusCode: statusCode, message: truncated);
  }

  LlmApiException _wrapFirebaseException(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('quota') || msg.contains('resource_exhausted') || msg.contains('too many requests')) {
      return LlmApiException(statusCode: 429, message: e.toString(), type: 'firebase_gemini', code: 'quota_exceeded');
    }
    if (msg.contains('unauthenticated') || msg.contains('permission_denied')) {
      return LlmApiException(statusCode: 401, message: e.toString(), type: 'firebase_gemini', code: 'auth_error');
    }
    return LlmApiException(statusCode: 500, message: e.toString(), type: 'firebase_gemini', code: 'unknown');
  }
}
```

Keep the `LlmApiException` class at the bottom of the file exactly as it was.

- [ ] **Step 8: Run all AI service tests**

```bash
flutter test patrol_test/core/services/
```

Expected: all tests pass. The rag_service_test uses `StubLlmClient` (a fake), so it's unaffected by the real `LlmClient` change.

- [ ] **Step 9: Verify LOC**

```bash
wc -l lib/core/services/ai/llm_client.dart
```

Expected: under 300.

- [ ] **Step 10: Commit**

```bash
git add lib/core/services/ai/llm_client.dart
git commit -m "refactor(ai): migrate LlmClient to firebase_ai, remove Gemini fallback chains"
```

---

## Task 7: Refactor ServiceLocator

Remove all `geminiApiKey` / `useGeminiFree*` branching. Firebase Gemini becomes the default when no OpenAI/OpenRouter key is configured.

**Files:**
- Modify: `lib/core/di/service_locator.dart`

- [ ] **Step 1: Replace `embeddingService` getter**

Replace the existing `embeddingService` getter with:

```dart
  EmbeddingService get embeddingService {
    if (_embeddingService == null) {
      if (ConfigConstants.openAiApiKey.isNotEmpty) {
        _embeddingService = EmbeddingService(
          embeddingRepository: embeddingRepository,
          provider: EmbeddingProvider.openAiCompatible,
          baseUrl: 'https://api.openai.com/v1',
          apiKey: ConfigConstants.openAiApiKey,
          modelName: ConfigConstants.openAiEmbeddingModel,
        );
      } else if (ConfigConstants.openRouterApiKey.isNotEmpty) {
        _embeddingService = EmbeddingService(
          embeddingRepository: embeddingRepository,
          provider: EmbeddingProvider.openAiCompatible,
          apiKey: ConfigConstants.openRouterApiKey,
          modelName: ConfigConstants.openRouterEmbeddingModel,
          siteUrl: ConfigConstants.openRouterSiteUrl,
          appName: ConfigConstants.openRouterAppName,
        );
      } else {
        // Default: Firebase Gemini — no API key needed.
        _embeddingService = EmbeddingService(
          embeddingRepository: embeddingRepository,
          provider: EmbeddingProvider.gemini,
          modelName: EmbeddingService.defaultGeminiEmbeddingModel,
        );
      }
    }
    return _embeddingService!;
  }
```

- [ ] **Step 2: Replace `llmClient` getter**

Replace the existing `llmClient` getter with:

```dart
  LlmClient get llmClient {
    if (_llmClient == null) {
      if (ConfigConstants.openAiApiKey.isNotEmpty) {
        _llmClient = LlmClient(
          provider: LlmProvider.openAiCompatible,
          baseUrl: 'https://api.openai.com/v1',
          apiKey: ConfigConstants.openAiApiKey,
          modelName: 'gpt-4o-mini',
        );
      } else if (ConfigConstants.openRouterApiKey.isNotEmpty) {
        _llmClient = LlmClient(
          provider: LlmProvider.openAiCompatible,
          apiKey: ConfigConstants.openRouterApiKey,
          modelName: ConfigConstants.openRouterModel,
          siteUrl: ConfigConstants.openRouterSiteUrl,
          appName: ConfigConstants.openRouterAppName,
        );
      } else {
        // Default: Firebase Gemini — no API key needed.
        _llmClient = LlmClient(
          provider: LlmProvider.gemini,
          modelName: LlmClient.defaultGeminiModel,
        );
      }
    }
    return _llmClient!;
  }
```

- [ ] **Step 3: Replace `rewriteLlmClient` getter**

Replace the existing `rewriteLlmClient` getter with:

```dart
  LlmClient get rewriteLlmClient {
    if (_rewriteLlmClient == null) {
      if (ConfigConstants.openAiApiKey.isNotEmpty) {
        _rewriteLlmClient = LlmClient(
          provider: LlmProvider.openAiCompatible,
          baseUrl: 'https://api.openai.com/v1',
          apiKey: ConfigConstants.openAiApiKey,
          modelName: 'gpt-4o-mini',
          temperature: 0.0,
          topP: 1.0,
          maxOutputTokens: 256,
        );
      } else if (ConfigConstants.openRouterApiKey.isNotEmpty) {
        _rewriteLlmClient = LlmClient(
          provider: LlmProvider.openAiCompatible,
          apiKey: ConfigConstants.openRouterApiKey,
          modelName: ConfigConstants.openRouterModel,
          siteUrl: ConfigConstants.openRouterSiteUrl,
          appName: ConfigConstants.openRouterAppName,
          temperature: 0.0,
          topP: 1.0,
          maxOutputTokens: 256,
        );
      } else {
        // Default: Firebase Gemini — no API key needed.
        _rewriteLlmClient = LlmClient(
          provider: LlmProvider.gemini,
          modelName: LlmClient.defaultGeminiModel,
          temperature: 0.0,
          topP: 1.0,
          maxOutputTokens: 256,
        );
      }
    }
    return _rewriteLlmClient!;
  }
```

- [ ] **Step 4: Run full analyze**

```bash
flutter analyze lib/core/di/service_locator.dart
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/core/di/service_locator.dart
git commit -m "refactor(di): make Firebase Gemini the default LLM+embedding provider"
```

---

## Task 8: Deprecate unused ConfigConstants

**Files:**
- Modify: `lib/constants/config_constants.dart`

- [ ] **Step 1: Add deprecation comments to unused constants**

At the top of `config_constants.dart` add a block comment before the enum declaration:

```dart
// ignore_for_file: constant_identifier_names
```

Then add `@Deprecated` annotations to the now-unused Gemini key constants. Find these enum values and precede each with a deprecation annotation:

```dart
  // ignore: deprecated_member_use_from_same_package
  @Deprecated('No longer used — ServiceLocator now uses firebase_ai. Remove in a follow-up PR.')
  GEMINI_API_KEY,

  @Deprecated('No longer used — firebase_ai handles auth. Remove in a follow-up PR.')
  USE_GEMINI_FREE_MODEL,

  @Deprecated('No longer used. Remove in a follow-up PR.')
  GEMINI_FREE_MODEL_NAME,

  @Deprecated('No longer used. Remove in a follow-up PR.')
  GEMINI_FREE_EMBEDDING_MODEL,

  @Deprecated('No longer used. Remove in a follow-up PR.')
  GEMINI_FREE_BASE_URL,

  @Deprecated('No longer used. Remove in a follow-up PR.')
  GEMINI_FREE_API_KEY,
```

Do NOT delete the constants yet — build scripts may still pass these dart-defines and that's fine.

- [ ] **Step 2: Analyze**

```bash
flutter analyze lib/constants/config_constants.dart
```

Expected: no errors (the `@Deprecated` on enum values is valid Dart).

- [ ] **Step 3: Commit**

```bash
git add lib/constants/config_constants.dart
git commit -m "chore(config): deprecate unused Gemini API key constants"
```

---

## Task 9: Full Verification

- [ ] **Step 1: Full analyze**

```bash
flutter analyze
```

Expected: zero new errors or warnings introduced by this migration. If you see unused import warnings on `config_constants.dart`, confirm those are only for the deprecated constants — acceptable until the cleanup PR.

- [ ] **Step 2: Full logic test suite**

```bash
flutter test patrol_test
```

Expected: all tests pass (same count as before the migration).

- [ ] **Step 3: Verify LOC targets**

```bash
wc -l lib/core/services/ai/llm_client.dart \
       lib/core/services/ai/embedding_service.dart \
       lib/core/services/ai/_providers/firebase_gemini_llm_provider.dart \
       lib/core/services/ai/_providers/firebase_gemini_embedding_provider.dart \
       lib/core/services/ai/embedding_chunker.dart
```

Expected: `llm_client.dart` ≤ 300. `embedding_service.dart` significantly lower than 582 (target < 420). Provider files each under 120.

- [ ] **Step 4: Manual smoke test — build staging with no API key dart-defines**

```bash
./scripts/run_app.sh --quick
```

Open the Chat tab. Type a question about your notes. Expected: a response streams in from Gemini via Firebase AI. No "API key missing" error in the console.

- [ ] **Step 5: Final commit if clean**

```bash
git add -u
git commit -m "chore(ai): verify Firebase AI migration — all tests pass, analyze clean"
```

---

## Known Follow-ups (out of scope for this PR)

- Remove the deprecated `GEMINI_API_KEY` and `USE_GEMINI_FREE_MODEL` constants from `config_constants.dart` and build scripts
- `embedding_service.dart` will still be over 300 LOC; a follow-up should extract the stale-notes management logic (`isNoteStale`, `reembedStaleNotes`, `reembedAll`, `processPendingEmbeddings`) into `embedding_stale_manager.dart`
- Firebase App Check integration for production hardening
