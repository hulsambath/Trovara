# Tiered AI Chat — Plan A: Tier Infrastructure (pure Dart)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan one task at a time. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make AI chat tier-aware — free users get base retrieval on an on-device backend (or their own BYOK key), Pro users get enhanced retrieval on premium cloud — without rewriting the RAG pipeline.

**Architecture:** A `ChatTierResolver` reads `ProAccessService` + BYOK-key presence and returns the active `ChatTier`. `ServiceLocator` uses it to pick the chat `LlmChatBackend` (on-device stub / BYOK cloud / premium cloud) and to pick a `RetrievalDepth` preset that `RagService` threads into `RagRetriever`. The on-device backend lands as a deterministic **stub** here (real MediaPipe runtime is Plan B). BYOK key is persisted via `SharedPreferences` (mirroring `note_tombstone_registry.dart`).

**Tech Stack:** Flutter/Dart, `shared_preferences`, `patrol_finders` logic tests (real ObjectBox, no mocks), `easy_localization`, `lucide_icons_flutter`.

## Global Constraints

- MVVM strict: views never call services; tier decisions live in services, surfaced to the VM. (`lib/views/CLAUDE.md`)
- All wiring goes through `ServiceLocator`; never instantiate a service/backend directly. (`CLAUDE.md` rule 2)
- New LLM backend = implement `LlmChatBackend` + add an `LlmProvider` enum value; do NOT subclass `LlmClient`. (`lib/core/services/ai/CLAUDE.md`)
- Preserve the existing cloud provider preference order Gemini → OpenAI → OpenRouter. (`ai/CLAUDE.md`)
- No hardcoded user-visible strings — add keys to BOTH `assets/translations/en.json` AND `km.json`; `/i18n-check` must pass. (`CLAUDE.md` rule 4)
- No hardcoded colors/text styles (`Theme.of(context).*`); icons from `lucide_icons_flutter` only. (`CLAUDE.md` rules 5–6)
- Single quotes, 120-char width, `const` where it compiles; 300 LOC hard file limit. (`CLAUDE.md` rules 9–10)
- Logic tests live in `patrol_test/` and use the local `patrolTest` wrapper from `test_support.dart`; run with `flutter test patrol_test`. (`CLAUDE.md`)
- Do NOT persist the BYOK key to Drive sync and never log it. (spec §6)

---

### Task 1: ChatTier + ChatTierResolver

**Files:**
- Create: `lib/core/services/ai/chat_tier.dart`
- Create: `lib/core/services/ai/chat_tier_resolver.dart`
- Test: `patrol_test/core/services/ai/chat_tier_resolver_test.dart`

**Interfaces:**
- Consumes: `ProAccessService` (`lib/core/services/pro/pro_access_service.dart`, `bool get isProUnlocked`).
- Produces:
  - `enum ChatTier { free, pro }`
  - `enum ChatEngine { onDevice, byokCloud, premiumCloud }`
  - `class ChatTierResolver` with:
    - `ChatTierResolver({required ProAccessService proAccess, required bool Function() hasByokKey})`
    - `ChatTier resolveTier()` → `pro` iff `proAccess.isProUnlocked`, else `free`
    - `ChatEngine resolveEngine()` → `premiumCloud` if Pro; else `byokCloud` if `hasByokKey()`; else `onDevice`

- [ ] **Step 1: Write the failing test**

```dart
// patrol_test/core/services/ai/chat_tier_resolver_test.dart
import 'package:trovara/core/services/ai/chat_tier.dart';
import 'package:trovara/core/services/ai/chat_tier_resolver.dart';
import 'package:trovara/core/services/pro/pro_access_service.dart';

import '../../../test_support.dart';

void main() {
  patrolTest('free + no BYOK key resolves to free/onDevice', (\$) async {
    final pro = ProAccessService();
    final resolver = ChatTierResolver(proAccess: pro, hasByokKey: () => false);

    expect(resolver.resolveTier(), ChatTier.free);
    expect(resolver.resolveEngine(), ChatEngine.onDevice);
  });

  patrolTest('free + BYOK key resolves to free/byokCloud', (\$) async {
    final pro = ProAccessService();
    final resolver = ChatTierResolver(proAccess: pro, hasByokKey: () => true);

    expect(resolver.resolveTier(), ChatTier.free);
    expect(resolver.resolveEngine(), ChatEngine.byokCloud);
  });

  patrolTest('pro resolves to pro/premiumCloud regardless of BYOK', (\$) async {
    final pro = ProAccessService();
    await pro.unlockPro();
    final resolver = ChatTierResolver(proAccess: pro, hasByokKey: () => false);

    expect(resolver.resolveTier(), ChatTier.pro);
    expect(resolver.resolveEngine(), ChatEngine.premiumCloud);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test patrol_test/core/services/ai/chat_tier_resolver_test.dart`
