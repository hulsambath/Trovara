# Text Parser Service

> Parses Quill Delta JSON content into plain text, previews, word counts,
> and character counts.

`TextParserService` is a stateless utility class with static methods. It is
used throughout the app wherever Quill document content needs to be
presented as plain text — note cards, search, embeddings, and statistics.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Files & Classes](#2-files--classes)
3. [Public API](#3-public-api)
4. [Quill JSON Formats](#4-quill-json-formats)
5. [Usage Examples](#5-usage-examples)

---

## 1. Overview

Trovara stores note content as **Quill Delta JSON**, a rich-text format
produced by the `flutter_quill` editor. The Delta format encodes text,
formatting, and embeds as an array of operations:

```json
{
  "ops": [
    { "insert": "Hello " },
    { "insert": "world", "attributes": { "bold": true } },
    { "insert": "\n" }
  ]
}
```

`TextParserService` extracts only the textual content from these
operations, stripping formatting attributes and normalising whitespace.

---

## 2. Files & Classes

| File                                         | Purpose                |
| -------------------------------------------- | ---------------------- |
| `lib/core/services/text_parser_service.dart` | Service implementation |

No dependencies beyond `dart:convert`. Follows Single Responsibility
Principle — only handles text parsing.

---

## 3. Public API

All methods are **static** (no instance needed).

### `parseQuillContent(content)`

```dart
static String parseQuillContent(String content)
```

Extracts plain text from Quill Delta JSON. Handles both `{"ops": [...]}`
and bare `[...]` formats. Strips newlines, collapses whitespace.

Falls back to basic HTML tag stripping if JSON parsing fails.

### `getPreviewText(content, {maxLength})`

```dart
static String getPreviewText(String content, {int maxLength = 150})
```

Returns a truncated plain-text preview for note cards. Appends `...` if
the text exceeds `maxLength`.

### `calculateWordCount(content)`

```dart
static int calculateWordCount(String content)
```

Splits parsed text on whitespace and counts non-empty segments.

### `calculateCharacterCount(content)`

```dart
static int calculateCharacterCount(String content)
```

Returns the character length of the parsed plain text.

---

## 4. Quill JSON Formats

The parser handles two JSON shapes:

| Shape                 | Example                           |
| --------------------- | --------------------------------- |
| Standard Quill object | `{"ops": [{"insert": "text\n"}]}` |
| Direct ops array      | `[{"insert": "text\n"}]`          |

Only `"insert"` values of type `String` are extracted. Non-string inserts
(e.g. embedded images) are silently skipped.

---

## 5. Usage Examples

`TextParserService` is used by:

| Consumer                     | Method called             | Purpose                        |
| ---------------------------- | ------------------------- | ------------------------------ |
| `Note.content` getter        | `parseQuillContent`       | Plain-text content accessor    |
| `Note.wordCount` getter      | `calculateWordCount`      | Statistics                     |
| `Note.characterCount` getter | `calculateCharacterCount` | Statistics                     |
| `NoteCard` widget            | `getPreviewText`          | Preview in note list           |
| `NoteCard` widget            | `parseQuillContent`       | Expanded content view          |
| `EmbeddingService`           | `parseQuillContent`       | Text extraction for embeddings |
