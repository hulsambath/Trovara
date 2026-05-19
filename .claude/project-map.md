# Trovara — Project Map

> Claude Code: use this as an index to find files. Don't read the files themselves unless the task requires it.

## Context Files (read per routing table in CLAUDE.md)

```
CLAUDE.md                              ← ROOT: read first, always
lib/core/CLAUDE.md                     ← services, repos, DI, layering rules
lib/views/CLAUDE.md                    ← view structure, MVVM, pitfalls
lib/core/services/ai/CLAUDE.md         ← RAG pipeline rules, provider order
lib/core/storage/CLAUDE.md             ← storage layer patterns
docs/style_guide/Views_Style_Guide.md  ← authoritative view spec
docs/style_guide/File_Organization_Rules.md ← LOC limits, refactor recipes
docs/PATTERNS.md                       ← quick-ref code templates
```

## DI & Wiring

```
lib/core/di/service_locator.dart       ← composition root (all lazy getters)
lib/core/base/base_view_model.dart     ← BaseViewModel (extends CmChangeNotifier)
lib/core/base/view_model_provider.dart ← ViewModelProvider<T> widget
lib/provider_scope.dart                ← app-wide providers (Theme, InAppUpdate)
lib/core/route/app_router.dart         ← all GoRoute definitions
```

## Models (ObjectBox @Entity)

```
lib/models/note.dart                   ← Note (main entity, syncId, tags, source)
lib/models/folder.dart                 ← Folder
lib/models/custom_tag.dart             ← CustomTag + CustomTags static helper
lib/models/note_embedding.dart         ← NoteEmbedding (vector chunks)
lib/models/chat_thread.dart            ← ChatThread
lib/models/chat_message.dart           ← ChatMessageEntity + ChatMessage (UI)
lib/models/mood_tag.dart               ← MoodTag (predefined, not @Entity)
lib/models/activity_tag.dart           ← ActivityTag (predefined)
lib/models/time_tag.dart               ← TimeTag (predefined)
lib/models/personal_growth_tag.dart    ← PersonalGrowthTag (predefined)
lib/models/retrieved_document.dart     ← RetrievedDocument (RAG result)
lib/models/note_analytics.dart         ← NoteAnalytics
```

## Repository Interfaces

```
lib/core/repository/interfaces/
├── note_repository.dart               ← INoteRepository
├── folder_repository.dart             ← IFolderRepository
├── custom_tag_repository.dart         ← ICustomTagRepository
├── embedding_repository.dart          ← IEmbeddingRepository
├── chat_thread_repository.dart        ← IChatThreadRepository
└── chat_message_repository.dart       ← IChatMessageRepository
```

## Repository Implementations

```
lib/core/repository/implementations/
├── objectbox_note_repository.dart
├── objectbox_folder_repository.dart
├── objectbox_custom_tag_repository.dart
├── objectbox_embedding_repository.dart
├── objectbox_chat_thread_repository.dart
└── objectbox_chat_message_repository.dart

lib/core/repository/base/
├── base_repository.dart               ← listener management
└── objectbox_store_manager.dart       ← singleton Store
```

## Services

```
lib/core/services/notes/
├── note_service.dart                  ← orchestrator (CRUD, import, export, merge)
├── note_factory.dart                  ← note creation logic
├── note_trash_operations.dart         ← soft-delete / restore / purge
├── note_drive_trash_sync.dart         ← Drive-aware trash ops
├── note_import_from_adapter.dart      ← adapter-based import pipeline
├── note_import_from_json.dart         ← JSON-based import (Trovara + Storypad)
├── note_merge_engine.dart             ← conflict-free merge (local ↔ remote)
├── note_sync_id.dart                  ← deterministic UUID v5 generation
├── note_tombstone_registry.dart       ← permanent-delete tracking
├── custom_tag_service.dart            ← tag CRUD + static collection sync
├── text_parser_service.dart           ← Quill JSON → plain text
└── _storypad/
    ├── storypad_converter.dart        ← Storypad backup → Trovara schema
    └── storypad_value_parsers.dart    ← lenient type coercion

lib/core/services/ai/
├── rag_service.dart                   ← RAG orchestrator (query + queryStream)
├── embedding_service.dart             ← text → vector embeddings
├── vector_search_service.dart         ← cosine similarity brute-force search
├── document_resolver_service.dart     ← chunks → hydrated documents
├── prompt_builder_service.dart        ← token-budget-aware prompt assembly
├── llm_client.dart                    ← provider-agnostic LLM (Gemini/OpenAI/OpenRouter)
├── query_rewrite_service.dart         ← query optimization for retrieval
├── multi_query_expansion_service.dart ← 1 → N query variants
├── rag_chat_memory.dart               ← bounded prior-turn management
└── rrf_key_score.dart                 ← Reciprocal Rank Fusion data class

lib/core/services/auth/
├── google_drive_service.dart          ← Google Sign-In + Drive AppData API
└── linux_google_account.dart          ← Linux OAuth2 compat wrapper

lib/core/services/sync/
└── google_drive_sync_service.dart     ← full sync flow (download → merge → upload)

lib/core/services/chat/
├── chat_service.dart                  ← thread + message CRUD, export/import
└── chat_drive_sync_service.dart       ← chat history sync with Drive

lib/core/services/app/
├── app_icon_service.dart              ← dynamic app icon (iOS only)
└── mock_data_service.dart             ← dev-only note seeding
```