Expected: FAIL — `chat_tier.dart` / `chat_tier_resolver.dart` do not exist (compile error).

- [ ] **Step 3: Write the enums**

```dart
// lib/core/services/ai/chat_tier.dart

/// Quality tier of the AI chat experience. Drives retrieval depth + UI.
enum ChatTier { free, pro }

/// The concrete generation engine behind chat for the active tier.
enum ChatEngine { onDevice, byokCloud, premiumCloud }
```

- [ ] **Step 4: Write the resolver**

```dart
// lib/core/services/ai/chat_tier_resolver.dart
import 'package:trovara/core/services/ai/chat_tier.dart';
import 'package:trovara/core/services/pro/pro_access_service.dart';

/// Single decision point for chat tier + engine selection.
///
/// Reads [ProAccessService] for entitlement and a BYOK-key presence callback,
/// so both backend selection and retrieval-depth selection agree (DRY).
class ChatTierResolver {
  ChatTierResolver({required ProAccessService proAccess, required bool Function() hasByokKey})
    : _proAccess = proAccess,
      _hasByokKey = hasByokKey;

  final ProAccessService _proAccess;
  final bool Function() _hasByokKey;

  ChatTier resolveTier() => _proAccess.isProUnlocked ? ChatTier.pro : ChatTier.free;

  ChatEngine resolveEngine() {
    if (_proAccess.isProUnlocked) return ChatEngine.premiumCloud;
    if (_hasByokKey()) return ChatEngine.byokCloud;
    return ChatEngine.onDevice;
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test patrol_test/core/services/ai/chat_tier_resolver_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/ai/chat_tier.dart lib/core/services/ai/chat_tier_resolver.dart \
  patrol_test/core/services/ai/chat_tier_resolver_test.dart
git commit -m "feat(ai): add ChatTier + ChatTierResolver for tiered chat

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: RetrievalDepth presets + thread into RagRetriever/RagService

**Files:**
- Create: `lib/core/services/ai/retrieval_depth.dart`
- Modify: `lib/core/services/ai/rag_retriever.dart` (add `expansionCount` param to `retrieve`)
- Modify: `lib/core/services/ai/rag_service.dart` (accept a `RetrievalDepth`, pass through)
- Test: `patrol_test/core/services/ai/retrieval_depth_test.dart`

**Interfaces:**
- Produces:
  - `class RetrievalDepth` with `final int fusionPoolSizePerQuery; final int topKChunks; final int expansionCount;` const ctor, and two const presets:
    - `RetrievalDepth.free` → `fusionPoolSizePerQuery: 5, topKChunks: 3, expansionCount: 1`
    - `RetrievalDepth.pro` → `fusionPoolSizePerQuery: 8, topKChunks: 5, expansionCount: 3`
  - `static RetrievalDepth forTier(ChatTier tier)` → `tier == ChatTier.pro ? pro : free`
- Consumes: `ChatTier` (Task 1).
- Modifies: `RagRetriever.retrieve(... , int expansionCount = 3)` — expansion uses this count instead of the hardcoded `3`.
- Modifies: `RagService.queryStream` / `query` — accept `RetrievalDepth depth = RetrievalDepth.free` and pass `depth.fusionPoolSizePerQuery`, `depth.topKChunks`, `depth.expansionCount` to `retrieve`.

- [ ] **Step 1: Write the failing test**

```dart
// patrol_test/core/services/ai/retrieval_depth_test.dart
import 'package:trovara/core/services/ai/chat_tier.dart';
import 'package:trovara/core/services/ai/retrieval_depth.dart';

import '../../../test_support.dart';

