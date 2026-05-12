# Patrol Unit Testing Guide

This document outlines the testing structure for the logic and unit tests located in the `patrol_test` directory.

## Overview

The unit tests in this project have been migrated to utilize Patrol's testing framework via the `patrol_finders` package. This provides a unified callback structure (`($) async`) across both integration tests and unit tests.

Using `patrol_finders` allows us to run logic-only tests locally without needing an emulator or encountering native automation binding errors (e.g., `LateInitializationError` for `patrolAppService`).

## How to Run the Tests

To run the entire unit test suite inside the `patrol_test` directory:

```bash
flutter test patrol_test
```

To run a specific test file:

```bash
flutter test patrol_test/core/import/converters/markdown_to_quill_test.dart
```

## What the Tests Cover

The `patrol_test` directory contains 194 distinct tests that ensure the reliability of the core services. Below is a high-level summary of the covered components:

### 1. Document and RAG Services (`core/services/`)
- **EmbeddingService**: Verifies the creation of deterministic text chunks and signatures, and tests the logic for determining when notes are stale (i.e. need re-embedding).
- **VectorSearchService**: Tests cosine similarity calculations (identical, orthogonal, opposite vectors) and validates search ranking, exclusion rules, and metadata filtering.
- **PromptBuilderService**: Validates the construction of prompts for the LLM. Ensures token budgets are respected, note metadata (titles, tags, dates) is injected properly, and context delimiters are cleanly formatted.
- **DocumentResolverService**: Tests the resolution logic that maps raw vector chunks back to their originating note records, averaging scores and respecting text limits.
- **RagService**: Tests the end-to-end RAG pipeline including prompt expansion, chunk retrieval, stream emitting, and graceful handling of missing or deleted notes.
- **RagChatMemoryTest**: Ensures chat transcript truncation correctly prioritizes the most recent turns while keeping strictly below token boundaries.

### 2. Import Converters (`core/import/converters/`)
These tests validate the conversion logic between Markdown syntax and internal Quill Deltas.
- **Markdown to Quill**: Tests parsing logic that turns raw markdown into JSON-friendly Delta operations.
  - Heading tags (`#`) to newline header attributes.
  - Lists (`-`, `1.`) to bullet or ordered list blocks.
  - Links (`[text](url)`) to link embeddings.
  - Horizontal rules (`---`) to divider objects.
  - **Formatting**: Tests conversion of **bold** (`**`), *italic* (`*`), and blockquotes (`>`).
- **Quill to Markdown**: Reverses the process, ensuring changes in the rich text editor map accurately back to Markdown strings. Tests cover links, lists, headings, dividers, bold, italics, and blockquotes.
- **Round Trip**: Validates that saving Markdown to Quill and back to Markdown results in structurally identical text.

### 3. External Import Adapters (`core/import/adapters/`)
- **Obsidian Adapter**: Tests parsing rules specific to Obsidian. This covers frontmatter extraction (YAML tags, created/modified dates), internal wikilinks (`[[link]]`), hierarchical folder translation, and inline `#tags`.
- **Notion Adapter**: Tests parsing of Notion's distinct Markdown export style, ensuring it handles 32-character UUID stripping from filenames, property line extraction (`**Tags:**`), HTML tag stripping, and unique formatting edge cases.

## Writing New Tests

When adding new tests to the `patrol_test` directory, make sure to import the shared test support file and use `patrolTest`:

```dart
import 'package:flutter_test/flutter_test.dart';
import '../../test_support.dart'; // Ensure you import test_support to get Patrol bindings

void main() {
  patrolTest('description of your test', ($) async {
    // Your test logic here
    expect(1, 1);
  });
}
```