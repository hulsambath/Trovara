import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:trovara/core/services/ai/rag_service.dart';
import 'package:trovara/core/services/ai/llm_client.dart';
import 'package:trovara/models/quiz.dart';

/// Service for generating quiz questions from notes using LLM
class QuizGeneratorService {
  /// RAG service for retrieving context from notes
  final RagService ragService;

  /// LLM client for generating questions
  final LlmClient llmClient;

  static final _logger = Logger();

  QuizGeneratorService({
    required this.ragService,
    required this.llmClient,
  });

  /// Generate quiz questions from selected notes
  ///
  /// Returns a list of [QuizQuestion] objects with varied difficulty levels.
  /// Includes explanations for each question and links back to source notes.
  ///
  /// The generation process:
  /// 1. Use RAG to retrieve context from selected notes
  /// 2. Prompt LLM to generate multiple-choice questions
  /// 3. Parse structured JSON response into QuizQuestion objects
  Future<List<QuizQuestion>> generateQuiz({
    required List<int> noteIds,
    required int questionCount,
  }) async {
    _logger.i('Generating $questionCount quiz questions from ${noteIds.length} notes');

    try {
      // Step 1: Retrieve context from notes using RAG query
      // This uses the full RAG pipeline to get relevant content from notes
      final ragResult = await ragService.query(
        'Key concepts, definitions, and facts for creating assessment questions',
      );

      if (ragResult.answer.isEmpty) {
        _logger.w('RAG returned empty context for quiz generation');
        return [];
      }

      // Step 2: Build prompt and generate questions via LLM
      final prompt = _buildQuizPrompt(ragResult.answer, questionCount);
      final response = await llmClient.generate(prompt);

      // Step 3: Parse LLM response into structured questions
      final questions = _parseQuestionResponse(response, noteIds);

      _logger.i('Generated ${questions.length} quiz questions');
      return questions;
    } catch (e) {
      _logger.e('Failed to generate quiz', error: e);
      return [];
    }
  }

  /// Build the prompt for the LLM to generate quiz questions
  String _buildQuizPrompt(String context, int count) {
    return '''You are an expert test designer. Generate exactly $count multiple-choice quiz questions based on this text:

<context>
$context
</context>

Requirements:
1. Each question must have exactly 4 options (labeled A, B, C, D)
2. Vary difficulty levels evenly: some easy (simple recall), some medium (understanding), some hard (application/synthesis)
3. Include a clear explanation for each question
4. Format the output as a JSON array with exactly these fields for each question:
   - question (string)
   - options (array of exactly 4 strings)
   - correctIndex (number: 0, 1, 2, or 3)
   - difficulty (string: "easy", "medium", or "hard")
   - explanation (string)

Output ONLY the valid JSON array, no markdown formatting, no code blocks.''';
  }

  /// Parse the LLM's JSON response into QuizQuestion objects
  List<QuizQuestion> _parseQuestionResponse(String response, List<int> sourceNoteIds) {
    try {
      // Clean up response (remove markdown code blocks if present)
      String cleaned = response.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      }
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      // Parse JSON array
      final jsonArray = jsonDecode(cleaned) as List;
      final questions = <QuizQuestion>[];

      for (final item in jsonArray) {
        try {
          final q = item as Map<String, dynamic>;
          final question = QuizQuestion(
            question: q['question'] as String,
            options: List<String>.from(q['options'] as List),
            correctIndex: q['correctIndex'] as int,
            difficulty: q['difficulty'] as String,
            sourceNoteIds: sourceNoteIds,
            explanation: q['explanation'] as String?,
          );

          // Validate question before adding
          if (question.isValid) {
            questions.add(question);
          } else {
            _logger.w('Invalid question structure, skipping: ${q['question']}');
          }
        } catch (e) {
          _logger.w('Failed to parse individual question', error: e);
          continue;
        }
      }

      return questions;
    } catch (e) {
      _logger.e('Failed to parse quiz response', error: e);
      return [];
    }
  }

  /// Get difficulty distribution statistics for quiz questions
  Map<String, int> getDifficultyDistribution(List<QuizQuestion> questions) {
    final dist = <String, int>{'easy': 0, 'medium': 0, 'hard': 0};
    for (final q in questions) {
      dist[q.difficulty] = (dist[q.difficulty] ?? 0) + 1;
    }
    return dist;
  }
}
