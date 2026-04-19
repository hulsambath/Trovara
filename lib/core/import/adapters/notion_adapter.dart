import 'package:trovara/core/import/import_adapter.dart';
import 'package:intl/intl.dart';

/// Imports notes from a Notion Markdown export.
///
/// ## How Notion exports work
/// When you export a Notion workspace as "Markdown & CSV":
/// - Each page becomes a `.md` file
/// - Filenames contain a trailing UUID: `"Meeting Notes abc123def456abc123def456abc1.md"`
/// - Database pages export as individual `.md` files alongside a `.csv` index
/// - Nested pages are in sub-folders
///
/// ## Accepted input format
/// Same as [ObsidianAdapter]: a `List<Map<String,dynamic>>` where each map has
/// `{ "path": "...", "content": "..." }`.
///
/// ## What this adapter does
/// 1. Strips Notion's trailing UUID from filenames to recover the clean title
/// 2. Parses Notion's property block at the top of each file
///    (e.g. `**Tags:** productivity, ai`)
/// 3. Extracts `@mention` links → [ImportedNote.internalLinks]
/// 4. Strips auto-generated Notion metadata lines
/// 5. Maps sub-folder structure → Trovara folder IDs
class NotionAdapter implements NoteImportAdapter {
  /// Keys allowed for Notion's `**Key:** value` (colon inside bold) export shape.
  /// Other `**Phrase:**` lines are treated as normal content (e.g. intro headings).
  static const Set<String> _notionInnerColonPropertyKeys = {
    'tags',
    'tag',
    'labels',
    'created',
    'created time',
    'date created',
    'last edited',
    'last edited time',
    'updated',
    'modified',
    'status',
    'type',
    'name',
    'title',
    'date',
    'author',
    'icon',
    'url',
    'related to',
    'owner',
    'assign',
    'assignee',
    'priority',
    'due',
    'due date',
    'category',
    'area',
    'project',
  };

  @override
  String get sourceName => 'notion';

  @override
  bool canHandle(dynamic rawInput) {
    if (rawInput is! List || rawInput.isEmpty) return false;
    final first = rawInput.first;
    if (first is! Map) return false;
    final content = first['content'] as String? ?? '';
    // Notion pages often start with a property table or a UUID-suffixed name in the path
    return content.isNotEmpty || _hasNotionUuidPath(first['path'] as String? ?? '');
  }

  @override
  Future<List<ImportedNote>> parse(dynamic rawInput) async {
    if (rawInput is! List) return [];

    final notes = <ImportedNote>[];
    for (final file in rawInput) {
      if (file is! Map) continue;
      final path = file['path'] as String? ?? '';
      final rawText = file['content'] as String? ?? '';
      // Skip CSV files — they are database indexes, not individual notes
      if (path.toLowerCase().endsWith('.csv')) continue;
      if (rawText.trim().isEmpty) continue;

      try {
        notes.add(_parseFile(path: path, rawText: rawText));
      } catch (_) {
        // Skip malformed entries
      }
    }
    return notes;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  ImportedNote _parseFile({required String path, required String rawText}) {
    final text = rawText.replaceAll('\r\n', '\n');

    // ── Title from filename (Notion embeds UUID in filename) ───────────────
    String title = _titleFromNotionFilename(path);

    // ── Notion property block ──────────────────────────────────────────────
    // Notion exports properties as bold-key: value lines at the top.
    // E.g.:  **Created:** March 19, 2026 3:02 PM
    //        **Tags:** productivity, ai
    final propertyLines = <String, String>{};
    final bodyLines = text.split('\n');
    int bodyStart = 0;

    // Always prefer the H1 heading over the UUID-stripped filename.
    // Notion files always start with an H1 that is the canonical page title.
    if (bodyLines.isNotEmpty && bodyLines[0].startsWith('# ')) {
      final h1Title = bodyLines[0].substring(2).trim();
      if (h1Title.isNotEmpty) title = h1Title;
      bodyStart = 1;
    }

    // Collect consecutive Notion property lines (bold key: value)
    while (bodyStart < bodyLines.length) {
      final line = bodyLines[bodyStart].trim();

      // Prefer explicit separator: colon AFTER closing `**` → `**Key**: value`
      final outerColon = RegExp(r'^\*\*([^*]+)\*\*:\s*(.*)$').firstMatch(line);
      // Notion export shape `**Key:** value` (colon before closing bold) — only for known keys
      // so lines like `**Introduction:** This chapter…` stay in the body.
      final innerColon = RegExp(r'^\*\*([^*]+):\*\*\s*(.*)$').firstMatch(line);

      RegExpMatch? propMatch;
      if (outerColon != null) {
        propMatch = outerColon;
      } else if (innerColon != null) {
        final rawKeyInner = (innerColon.group(1) ?? '').trim();
        final keyNorm = rawKeyInner.replaceAll(RegExp(r':\s*$'), '').trim().toLowerCase();
        if (_notionInnerColonPropertyKeys.contains(keyNorm)) {
          propMatch = innerColon;
        }
      }

      if (propMatch != null) {
        final rawKey = (propMatch.group(1) ?? '').trim();
        final key = rawKey.replaceAll(RegExp(r':\s*$'), '').trim().toLowerCase();
        final value = propMatch.group(2) ?? '';
        propertyLines[key] = value.trim();
        bodyStart++;
      } else if (line.isEmpty && bodyStart < bodyLines.length - 1) {
        // Allow one blank separator line after properties
        bodyStart++;
        break;
      } else {
        break;
      }
    }

    final body = bodyLines.sublist(bodyStart).join('\n').trim();

    // ── Tags from Notion properties ────────────────────────────────────────
    final tags = <String>[];
    final rawTags = propertyLines['tags'] ?? propertyLines['tag'] ?? propertyLines['labels'] ?? '';
    if (rawTags.isNotEmpty) {
      tags.addAll(rawTags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty));
    }

    // ── Dates ──────────────────────────────────────────────────────────────
    final createdAt = _parseDate(
      propertyLines['created'] ?? propertyLines['created time'] ?? propertyLines['date created'],
    );
    final updatedAt = _parseDate(
      propertyLines['last edited'] ??
          propertyLines['last edited time'] ??
          propertyLines['updated'] ??
          propertyLines['modified'],
    );

    // ── Internal links (Notion @mentions become plain text or links) ───────
    final internalLinks = RegExp(
      r'@\[([^\]]+)\]|\[\[([^\]]+)\]\]',
    ).allMatches(body).map((m) => (m.group(1) ?? m.group(2) ?? '').trim()).where((s) => s.isNotEmpty).toSet().toList();

    // ── Folder mapping ─────────────────────────────────────────────────────
    final folderId = _folderIdFromPath(path);

    return ImportedNote(
      title: title.isEmpty ? 'Imported note' : title,
      markdownContent: _cleanNotionBody(body),
      createdAt: createdAt,
      updatedAt: updatedAt,
      tags: tags,
      internalLinks: internalLinks,
      folderId: folderId,
      rawMetadata: propertyLines,
    );
  }