## Import / Export

```
lib/core/import/
├── import_adapter.dart                ← NoteImportAdapter interface + ImportedNote + ImportResult
├── adapters/
│   ├── obsidian_adapter.dart          ← Obsidian vault .md files
│   ├── notion_adapter.dart            ← Notion export .md files
│   └── storypad_adapter.dart          ← Storypad JSON backup
└── converters/
    ├── markdown_to_quill.dart         ← Markdown → Quill Delta JSON
    └── quill_to_markdown.dart         ← Quill Delta JSON → Markdown

lib/core/export/exporters/
└── markdown_exporter.dart             ← Note → Obsidian-compatible .md
```

## Views

```
lib/views/
├── main/          ← tab bar shell (Notes, Chat, Insights, Settings)
├── notes/         ← note list + note editor
│   ├── note/      ← single note editor (Quill)
│   └── widgets/   ← NoteCard
├── chat/          ← RAG chat UI
│   └── widgets/   ← ChatBubble, ChatDrawer, ChatInputField, etc.
├── search/        ← full-screen search + tag filter
├── insights/      ← analytics (heatmap, sentiment, tag frequency)
│   └── widgets/   ← chart components
├── setting/       ← settings (account, theme, sync, import/export)
└── trash/         ← recently deleted notes
```

## Shared Widgets

```
lib/widgets/
├── nm_toast.dart                      ← toast notifications
├── nm_loading_overlay.dart            ← loading overlays
├── nm_refresh_indicator.dart          ← pull-to-refresh
├── quill_divider_embed_builder.dart   ← horizontal rule embed
├── tages/                             ← tag chip widgets (mood, activity, time, growth, custom)
│   └── unified_tags_icon_button.dart  ← combined tag picker dialog
└── util_widgets/
    └── connectivity_status.dart       ← network status toasts
```

## Config & Constants

```
lib/constants/
├── config_constants.dart              ← dart-define keys (API keys, app name)
├── app_constants.dart                 ← locales, utility
├── app_color.dart                     ← status colors (error, success, etc.)
├── date_format.dart                   ← relative date formatting
└── device_constants.dart              ← screen dimensions

lib/core/theme/
├── theme_config.dart                  ← Material 3 theme (light/dark from brand color)
└── typo_graphy.dart                   ← Garet font family weights
```

## Entry Points

```
lib/main.dart                          ← default (no Firebase)
lib/main_staging.dart                  ← staging flavor
lib/main_prod.dart                     ← production flavor
lib/initializer.dart                   ← startup sequence
lib/app.dart                           ← MaterialApp.router
lib/app_scope.dart                     ← EasyLocalization + ProviderScope wrapper
```

## Scripts

```
scripts/
├── run_app.sh                         ← flutter run with dart-defines
├── build_runner.sh                    ← build_runner for ObjectBox codegen
├── build_apk.sh                       ← Android APK build
├── create_firebase_stub.sh            ← stub for CI builds
└── install_hooks.sh                   ← git hooks setup
```

## Tests

```
patrol_test/
├── core/services/                     ← service logic tests
├── core/import/                       ← adapter round-trip tests
└── test_support.dart                  ← shared fixtures + patrolTest wrapper
```
