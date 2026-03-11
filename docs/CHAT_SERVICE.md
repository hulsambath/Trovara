# Chat Service

> Service layer for chat thread and message operations, including
> import/export and Drive sync support.

`ChatService` coordinates between `IChatThreadRepository` and
`IChatMessageRepository` and encapsulates business rules such as thread
reuse, message truncation, and merge-based import/export.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Files & Classes](#3-files--classes)
4. [Thread Operations](#4-thread-operations)
5. [Message Operations](#5-message-operations)
6. [Delete & Cleanup](#6-delete--cleanup)
7. [Import / Export / Merge](#7-import--export--merge)
8. [Lifecycle & Listeners](#8-lifecycle--listeners)
9. [Dependency Injection](#9-dependency-injection)

---

## 1. Overview

Trovara supports two types of chat:

- **Per-note threads** – scoped to a single note, used for note-specific
  questions via the RAG pipeline.
- **Global threads** – general-purpose conversations not tied to any note.

`ChatService` manages both, backed by ObjectBox repositories.

---

## 2. Architecture

```
ChatViewModel
      │
      ▼
  ChatService           ◄── business rules, coordination
      │
      ├──► IChatThreadRepository   (thread persistence)
      └──► IChatMessageRepository  (message persistence)
```

---

## 3. Files & Classes

| File                                                          | Purpose                     |
| ------------------------------------------------------------- | --------------------------- |
| `lib/core/services/chat_service.dart`                         | Service implementation      |
| `lib/core/repository/interfaces/chat_thread_repository.dart`  | Thread repository contract  |
| `lib/core/repository/interfaces/chat_message_repository.dart` | Message repository contract |
| `lib/models/chat_thread.dart`                                 | ChatThread entity           |
| `lib/models/chat_message.dart`                                | ChatMessageEntity           |

---

## 4. Thread Operations

### `startPerNoteThread(noteId)`

```dart
Future<ChatThread> startPerNoteThread(int noteId)
```

Returns an existing thread for the note if one exists, otherwise creates
a new `per_note` thread. This ensures one active thread per note.

### `startGlobalThread({title})`

```dart
Future<ChatThread> startGlobalThread({String? title})
```

Creates a new `global` thread. Multiple global threads can coexist.

### Other thread methods

| Method                     | Returns                         |
| -------------------------- | ------------------------------- |
| `getThreadsByNote(noteId)` | All threads for a specific note |
| `getGlobalThreads()`       | All global (non-note) threads   |
| `getThreadById(id)`        | Single thread by ID             |
| `updateThread(thread)`     | Persists thread changes         |

---

## 5. Message Operations

### `addUserMessage(thread, text)`

```dart
Future<ChatMessageEntity> addUserMessage(ChatThread thread, String text)
```

Appends a user message to the thread and bumps the thread's `updatedAt`.

### `addAssistantMessage(thread, content, {...})`

```dart
Future<ChatMessageEntity> addAssistantMessage(
  ChatThread thread,
  String content, {
  List<String> sourceNoteTitles,
  int? promptTokens,
  int? completionTokens,
})
```

Appends an assistant response with optional metadata (source notes, token
usage).

### Query methods

| Method                                 | Returns                      |
| -------------------------------------- | ---------------------------- |
| `getMessagesForThread(threadId)`       | All messages in a thread     |
| `getRecentMessages(threadId, {limit})` | Last N messages (default 50) |

---

## 6. Delete & Cleanup

| Method                                    | Behaviour                                                                    |
| ----------------------------------------- | ---------------------------------------------------------------------------- |
| `deleteThread(threadId)`                  | Deletes the thread and all its messages.                                     |
| `clearThreadHistory(threadId)`            | Deletes all messages but keeps the thread itself.                            |
| `truncateThread(threadId, {maxMessages})` | Keeps only the most recent N messages (default 100). Removes older messages. |

---

## 7. Import / Export / Merge

### `exportAllToJson()`

Exports all threads and their messages to a JSON map:

```json
{
  "version": 1,
  "exportedAt": "2026-03-10T...",
  "threads": [...],
  "messages": [...]
}
```

### `importAllFromJson(json)`

Upsert import: threads and messages are matched by `id`. If a local entity
exists and the import has a newer `updatedAt`, it is updated.

### `mergeWithRemoteData(remoteData)`

Merges local and remote data using latest-wins strategy:

- Threads keyed by `id`.
- Messages keyed by `threadId_id`.
- `updatedAt` timestamp comparison resolves conflicts.

---

## 8. Lifecycle & Listeners

```dart
void addListener(Function() listener)    // registers on both repos
void removeListener(Function() listener)
void dispose()                           // disposes both repos
```

---

## 9. Dependency Injection

```dart
ChatService get chatService {
  _chatService ??= ChatService(
    threadRepository: chatThreadRepository,
    messageRepository: chatMessageRepository,
  );
  return _chatService!;
}
```

Access via `ServiceLocator().chatService`.