void main() {
  patrolTest('free preset is shallow', (\$) async {
    const d = RetrievalDepth.free;
    expect(d.fusionPoolSizePerQuery, 5);
    expect(d.topKChunks, 3);
    expect(d.expansionCount, 1);
  });

  patrolTest('pro preset is deeper', (\$) async {
    const d = RetrievalDepth.pro;
    expect(d.fusionPoolSizePerQuery, 8);
    expect(d.topKChunks, 5);
    expect(d.expansionCount, 3);
  });

  patrolTest('forTier maps tier to preset', (\$) async {
    expect(RetrievalDepth.forTier(ChatTier.free), same(RetrievalDepth.free));
    expect(RetrievalDepth.forTier(ChatTier.pro), same(RetrievalDepth.pro));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test patrol_test/core/services/ai/retrieval_depth_test.dart`
Expected: FAIL — `retrieval_depth.dart` does not exist.

- [ ] **Step 3: Write RetrievalDepth**

```dart
// lib/core/services/ai/retrieval_depth.dart
import 'package:trovara/core/services/ai/chat_tier.dart';

/// Retrieval-depth preset for a chat tier. Higher = better recall, more cost.
class RetrievalDepth {
  const RetrievalDepth({
    required this.fusionPoolSizePerQuery,
    required this.topKChunks,
    required this.expansionCount,
  });

  /// Candidates each (expanded) query contributes before RRF fusion.
  final int fusionPoolSizePerQuery;

  /// Final chunks used as prompt context.
  final int topKChunks;

  /// Number of query variations for multi-query expansion (1 = no expansion).
  final int expansionCount;

  static const RetrievalDepth free = RetrievalDepth(fusionPoolSizePerQuery: 5, topKChunks: 3, expansionCount: 1);
  static const RetrievalDepth pro = RetrievalDepth(fusionPoolSizePerQuery: 8, topKChunks: 5, expansionCount: 3);

  static RetrievalDepth forTier(ChatTier tier) => tier == ChatTier.pro ? pro : free;
}
```

- [ ] **Step 4: Run depth test to verify it passes**

Run: `flutter test patrol_test/core/services/ai/retrieval_depth_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Thread `expansionCount` into RagRetriever**

In `lib/core/services/ai/rag_retriever.dart`, change the `retrieve` signature to add `int expansionCount = 3` (keep default 3 so existing callers are unaffected), and use it in the expansion call.

Replace the signature block:

```dart
  Future<RagRetrieval> retrieve(
    String userQuestion, {
    required int fusionPoolSizePerQuery,
    required double minScore,
    required int expectedEmbeddingDim,
    String? conversationContext,
    int topKChunks = 3,
    int expansionCount = 3,
  }) async {
```

Replace the expansion lines:

```dart
    // 2) Expand (expansionCount variations; 1 disables expansion)
    final queries = expansionCount <= 1
        ? [rewritten]
        : (() {
            final expanded = await _multiQueryExpansionService.expand(rewritten, count: expansionCount);
            return expanded.isEmpty ? [rewritten] : expanded;
          })();
```

Note: `await` inside a closure is illegal — instead write it inline:

```dart
    // 2) Expand (expansionCount variations; 1 disables expansion)
    List<String> queries;
    if (expansionCount <= 1) {
      queries = [rewritten];
    } else {
      final expanded = await _multiQueryExpansionService.expand(rewritten, count: expansionCount);
      queries = expanded.isEmpty ? [rewritten] : expanded;
    }
```

- [ ] **Step 6: Thread `RetrievalDepth` into RagService**

In `lib/core/services/ai/rag_service.dart`, add the import:

```dart
import 'package:trovara/core/services/ai/retrieval_depth.dart';
```

Add a `RetrievalDepth depth = RetrievalDepth.free` named param to BOTH `query(...)` and `queryStream(...)`, and pass it into the two `_retriever.retrieve(...)` calls. For each call replace:

```dart
        fusionPoolSizePerQuery: searchTopK,
        minScore: minScore,
        expectedEmbeddingDim: stats.embeddingDimension,
        conversationContext: memory.rewriteContext.isEmpty ? null : memory.rewriteContext,
```

with:

```dart
        fusionPoolSizePerQuery: depth.fusionPoolSizePerQuery,
        minScore: minScore,
        expectedEmbeddingDim: stats.embeddingDimension,
        conversationContext: memory.rewriteContext.isEmpty ? null : memory.rewriteContext,
        topKChunks: depth.topKChunks,
        expansionCount: depth.expansionCount,
```

(Leave the existing `searchTopK` param in the signature for back-compat; `depth` now drives the pool size.)

- [ ] **Step 7: Run the AI service suite to verify no regression**

Run: `flutter test patrol_test/core/services/`
Expected: PASS — existing RAG/retriever tests still green (defaults unchanged: `expansionCount` defaults to 3, depth defaults to free only in `RagService`, but existing tests call `retrieve` directly with the old defaults).

- [ ] **Step 8: Commit**

```bash
git add lib/core/services/ai/retrieval_depth.dart lib/core/services/ai/rag_retriever.dart \
  lib/core/services/ai/rag_service.dart patrol_test/core/services/ai/retrieval_depth_test.dart
git commit -m "feat(ai): tier-aware retrieval depth in RagService/RagRetriever

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: OnDeviceLlmProvider stub + LlmProvider.onDevice

**Files:**
- Create: `lib/core/services/ai/_providers/on_device_llm_provider.dart`
- Modify: `lib/core/services/ai/llm_client.dart` (add enum value + switch arm)
- Test: `patrol_test/core/services/ai/on_device_llm_provider_test.dart`

**Interfaces:**
- Produces: `class OnDeviceLlmProvider implements LlmChatBackend` — deterministic placeholder until Plan B swaps in MediaPipe.
  - `generate(...)` → returns a fixed sentinel string `OnDeviceLlmProvider.comingSoonAnswer`.
  - `generateStream(...)` → yields that same string as a single chunk.
  - `static const String comingSoonAnswer = 'On-device AI is being prepared on your device. Please try again shortly.';`
- Consumes: `LlmChatBackend`, `ChatTurn` (`_providers/llm_chat_backend.dart`).
- Modifies: `LlmProvider` enum → `{ openAiCompatible, gemini, onDevice }`; `LlmClient.initialize()` switch gains an `onDevice` arm building `OnDeviceLlmProvider()`. The `_apiKey.isEmpty` early-return must be bypassed for on-device (no key needed).

- [ ] **Step 1: Write the failing test**

```dart
// patrol_test/core/services/ai/on_device_llm_provider_test.dart
import 'package:trovara/core/services/ai/_providers/on_device_llm_provider.dart';

import '../../../test_support.dart';

void main() {
  patrolTest('generate returns the coming-soon sentinel', (\$) async {
    final provider = OnDeviceLlmProvider();
    final answer = await provider.generate(systemPrompt: 's', history: const [], userMessage: 'hi');
    expect(answer, OnDeviceLlmProvider.comingSoonAnswer);
  });

  patrolTest('generateStream yields the sentinel as one chunk', (\$) async {
    final provider = OnDeviceLlmProvider();
    final chunks = await provider
        .generateStream(systemPrompt: 's', history: const [], userMessage: 'hi')
        .toList();
    expect(chunks, [OnDeviceLlmProvider.comingSoonAnswer]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test patrol_test/core/services/ai/on_device_llm_provider_test.dart`
Expected: FAIL — `on_device_llm_provider.dart` does not exist.

- [ ] **Step 3: Write the stub provider**

```dart
// lib/core/services/ai/_providers/on_device_llm_provider.dart
import 'package:trovara/core/services/ai/_providers/llm_chat_backend.dart';

/// Free-tier on-device chat backend.
///
/// STUB: returns a deterministic placeholder. Plan B replaces the body with a
/// MediaPipe LLM Inference runtime; the [LlmChatBackend] contract stays identical
/// so no caller changes when the real engine lands.
class OnDeviceLlmProvider implements LlmChatBackend {
  static const String comingSoonAnswer =
      'On-device AI is being prepared on your device. Please try again shortly.';

  @override
  Future<String> generate({
    required String systemPrompt,
    required List<ChatTurn> history,
    required String userMessage,
  }) async => comingSoonAnswer;

  @override
  Stream<String> generateStream({
    required String systemPrompt,
    required List<ChatTurn> history,
    required String userMessage,
  }) async* {
    yield comingSoonAnswer;
  }
}
```

- [ ] **Step 4: Wire the enum + switch in LlmClient**

In `lib/core/services/ai/llm_client.dart`:

Add the import:

```dart
import 'package:trovara/core/services/ai/_providers/on_device_llm_provider.dart';
```

Change the enum:

```dart
enum LlmProvider { openAiCompatible, gemini, onDevice }
```

In `initialize()`, bypass the empty-key guard for on-device and add the switch arm. Replace:

```dart
    if (_apiKey.isEmpty) {
      _logger.w('LlmClient: No API key provided — generation disabled');
      return;
    }

    _backend = switch (_provider) {
```

with:

```dart
    if (_provider != LlmProvider.onDevice && _apiKey.isEmpty) {
      _logger.w('LlmClient: No API key provided — generation disabled');
      return;
    }

    _backend = switch (_provider) {
      LlmProvider.onDevice => OnDeviceLlmProvider(),
```

(Leave the existing `gemini` and `openAiCompatible` arms unchanged after the new arm.)

Also make `isAvailable` true for on-device without a key. Replace:

```dart
  bool get isAvailable => _isInitialized && _apiKey.isNotEmpty;
```

with:

```dart
  bool get isAvailable => _isInitialized && (_provider == LlmProvider.onDevice || _apiKey.isNotEmpty);
```

- [ ] **Step 5: Run provider + llm_client tests to verify pass**

Run: `flutter test patrol_test/core/services/ai/on_device_llm_provider_test.dart patrol_test/core/services/`
Expected: PASS — new provider tests green; existing `llm_client` tests unaffected (default provider still `openAiCompatible`).

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/ai/_providers/on_device_llm_provider.dart lib/core/services/ai/llm_client.dart \
  patrol_test/core/services/ai/on_device_llm_provider_test.dart
git commit -m "feat(ai): add OnDeviceLlmProvider stub + LlmProvider.onDevice

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: BYOK key store (SharedPreferences)

**Files:**
- Create: `lib/core/services/ai/byok_key_store.dart`
- Test: `patrol_test/core/services/ai/byok_key_store_test.dart`

**Interfaces:**
- Produces: `class ByokKeyStore` (mirrors `note_tombstone_registry.dart` SharedPreferences pattern, with an in-memory cache for a synchronous `hasKey`):
  - `Future<void> load()` — populate cache from prefs (idempotent)
  - `bool get hasKey` — synchronous; true if a non-empty key is cached
  - `String? get key` — cached key or null
  - `Future<void> setKey(String value)` — trims; empty clears
  - `Future<void> clear()`
  - `static const String prefsKey = 'byok_gemini_api_key';`
- Note: BYOK is the user's own key on their own device. Stored in `SharedPreferences` for MVP; a follow-up may move to platform secure storage. Never logged, never synced to Drive (Global Constraints).

- [ ] **Step 1: Write the failing test**

```dart
// patrol_test/core/services/ai/byok_key_store_test.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trovara/core/services/ai/byok_key_store.dart';

import '../../../test_support.dart';

void main() {
  patrolTest('starts empty, stores and reports a key', (\$) async {
    SharedPreferences.setMockInitialValues({});
    final store = ByokKeyStore();
    await store.load();
    expect(store.hasKey, isFalse);

    await store.setKey('  my-key  ');
    expect(store.hasKey, isTrue);
    expect(store.key, 'my-key');
  });

  patrolTest('clear removes the key', (\$) async {
    SharedPreferences.setMockInitialValues({ByokKeyStore.prefsKey: 'k'});
    final store = ByokKeyStore();
    await store.load();
    expect(store.hasKey, isTrue);

    await store.clear();
    expect(store.hasKey, isFalse);
    expect(store.key, isNull);
  });

  patrolTest('setting an empty value clears the key', (\$) async {
    SharedPreferences.setMockInitialValues({});
    final store = ByokKeyStore();
    await store.load();
    await store.setKey('k');
    await store.setKey('   ');
    expect(store.hasKey, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test patrol_test/core/services/ai/byok_key_store_test.dart`
Expected: FAIL — `byok_key_store.dart` does not exist.

- [ ] **Step 3: Write the store**

```dart
// lib/core/services/ai/byok_key_store.dart
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's own ("bring your own key") AI API key for the free tier.
///
/// Backed by [SharedPreferences] with an in-memory cache so [hasKey] is sync
/// (needed by ChatTierResolver). Never logged; never synced to Drive.
class ByokKeyStore {
  static const String prefsKey = 'byok_gemini_api_key';

  String? _cached;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(prefsKey)?.trim();
    _cached = (value == null || value.isEmpty) ? null : value;
  }

  bool get hasKey => _cached != null && _cached!.isNotEmpty;

  String? get key => _cached;

  Future<void> setKey(String value) async {
    final trimmed = value.trim();
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      _cached = null;
      await prefs.remove(prefsKey);
      return;
    }
    _cached = trimmed;
    await prefs.setString(prefsKey, trimmed);
  }

  Future<void> clear() async {
    _cached = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test patrol_test/core/services/ai/byok_key_store_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/ai/byok_key_store.dart patrol_test/core/services/ai/byok_key_store_test.dart
git commit -m "feat(ai): add ByokKeyStore for free-tier bring-your-own-key

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Wire tier-aware chat backend + depth in ServiceLocator

**Files:**
- Modify: `lib/core/di/service_locator.dart`
- Test: `patrol_test/core/di/chat_tier_wiring_test.dart`

**Interfaces:**
- Consumes: `ByokKeyStore` (Task 4), `ChatTierResolver`/`ChatTier`/`ChatEngine` (Task 1), `RetrievalDepth` (Task 2), `LlmProvider.onDevice` (Task 3), existing `ProAccessService` getter.
- Produces (new lazy getters on `ServiceLocator`):
  - `ByokKeyStore get byokKeyStore`
  - `ChatTierResolver get chatTierResolver` (built from `proAccessService` + `() => byokKeyStore.hasKey`)
  - `LlmClient chatLlmClientForEngine(ChatEngine engine)` — returns the correct backend client:
    - `premiumCloud` → existing `llmClient` (cloud preference order unchanged)
    - `byokCloud` → a Gemini `LlmClient` built from `byokKeyStore.key!`
    - `onDevice` → `LlmClient(provider: LlmProvider.onDevice, apiKey: '')`
  - `RetrievalDepth get activeRetrievalDepth` → `RetrievalDepth.forTier(chatTierResolver.resolveTier())`
- Note: `ProAccessService.initialize()` and `byokKeyStore.load()` must be awaited in `ServiceLocator.initialize()` so sync resolution is correct at first chat. Add both calls to the existing `initialize()` body.

- [ ] **Step 1: Write the failing test**

```dart
// patrol_test/core/di/chat_tier_wiring_test.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/services/ai/chat_tier.dart';
import 'package:trovara/core/services/ai/llm_client.dart';
import 'package:trovara/core/services/ai/retrieval_depth.dart';

import '../../test_support.dart';

void main() {
  patrolTest('free + no key → onDevice engine, free depth', (\$) async {
    SharedPreferences.setMockInitialValues({});
    final locator = ServiceLocator();
    await locator.byokKeyStore.load();
    await locator.proAccessService.lockPro();

    final engine = locator.chatTierResolver.resolveEngine();
    expect(engine, ChatEngine.onDevice);
    expect(locator.chatLlmClientForEngine(engine).provider, LlmProvider.onDevice);
    expect(locator.activeRetrievalDepth, same(RetrievalDepth.free));
  });

  patrolTest('pro → premiumCloud engine, pro depth', (\$) async {
    SharedPreferences.setMockInitialValues({});
    final locator = ServiceLocator();
    await locator.byokKeyStore.load();
    await locator.proAccessService.unlockPro();

    expect(locator.chatTierResolver.resolveEngine(), ChatEngine.premiumCloud);
    expect(locator.activeRetrievalDepth, same(RetrievalDepth.pro));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test patrol_test/core/di/chat_tier_wiring_test.dart`
Expected: FAIL — `byokKeyStore` / `chatTierResolver` / `chatLlmClientForEngine` / `activeRetrievalDepth` are undefined on `ServiceLocator`.

- [ ] **Step 3: Add imports + backing fields**

In `lib/core/di/service_locator.dart`, add imports:

```dart
import 'package:trovara/core/services/ai/byok_key_store.dart';
import 'package:trovara/core/services/ai/chat_tier.dart';
import 'package:trovara/core/services/ai/chat_tier_resolver.dart';
import 'package:trovara/core/services/ai/retrieval_depth.dart';
```

Add nullable backing fields next to the other `_xxx` fields (near `_billingService`):

```dart
  ByokKeyStore? _byokKeyStore;
  ChatTierResolver? _chatTierResolver;
```

- [ ] **Step 4: Add the getters + factory**

Add near the `llmClient` getter:

```dart
  /// Free-tier bring-your-own-key store.
  ByokKeyStore get byokKeyStore => _byokKeyStore ??= ByokKeyStore();

  /// Single decision point for chat tier + engine.
  ChatTierResolver get chatTierResolver => _chatTierResolver ??=
      ChatTierResolver(proAccess: proAccessService, hasByokKey: () => byokKeyStore.hasKey);

  /// Retrieval depth preset for the currently-active chat tier.
  RetrievalDepth get activeRetrievalDepth => RetrievalDepth.forTier(chatTierResolver.resolveTier());

  /// Build the chat [LlmClient] for a resolved [ChatEngine].
  LlmClient chatLlmClientForEngine(ChatEngine engine) {
    switch (engine) {
      case ChatEngine.premiumCloud:
        return llmClient;
      case ChatEngine.byokCloud:
        return LlmClient(
          provider: LlmProvider.gemini,
          apiKey: byokKeyStore.key ?? '',
          modelName: LlmClient.defaultGeminiModel,
        );
      case ChatEngine.onDevice:
        return LlmClient(provider: LlmProvider.onDevice, apiKey: '');
    }
  }
```

- [ ] **Step 5: Await stores in initialize()**

In `ServiceLocator.initialize()`, add (after the existing repository/service wiring, before completion):

```dart
    await proAccessService.initialize();
    await byokKeyStore.load();
```

- [ ] **Step 6: Run analyze + the wiring test**

Run: `flutter analyze lib/core/di/service_locator.dart && flutter test patrol_test/core/di/chat_tier_wiring_test.dart`
Expected: analyze clean; 2 tests PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/core/di/service_locator.dart patrol_test/core/di/chat_tier_wiring_test.dart
git commit -m "feat(di): wire tier-aware chat backend + retrieval depth

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Chat tier badge + upgrade nudge (UI)

**Files:**
- Modify: `lib/views/chat/chat_view_model.dart` (expose `ChatTier get chatTier`)
- Modify: `lib/views/chat/` content/widgets — add a tier badge + a free-tier "Upgrade" nudge
- Modify: `assets/translations/en.json` and `assets/translations/km.json`
- Test: `patrol_test/views/chat/chat_tier_badge_test.dart`

**Interfaces:**
- Consumes: `ChatTierResolver` via `ServiceLocator().chatTierResolver`; `ChatTier`.
- Produces: `ChatTier get chatTier => _tierResolver.resolveTier();` on `ChatViewModel`, and a `_ChatTierBadge` private widget (part file) showing "On-device" (free) / "Pro" (pro) and, when free, an upgrade action routing to `/pro/paywall`.
- i18n keys (BOTH `en.json` and `km.json`):
  - `chat.tier.free_badge` → en: `"On-device"`, km: `"ក្នុងឧបករណ៍"`
  - `chat.tier.pro_badge` → en: `"Pro"`, km: `"Pro"`
  - `chat.tier.upgrade_cta` → en: `"Upgrade for better answers"`, km: `"ដំឡើងកំណែ ដើម្បីចម្លើយប្រសើរ"`

- [ ] **Step 1: Add the i18n keys to en.json**

Under the existing `"chat"` object in `assets/translations/en.json`, add:

```json
"tier": {
  "free_badge": "On-device",
  "pro_badge": "Pro",
  "upgrade_cta": "Upgrade for better answers"
}
```

- [ ] **Step 2: Mirror the keys in km.json**

Under the `"chat"` object in `assets/translations/km.json`, add:

```json
"tier": {
  "free_badge": "ក្នុងឧបករណ៍",
  "pro_badge": "Pro",
  "upgrade_cta": "ដំឡើងកំណែ ដើម្បីចម្លើយប្រសើរ"
}
```

- [ ] **Step 3: Verify i18n parity**

Run: `flutter test patrol_test` (the i18n parity test) or the `/i18n-check` command.
Expected: parity OK — en and km have identical keys.

- [ ] **Step 4: Expose tier on ChatViewModel**

In `lib/views/chat/chat_view_model.dart`, add a field from the locator and a getter:

```dart
  final ChatTierResolver _tierResolver = ServiceLocator().chatTierResolver;

  ChatTier get chatTier => _tierResolver.resolveTier();
```

(Add imports `package:trovara/core/services/ai/chat_tier.dart` and `chat_tier_resolver.dart`. Do not import `service_locator` if already imported.)

- [ ] **Step 5: Write the failing widget test**

```dart
// patrol_test/views/chat/chat_tier_badge_test.dart
import 'package:flutter/material.dart';
import 'package:trovara/core/services/ai/chat_tier.dart';

import '../../test_support.dart';

void main() {
  patrolTest('free tier shows on-device badge label key', (\$) async {
    // Badge maps ChatTier.free → 'chat.tier.free_badge'.
    expect(badgeKeyForTier(ChatTier.free), 'chat.tier.free_badge');
    expect(badgeKeyForTier(ChatTier.pro), 'chat.tier.pro_badge');
  });
}

// Pure mapping under test, colocated with the badge widget.
String badgeKeyForTier(ChatTier tier) =>
    tier == ChatTier.pro ? 'chat.tier.pro_badge' : 'chat.tier.free_badge';
```

- [ ] **Step 6: Add the badge widget + mapping**

Create the badge as a `part` file of the chat view (follow the existing chat view's `part` structure). Define the top-level helper `badgeKeyForTier` (matching the test) in the same file, and a `_ChatTierBadge` widget:

```dart
// part of '<chat_view>.dart';

String badgeKeyForTier(ChatTier tier) =>
    tier == ChatTier.pro ? 'chat.tier.pro_badge' : 'chat.tier.free_badge';

class _ChatTierBadge extends StatelessWidget {
  const _ChatTierBadge({required this.tier});

  final ChatTier tier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          tier == ChatTier.pro ? LucideIcons.sparkles : LucideIcons.cpu,
          size: 14,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 4),
        Text(tr(badgeKeyForTier(tier)), style: theme.textTheme.labelSmall),
        if (tier == ChatTier.free) ...[
          const SizedBox(width: 8),
          TextButton(
            key: const ValueKey('chat-upgrade-cta'),
            onPressed: () => context.push('/pro/paywall'),
            child: Text(tr('chat.tier.upgrade_cta')),
          ),
        ],
      ],
    );
  }
}
```

Render `_ChatTierBadge(tier: viewModel.chatTier)` in the chat content header (e.g. the chat `AppBar`'s `bottom` or the top of the message list). Add the `part` declaration to the chat view and ensure `chat_tier.dart`, `lucide_icons_flutter`, `easy_localization`, and `go_router` are imported by the chat view.

- [ ] **Step 7: Run analyze + tests**

Run: `flutter analyze lib/views/chat/ && flutter test patrol_test/views/chat/`
Expected: analyze clean; badge mapping test PASS; existing chat tests unaffected.

- [ ] **Step 8: Commit**

```bash
git add lib/views/chat/ assets/translations/en.json assets/translations/km.json \
  patrol_test/views/chat/chat_tier_badge_test.dart
git commit -m "feat(chat): tier badge + free-tier upgrade nudge

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: Use the active backend + depth in chat generation

**Files:**
- Modify: `lib/views/chat/chat_view_model.dart` (or the chat send path) to drive generation through the tier-selected client + depth
- Test: `patrol_test/views/chat/chat_tier_generation_test.dart`

**Interfaces:**
- Consumes: `ServiceLocator().chatTierResolver`, `chatLlmClientForEngine(...)`, `activeRetrievalDepth`, `RagService.queryStream(..., depth: ...)`.
- Behavior: when sending a chat message, the VM resolves the engine, and passes `ServiceLocator().activeRetrievalDepth` into `RagService.queryStream`. (If the chat path currently uses the global `ragService` with its fixed `llmClient`, this task documents the seam: free tier routes through the on-device/byok client. Minimal step here = pass `depth:` so retrieval is tiered immediately; full backend swap for chat generation is completed when Plan B's real on-device runtime lands.)

- [ ] **Step 1: Write the failing test**

```dart
// patrol_test/views/chat/chat_tier_generation_test.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/services/ai/retrieval_depth.dart';

import '../../test_support.dart';

void main() {
  patrolTest('active depth follows pro entitlement', (\$) async {
    SharedPreferences.setMockInitialValues({});
    final locator = ServiceLocator();
    await locator.byokKeyStore.load();

    await locator.proAccessService.lockPro();
    expect(locator.activeRetrievalDepth, same(RetrievalDepth.free));

    await locator.proAccessService.unlockPro();
    expect(locator.activeRetrievalDepth, same(RetrievalDepth.pro));
  });
}
```

- [ ] **Step 2: Run test to verify it fails (or passes if Task 5 already covers it)**

Run: `flutter test patrol_test/views/chat/chat_tier_generation_test.dart`
Expected: PASS once Task 5 is merged (this locks the entitlement→depth contract from the chat layer's perspective). If it fails, the `activeRetrievalDepth` getter regressed — fix before continuing.

- [ ] **Step 3: Thread `depth:` into the chat send path**

In `lib/views/chat/chat_view_model.dart`, find the call to `ragService.queryStream(...)` (or `query(...)`) and add the depth argument:

```dart
    final stream = _ragService.queryStream(
      userMessage,
      priorTurns: priorTurns,
      depth: ServiceLocator().activeRetrievalDepth,
    );
```

(Keep all existing arguments; only add `depth:`.)

- [ ] **Step 4: Run the chat suite**

Run: `flutter test patrol_test/views/chat/`
Expected: PASS — chat tests green with tiered depth wired in.

- [ ] **Step 5: Full analyze + test sweep**

Run: `flutter analyze && flutter test patrol_test`
Expected: no new analyze errors; full suite PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/views/chat/chat_view_model.dart patrol_test/views/chat/chat_tier_generation_test.dart
git commit -m "feat(chat): drive RAG retrieval depth from active tier

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Out of Scope (deferred)

- **Plan B:** real MediaPipe LLM Inference on-device runtime + model packaging (bundle vs first-run download), swapped behind `OnDeviceLlmProvider`.
- **Full chat backend swap:** routing free-tier *generation* (not just retrieval depth) through the on-device/BYOK client end-to-end — completes when Plan B's runtime exists.
- **ProAccessService persistence** (Tier 1.3) — required for tier to survive restart; tracked separately in the roadmap.
- **BYOK settings UI** (the input field to enter the key) — can be a small follow-up; `ByokKeyStore` is the backing store it will use.
- Premium model selection refinements and reranking quality tuning.

## Self-Review Notes

- **Spec coverage:** on-device free default (Tasks 3,5) · BYOK advanced (Tasks 4,5) · Pro premium + enhanced retrieval (Tasks 2,5) · no RAG rewrite (Task 2 only threads params) · tier UI affordances (Task 6) · sequencing with Option A (on-device is a stub, ships without billing). ✓
- **Type consistency:** `ChatTier`/`ChatEngine` (Task 1) reused verbatim in Tasks 2,5,6,7; `RetrievalDepth.{free,pro,forTier}` (Task 2) reused in Tasks 5,7; `OnDeviceLlmProvider` + `LlmProvider.onDevice` (Task 3) reused in Task 5; `ByokKeyStore.{hasKey,key,load}` (Task 4) reused in Task 5. ✓
- **No placeholders:** every code step contains complete code; commands have expected outcomes. ✓
