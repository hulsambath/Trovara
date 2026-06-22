---
name: doc-helper
description: Use when a new service, repository, or subsystem needs documentation — CLAUDE.md for new directories, dartdoc for public APIs, or updating existing architecture docs after a structural change.
allowed-tools: Read, Grep, Glob, Bash, Edit, Write
model: sonnet
---

# Doc Helper — Trovara Documentation

Generates accurate, concise documentation grounded in the actual code. Read the code first, then write. Never fabricate API details.

## Step 1 — Identify the Target

| Request | What to produce |
|---------|----------------|
| New `lib/core/services/<name>/` | `CLAUDE.md` in that directory |
| New `lib/views/<feature>/` | No CLAUDE.md needed — covered by `lib/views/CLAUDE.md` |
| New public service / repository class | Dartdoc on the class and its public methods |
| New subsystem added to `lib/core/` | Add a section to `lib/core/CLAUDE.md` |
| PR ready to open | Use `pr-prep` skill instead |

## Step 2 — Read Before Writing

Always read:
1. The target file(s) with the Read tool
2. The nearest existing `CLAUDE.md` — match tone and structure
3. Root `CLAUDE.md` — non-negotiable rules to reference where relevant

## Step 3 — CLAUDE.md for a New Service Directory

Use for `lib/core/services/<name>/CLAUDE.md`:

```markdown
# <Name> Service

## Purpose

One paragraph. What problem does this service solve? What does it own? What does it NOT own?

## Public API

### `<ClassName>`

Constructor params and what each one does (one line each).
Key public methods — name, return type, one-line purpose.
Skip getters that mirror a property name.

## Invariants & Constraints

- Threading model (main thread / background isolate)
- Caching strategy (e.g., SHA-256 signatures for change detection)
- Error contract (throws / returns null / returns Result type)
- Dependencies on other services and why

## What NOT to Put Here

List things that belong elsewhere (e.g., "UI state → ViewModel").

## Common Mistakes

1–3 bullets of easy-to-make mistakes given this service's shape.
```

## Step 4 — Dartdoc for Public Classes

Rules:
- Document the **why** and **invariants** — the signature already says what
- One-sentence summary on the class line
- Only document public methods with non-obvious behavior
- Skip trivial getters, `copyWith`, `toString`
- One short paragraph max — never multi-paragraph docstrings

```dart
/// Orchestrates RAG query flow: rewrite → embed → search → rank → prompt → stream.
///
/// All methods are safe to call from the main isolate. Heavy work (embedding,
/// HTTP) runs asynchronously and does not block the UI thread.
class RagService {
  /// Streams LLM response tokens for [query] using top-[topK] context notes.
  ///
  /// Throws [RagException] if embedding or LLM calls fail after retry.
  Stream<String> query(String query, {int topK = 5}) { ... }
}
```

## Step 5 — Updating lib/core/CLAUDE.md

When a new service or subsystem is added:
1. Read the current `lib/core/CLAUDE.md`
2. Add a row to the Services table and a short paragraph under Key Subsystems
3. Find the right insertion point — don't append to the end

## Quality Checklist

- [ ] Nothing documented that the name + type already conveys
- [ ] No fabricated method signatures — verified against actual file
- [ ] Invariants section covers error contract and threading model
- [ ] Common Mistakes covers the top 1–2 footguns in this code
- [ ] Follows 120-char line width (same as Dart code)
- [ ] Single quotes in any Dart examples
