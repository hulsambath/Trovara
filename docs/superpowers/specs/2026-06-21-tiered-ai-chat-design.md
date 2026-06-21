# Trovara — Tiered AI Chat (Free On-Device · Pro Premium Cloud)

**Date:** 2026-06-21
**Author:** Sambath HUL (with Claude Code)
**Status:** Approved direction — implementation plan to follow
**Parent roadmap:** `docs/superpowers/specs/2026-06-20-unified-enhancement-roadmap.md` (expands Tier 4.1)
**Relates to:** Pro tier (`docs/superpowers/specs/2026-05-22-trovara-pro-phase2-design.md`)

---

## 1. Problem & Goal

We want **free, unlimited AI chat over the user's notes**, with quality as the paid upgrade:
free users get a capable-but-modest experience at zero cost to us; paying users get
premium-model quality and stronger retrieval.

**The economic constraint (non-negotiable):** "free + unlimited + cloud LLM" cannot coexist —
any free user hitting *our* cloud key with no cap scales our bill linearly with usage. Therefore
the **free tier must have zero marginal cost to us.** This spec achieves that with an on-device
model as the free default.

**Non-goal:** Replacing the RAG pipeline. RAG (retrieval → context assembly → generation) stays.
Only the **generation backend (the model)** and **retrieval depth** are tiered.

---

## 2. Approved Tier Design

```
FREE  ├─ On-device model (DEFAULT)  → 0 marginal cost, offline, unlimited, private
      └─ BYOK (optional, advanced)  → user pastes their own cloud key; still free to us
PRO   └─ Premium cloud on OUR key   → top models + enhanced retrieval (subscription-funded)
```

| Dimension | Free (on-device) | Free (BYOK) | Pro |
|---|---|---|---|
| Generation model | Bundled small LLM (e.g. Gemma 2B / Phi-3-mini class) | User's cloud key (their quota) | Premium cloud (Gemini 1.5 Pro / GPT-4-class / Claude) |
| Marginal cost to us | Zero | Zero | Covered by subscription |
| Rate limit | None | User's own | Generous |
| Offline | Yes | No | No |
| Retrieval | Base RAG (single query, standard context budget) | Base RAG | Enhanced: multi-query expansion + larger context budget + reranking |
| Embeddings | On-device (ONNX, already started) | On-device or cloud per key | Cloud |

---

## 3. Key Architectural Insight

RAG is "retrieve relevant notes → build a prompt → ask a model." The **quality knob is the model
and the retrieval depth, not the RAG structure.** So we do **not** rewrite `RagService`. We:

1. Add an **on-device generation backend** behind the existing `LlmChatBackend` interface.
2. Add a **chat tier** dimension to backend selection in `ServiceLocator`.
3. Gate **retrieval depth** (multi-query expansion, context budget, reranking) on tier.

This reuses the seam that already exists: `LlmClient` is a thin facade over a swappable
`LlmChatBackend`, and providers live one-per-file in `lib/core/services/ai/_providers/`.

---

## 4. Components

### 4.1 New: `OnDeviceLlmProvider` (`lib/core/services/ai/_providers/on_device_llm_provider.dart`)
- Implements `LlmChatBackend` (same `generate` / `generateStream` contract as the cloud providers).
- Wraps an on-device inference runtime. Candidate runtimes (decide in plan):
  - **MediaPipe LLM Inference** (Google, first-class Gemma support, Android + iOS) — recommended.
  - llama.cpp via FFI, or ONNX Runtime GenAI (consistent with the existing `onnx_embedding_provider.dart`).
- Loads the model lazily on first chat; surfaces a one-time download/warm-up state to the VM.
- Streams tokens so `ChatView` behaves identically to cloud streaming.
- Must honor the `LlmChatBackend` contract exactly (Liskov) — no throwing on empty history, etc.

### 4.2 Extend: `LlmProvider` enum + selection
- Add `LlmProvider.onDevice`.
- Selection becomes **tier-aware** in `ServiceLocator`:

```
chat backend =
  if (Pro)                         → premium cloud provider (best available key)
  else if (user supplied own key)  → that cloud provider (BYOK)
  else                             → OnDeviceLlmProvider   // free default
```

- Mirrors the existing Gemini→OpenAI→OpenRouter fallback style; tier is just the first discriminator.

### 4.3 New: `ChatTier` concept
- Source of truth: `ProAccessService.isProUnlocked` + a BYOK key presence check.
- A small `ChatTierResolver` (or a method on `ServiceLocator`) returns the active tier so both
  backend selection and retrieval-depth selection read from one place (DRY, single decision point).