  /// Remove Notion UUIDs from filenames and recover the clean title.
  ///
  /// `"Meeting Notes abc123def456abc123def456abc1.md"` → `"Meeting Notes"`
  String _titleFromNotionFilename(String path) {
    final name = path.split(RegExp(r'[/\\]')).last;
    final withoutExt = name.endsWith('.md') ? name.substring(0, name.length - 3) : name;
    // Notion UUIDs: 32 hex characters, possibly preceded by a space
    return withoutExt.replaceAll(RegExp(r'\s+[0-9a-fA-F]{32}$'), '').trim();
  }

  bool _hasNotionUuidPath(String path) => RegExp(r'[0-9a-fA-F]{32}').hasMatch(path);

  /// Apply Notion-specific body cleanup:
  /// - Remove redundant `<aside>` blocks (Notion callouts exported as HTML)
  /// - Normalise Notion toggle syntax `> Toggle: content` → standard blockquote
  String _cleanNotionBody(String body) {
    // Strip raw HTML tags that Notion sometimes includes
    var clean = body.replaceAll(RegExp(r'<[^>]+>'), '');
    // Collapse triple+ blank lines
    clean = clean.replaceAll(RegExp(r'\n{4,}'), '\n\n\n');
    return clean.trim();
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    // Notion dates can be: "March 19, 2026 3:02 PM" or ISO "2026-03-19"
    return DateTime.tryParse(value) ?? _parseNotionHumanDate(value);
  }

  /// Best-effort parser for Notion's human-readable date format.
  DateTime? _parseNotionHumanDate(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;

    // Notion commonly exports:
    // - "March 19, 2026 3:02 PM"
    // - "March 19, 2026"
    // Use a real format parser (instead of trying to coerce into ISO-8601).
    const patterns = <String>['MMMM d, y h:mm a', 'MMMM d, y', 'MMM d, y h:mm a', 'MMM d, y'];

    for (final p in patterns) {
      try {
        return DateFormat(p, 'en_US').parseLoose(raw);
      } catch (_) {
        // try next pattern
      }
    }

    return null;
  }

  String? _folderIdFromPath(String path) {
    final parts = path.split(RegExp(r'[/\\]'));
    if (parts.length <= 1) return null;
    final dirs = parts.sublist(0, parts.length - 1);
    final slug = dirs
        .map((d) {
          // Strip Notion UUIDs from directory names too
          final cleaned = d.replaceAll(RegExp(r'\s+[0-9a-fA-F]{32}$'), '').trim();
          return cleaned.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
        })
        .where((s) => s.isNotEmpty)
        .join('_');
    return slug.isEmpty ? null : 'notion_$slug';
  }
}
