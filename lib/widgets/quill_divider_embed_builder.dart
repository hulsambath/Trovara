import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Horizontal rule embed (`divider`) from imported Quill JSON (e.g. Storypad, markdown `---`).
class QuillDividerEmbedBuilder extends EmbedBuilder {
  const QuillDividerEmbedBuilder();

  @override
  String get key => 'divider';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Divider(height: 1, thickness: 1, color: Theme.of(context).colorScheme.outlineVariant),
  );
}