### 4.4 Extend: retrieval depth gating (`RagService` / `RagRetriever`)
- `RagRetriever.retrieve(...)` gains a depth/budget parameter driven by tier:
  - **Free:** single rewritten query, standard top-K, standard token budget.
  - **Pro:** multi-query expansion ON, larger context budget, optional reranking.
- These services **already exist** (`MultiQueryExpansionService`, `PromptBuilderService` token budget) —
  this is wiring + a flag, not new pipeline code.

### 4.5 BYOK surface (free, advanced)
- A settings entry: "Use my own AI key (advanced)" → stores key in secure storage.
- When present and user is free, selection routes to the matching cloud provider.
- No new provider code — reuses `GeminiApiLlmProvider` / `OpenAiCompatibleLlmProvider`.

### 4.6 Chat UI affordances (`ChatView`)
- A subtle **tier badge** ("On-device" / "Pro") so quality expectations are set.
- First on-device run shows a model **download/warm-up** state (size disclosed up front).
- A **"Upgrade for better answers"** nudge in the free chat (ties into `PaywallView`).

---

## 5. Data Flow (unchanged skeleton, tiered ends)

```
User message
  → ChatTierResolver decides tier
  → RagRetriever.retrieve(query, depth = tierDepth)      // base vs enhanced
  → PromptBuilderService.build(context, budget = tierBudget)
  → LlmChatBackend.generateStream(prompt)                // on-device | BYOK | premium cloud
  → stream tokens to ChatView
```

Only the **two endpoints** (retrieval depth, generation backend) change with tier. Everything
between is the current pipeline.

---

## 6. Edge Cases & Risks

- **App size / model packaging:** bundling vs first-run download. Decide in plan — first-run
  download keeps the base APK/IPA small but needs a download UX + storage check + offline-first-run
  handling. Recommended: download-on-first-chat with clear size disclosure.
- **Embedding dimension compatibility:** on-device embeddings (ONNX) must not collide with notes
  already embedded by a cloud provider. Reuse the existing per-note embedding signature/versioning;
  re-embed on provider mismatch (already a concern flagged in roadmap 4.1).
- **On-device runtime per platform:** Android and iOS inference paths differ; MediaPipe covers both
  but verify iOS Share-Extension / background constraints don't apply here (chat is foreground).
- **Quality gap must feel intentional, not broken:** on-device answers should be clearly labeled and
  good enough to be useful; the Pro gap comes from both model and enhanced retrieval, so it reads as
  "better," not "the free one is broken."
- **BYOK key safety:** store in secure storage, never log, never sync to Drive.
- **Cold-start latency:** first on-device generation warms the model; show a spinner, keep the model
  resident for the session.

---

## 7. Why this fits the codebase (minimal blast radius)

- `LlmClient` is already a facade over `LlmChatBackend?` → add one backend, no caller churn.
- Providers are already one-per-file in `_providers/` → `OnDeviceLlmProvider` follows the pattern.
- `ServiceLocator` already selects providers by availability → add tier as the first discriminator.
- `MultiQueryExpansionService` + token-budget logic already exist → tier just toggles them.
- `onnx_embedding_provider.dart` already proves an on-device runtime works in this app.

Net: **no RAG rewrite.** New code is one generation backend + a tier resolver + selection wiring +
a flag threaded through retrieval + BYOK settings + chat UI affordances.

---

## 8. Sequencing (relative to the Option-A free release)

Option A (free store release) ships **before** premium billing is live. So:

1. **Pre-release (part of Option A):** On-device backend + tier resolver, with tier hard-pinned to
   "free / on-device" (Pro path stubbed). Free unlimited chat works at launch; no billing needed.
2. **Fast-follow (v1.1, with native billing):** flip the Pro arm on — premium cloud + enhanced
   retrieval behind the paywall. BYOK can land in either step (it's free-tier, billing-independent).

This lets the free on-device chat be a **launch feature** while premium chat becomes the paid hook.

---

## 9. Open Decisions for the Implementation Plan

- On-device runtime: **MediaPipe LLM Inference** (recommended) vs ONNX Runtime GenAI vs llama.cpp FFI.
- Specific free model + quantization (size vs quality trade-off).
- Bundle vs first-run download for the model file.
- Exact Pro premium model order (mirror the existing Gemini→OpenAI→OpenRouter preference?).
- BYOK in pre-release vs fast-follow.
```
