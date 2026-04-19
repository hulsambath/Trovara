import 'package:trovara/core/import/import_adapter.dart';

/// Imports notes from an Obsidian vault export.
///
/// ## Accepted input formats
///
/// The adapter accepts two raw-input shapes:
///
/// 1. **`List<Map<String,dynamic>>`** — a pre-parsed list of file descriptors.
///    Each map has:
///    ```json
///    { "path": "Notes/My Note.md", "content": "# My Note\n..." }
///    ```
///    This is the shape produced by the UI file-picker after reading each `.md`
///    file from a selected folder or zip.
///
/// 2. **`String`** — a single `.md` file's raw text content (useful for
///    single-file imports and unit tests).
///
/// ## Obsidian-specific features preserved
/// - YAML frontmatter (`---` / `---`) parsed for title, tags, dates
/// - `[[wikilinks]]` extracted → [ImportedNote.internalLinks]
/// - `#inline-tags` extracted and merged with frontmatter tags
/// - Folder path used to create [ImportedNote.folderId]
class ObsidianAdapter implements NoteImportAdapter {
  @override
  String get sourceName => 'obsidian';

  @override
  bool canHandle(dynamic rawInput) {
    if (rawInput is String) return true;
    if (rawInput is List) {
      if (rawInput.isEmpty) return false;
      final first = rawInput.first;
      return first is Map && (first.containsKey('content') || first.containsKey('path'));
    }
    return false;
  }

  @override
  Future<List<ImportedNote>> parse(dynamic rawInput) async {
    final files = _normalise(rawInput);
    final notes = <ImportedNote>[];

    for (final file in files) {
      final path = file['path'] as String? ?? '';
      final rawText = file['content'] as String? ?? '';
      if (rawText.trim().isEmpty) continue;

      try {
        notes.add(_parseFile(path: path, rawText: rawText));
      } catch (_) {
        // Skip malformed files silently
      }
    }

    return notes;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Normalise raw input into `[{path, content}]` maps.
  List<Map<String, dynamic>> _normalise(dynamic rawInput) {
    if (rawInput is String) {
      return [
        {'path': 'note.md', 'content': rawInput},
      ];
    }
    if (rawInput is List) {
      return rawInput.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    }
    return [];
  }

  ImportedNote _parseFile({required String path, required String rawText}) {
    final text = rawText.replaceAll('\r\n', '\n');

    // ── Frontmatter extraction ─────────────────────────────────────────────
    Map<String, dynamic> frontmatter = {};
    String body = text;

    final frontmatterMatch = RegExp(r'^---\n([\s\S]*?)\n---(?:\n|$)').firstMatch(text);
    if (frontmatterMatch != null) {
      final yamlBlock = frontmatterMatch.group(1) ?? '';
      frontmatter = _parseFrontmatter(yamlBlock);
      body = text.substring(frontmatterMatch.end);
    }

    // ── Title resolution ───────────────────────────────────────────────────
    // Priority: frontmatter `title` > first `# Heading` > filename (without ext)
    String title = _stringify(frontmatter['title']);
    if (title.isEmpty) {
      final h1 = RegExp(r'^# (.+)$', multiLine: true).firstMatch(body);
      if (h1 != null) {
        title = h1.group(1)!.trim();
        // Remove the h1 from body since it becomes the title
        body = body.replaceFirst(h1.group(0)!, '').trimLeft();
      }
    }
    if (title.isEmpty) {
      title = _filenameWithoutExtension(path);
    }

    // ── Dates ──────────────────────────────────────────────────────────────
    final createdAt = _parseDate(frontmatter['created'] ?? frontmatter['date'] ?? frontmatter['created_at']);
    final updatedAt = _parseDate(frontmatter['updated'] ?? frontmatter['modified'] ?? frontmatter['updated_at']);

    // ── Tags ───────────────────────────────────────────────────────────────
    final tags = <String>{};

    // Frontmatter tags (list or space-separated string)
    final rawTags = frontmatter['tags'];
    if (rawTags is List) {
      tags.addAll(rawTags.map((t) => t.toString().replaceAll('#', '').trim()));
    } else if (rawTags is String && rawTags.isNotEmpty) {
      tags.addAll(rawTags.split(RegExp(r'[\s,]+')).map((t) => t.replaceAll('#', '').trim()).where((t) => t.isNotEmpty));
    }

    // Inline #tags from body
    for (final match in RegExp(r'(?<!\[)#([A-Za-z0-9_/-]+)').allMatches(body)) {
      tags.add(match.group(1)!);
    }

    // ── Internal links [[wikilinks]] ───────────────────────────────────────
    final internalLinks = RegExp(
      r'\[\[([^\]|]+)(?:\|[^\]]*)?\]\]',
    ).allMatches(body).map((m) => m.group(1)!.trim()).toSet().toList();

    // ── Folder mapping ─────────────────────────────────────────────────────
    final folderId = _folderIdFromPath(path);

    return ImportedNote(
      title: title,
      markdownContent: body.trim(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      tags: tags.toList(),
      internalLinks: internalLinks,
      folderId: folderId,
      rawMetadata: Map<String, dynamic>.from(frontmatter),
    );
  }

  /// Basic line-by-line YAML frontmatter parser.
  ///
  /// Handles:
  /// - `key: value` (string)
  /// - `key: [val1, val2]` (inline list)
  /// - Multi-line list:
  ///   ```yaml
  ///   tags:
  ///     - foo
  ///     - bar
  ///   ```
  Map<String, dynamic> _parseFrontmatter(String yaml) {
    final result = <String, dynamic>{};
    String? currentKey;
    final listAccumulator = <String>[];

    void flushList() {
      if (currentKey != null && listAccumulator.isNotEmpty) {
        result[currentKey!] = List<String>.from(listAccumulator);
        listAccumulator.clear();
        currentKey = null;
      }
    }

    for (final line in yaml.split('\n')) {
      // List item under a key
      if (line.startsWith('  - ') || line.startsWith('- ')) {
        listAccumulator.add(line.replaceFirst(RegExp(r'^\s*-\s*'), '').trim());
        continue;
      }

      // New key: value pair
      final kv = RegExp(r'^([A-Za-z0-9_-]+):\s*(.*)$').firstMatch(line);
      if (kv != null) {
        flushList();
        final key = kv.group(1)!;
        final value = kv.group(2)!.trim();

        if (value.isEmpty) {
          // Multiline list follows
          currentKey = key;
        } else if (value.startsWith('[') && value.endsWith(']')) {
          // Inline list: [a, b, c]
          final inner = value.substring(1, value.length - 1);
          result[key] = inner.split(',').map((s) => s.trim().replaceAll(RegExp('["\']'), '')).toList();
        } else {
          result[key] = value.replaceAll(RegExp('["\']'), '');
        }
        continue;
      }

      flushList();
    }
    flushList();
    return result;
  }

  String _stringify(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString().trim());
  }

  String _filenameWithoutExtension(String path) {
    final name = path.split(RegExp(r'[/\\]')).last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  /// Map a vault file path to a stable Trovara folder ID.
  ///
  /// `"Notes/Work/meeting.md"` → `"obsidian_notes_work"`
  String? _folderIdFromPath(String path) {
    final parts = path.split(RegExp(r'[/\\]'));
    if (parts.length <= 1) return null; // root-level → use default
    final dirs = parts.sublist(0, parts.length - 1);
    final slug = dirs.map((d) => d.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')).join('_');
    return 'obsidian_$slug';
  }
}
