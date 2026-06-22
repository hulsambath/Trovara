/// Result of a RAG query, containing the answer and source metadata.
class RagResult {
  /// The LLM-generated answer text.
  final String answer;

  /// Titles of notes used as context for the answer.
  /// Useful for source attribution in the chat UI.
  final List<String> sourceNoteTitles;

  /// Debug transcript of the **full message list** sent to the LLM.
  ///
  /// Includes the system prompt, truncated prior turns (history), and the
  /// final user payload built by `PromptBuilderService`.
  ///
  /// Available for debugging/logging only; not displayed to the user.
  final String prompt;

  /// Number of embedding chunks that matched the query.
  final int matchedChunks;

  RagResult({required this.answer, required this.sourceNoteTitles, required this.prompt, required this.matchedChunks});

  @override
  String toString() =>
      'RagResult(sources: ${sourceNoteTitles.length}, '
      'chunks: $matchedChunks, '
      'answer: ${answer.length} chars)';
}
