import 'dart:convert';

/// Service for parsing Quill document content
/// Follows Single Responsibility Principle - only handles text parsing
class TextParserService {
  /// Parse Quill JSON content and extract plain text
  static String parseQuillContent(String content) {
    try {
      final dynamic jsonData = jsonDecode(content);
      List<dynamic> ops = [];

      // Handle different JSON structures
      if (jsonData is Map<String, dynamic>) {
        // Standard Quill format: {"ops": [...]}
        ops = jsonData['ops'] as List<dynamic>? ?? [];
      } else if (jsonData is List<dynamic>) {
        // Direct list format: [...]
        ops = jsonData;
      }

      // Extract only the "insert" values
      final StringBuffer plainText = StringBuffer();
      for (final op in ops) {
        if (op is Map<String, dynamic> && op.containsKey('insert')) {
          final insert = op['insert'];
          if (insert is String) {
            // Keep structural separation for line breaks so words from adjacent
            // lines don't get merged (important for search + word count).
            if (insert == '\n') {
              plainText.write(' ');
            } else {
              plainText.write(insert);
            }
          }
        }
      }

      final result = plainText.toString().trim();
      // Remove multiple spaces and clean up the text
      final cleanedResult = result.replaceAll(RegExp(r'\s+'), ' ').trim();

      return cleanedResult;
    } catch (e) {
      // Fallback to the old method if JSON parsing fails
      final plainText = content.replaceAll(RegExp(r'<[^>]*>'), '');
      return plainText.trim();
    }
  }

  /// Get preview text with length limit
  static String getPreviewText(String content, {int maxLength = 150}) {
    final plainText = parseQuillContent(content);
    return plainText.length > maxLength ? '${plainText.substring(0, maxLength)}...' : plainText;
  }

  /// Calculate word count from Quill content
  static int calculateWordCount(String content) {
    final plainText = parseQuillContent(content);
    return plainText.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
  }

  /// Calculate character count from Quill content
  static int calculateCharacterCount(String content) => parseQuillContent(content).length;
}
