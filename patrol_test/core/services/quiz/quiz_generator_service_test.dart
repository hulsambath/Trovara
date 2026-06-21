import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/quiz/quiz_generator_service.dart';
import 'package:trovara/core/services/ai/rag_service.dart';
import 'package:trovara/core/services/ai/retrieval_depth.dart';
import 'package:trovara/core/services/ai/rag_chat_memory.dart';
import 'package:trovara/core/services/ai/llm_client.dart';
import 'package:trovara/models/quiz.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  Stubs
// ═══════════════════════════════════════════════════════════════════════════

class StubRagService implements RagService {
  String? nextAnswer;
  List<String> nextSourceTitles = [];

  @override
  Future<RagResult> query(String userQuestion,
      {List<RagChatTurn> priorTurns = const [],
      int searchTopK = RagService.defaultSearchTopK,
      double minScore = RagService.defaultMinScore,
      int maxNotes = RagService.defaultMaxNotes,
      RetrievalDepth depth = RetrievalDepth.free}) async {
    return RagResult(
      answer: nextAnswer ?? 'Test context',
      sourceNoteTitles: nextSourceTitles,
      prompt: 'Debug prompt',
      matchedChunks: 2,
    );
  }

  @override
  Stream<String> queryStream(String userQuestion,
      {List<RagChatTurn> priorTurns = const [],
      int searchTopK = RagService.defaultSearchTopK,
      double minScore = RagService.defaultMinScore,
      int maxNotes = RagService.defaultMaxNotes,
      RetrievalDepth depth = RetrievalDepth.free}) async* {
    yield nextAnswer ?? 'Test context';
  }

  @override
  bool get isAvailable => true;

  @override
  Future<List<String>> getSourceTitles(
    String userQuestion, {
    List<RagChatTurn> priorTurns = const [],
    int searchTopK = RagService.defaultSearchTopK,
    double minScore = RagService.defaultMinScore,
    int maxNotes = RagService.defaultMaxNotes,
  }) async => nextSourceTitles;

  @override
  // ignore: empty_catches
  noSuchMethod(Invocation invocation) {}
}

class StubLlmClient implements LlmClient {
  String? nextResponse;

  @override
  Future<String> generate(String prompt) async {
    return nextResponse ?? '[]';
  }

  @override
  Stream<String> generateStream(String prompt) async* {
    yield nextResponse ?? '[]';
  }

  @override
  Future<String> generateWithMessages(
      {required String systemPrompt,
      required List<LlmChatMessage> history,
      required String userMessage}) async {
    return nextResponse ?? '[]';
  }

  @override
  Stream<String> generateStreamWithMessages(
      {required String systemPrompt,
      required List<LlmChatMessage> history,
      required String userMessage}) async* {
    yield nextResponse ?? '[]';
  }

  @override
  Future<void> initialize() async {}

  @override
  // ignore: empty_catches
  noSuchMethod(Invocation invocation) {}
}

void main() {
  group('QuizGeneratorService', () {
    late QuizGeneratorService service;
    late StubRagService ragService;
    late StubLlmClient llmClient;

    setUp(() {
      ragService = StubRagService();
      llmClient = StubLlmClient();
      service = QuizGeneratorService(
        ragService: ragService,
        llmClient: llmClient,
      );
    });

    test('generates quiz questions from selected notes', () async {
      // Setup stubs
      ragService.nextAnswer = 'Context about learning and understanding';
      ragService.nextSourceTitles = ['Note 1', 'Note 2'];

      llmClient.nextResponse = '''[
        {"question": "What is learning?", "options": ["A process", "B process", "C process", "D process"], "correctIndex": 0, "difficulty": "easy", "explanation": "Learning is a process"},
        {"question": "Why learn?", "options": ["A reason", "B reason", "C reason", "D reason"], "correctIndex": 1, "difficulty": "medium", "explanation": "To improve"},
        {"question": "How to apply?", "options": ["A way", "B way", "C way", "D way"], "correctIndex": 2, "difficulty": "hard", "explanation": "Through practice"}
      ]''';

      final questions = await service.generateQuiz(
        noteIds: [1, 2, 3],
        questionCount: 3,
      );

      expect(questions, hasLength(3));
      expect(questions.every((q) => q.options.length == 4), true);
      expect(questions.every((q) => q.isValid), true);
    });

    test('varies question difficulty across quiz', () async {
      ragService.nextAnswer = 'Test content';
      ragService.nextSourceTitles = ['Note 1'];

      llmClient.nextResponse = '''[
        {"question": "Q1", "options": ["A", "B", "C", "D"], "correctIndex": 0, "difficulty": "easy"},
        {"question": "Q2", "options": ["A", "B", "C", "D"], "correctIndex": 1, "difficulty": "medium"},
        {"question": "Q3", "options": ["A", "B", "C", "D"], "correctIndex": 2, "difficulty": "hard"}
      ]''';

      final questions = await service.generateQuiz(
        noteIds: [1],
        questionCount: 3,
      );

      final difficulties = questions.map((q) => q.difficulty).toSet();
      expect(difficulties, contains('easy'));
      expect(difficulties, contains('medium'));
      expect(difficulties, contains('hard'));
    });

    test('links questions to source note IDs', () async {
      ragService.nextAnswer = 'Test content';
      ragService.nextSourceTitles = ['Note 1'];

      llmClient.nextResponse = '''[
        {"question": "Q", "options": ["A", "B", "C", "D"], "correctIndex": 0, "difficulty": "easy"}
      ]''';

      final questions = await service.generateQuiz(
        noteIds: [1, 2, 3],
        questionCount: 1,
      );

      expect(questions.isNotEmpty, true);
      expect(questions.first.sourceNoteIds, [1, 2, 3]);
    });

    test('handles RAG service failures gracefully', () async {
      ragService.nextAnswer = '';
      ragService.nextSourceTitles = [];

      final questions = await service.generateQuiz(
        noteIds: [1],
        questionCount: 3,
      );

      expect(questions, isEmpty);
    });

    test('handles malformed LLM response gracefully', () async {
      ragService.nextAnswer = 'Test content';
      ragService.nextSourceTitles = ['Note 1'];
      llmClient.nextResponse = 'This is not valid JSON at all';

      final questions = await service.generateQuiz(
        noteIds: [1],
        questionCount: 3,
      );

      expect(questions, isEmpty);
    });

    test('parses questions with markdown code blocks in response', () async {
      ragService.nextAnswer = 'Test content';
      ragService.nextSourceTitles = ['Note 1'];

      llmClient.nextResponse = '''```json
[
  {"question": "Q1", "options": ["A", "B", "C", "D"], "correctIndex": 0, "difficulty": "easy"}
]
```''';

      final questions = await service.generateQuiz(
        noteIds: [1],
        questionCount: 1,
      );

      expect(questions, hasLength(1));
      expect(questions.first.question, 'Q1');
    });

    test('getDifficultyDistribution counts questions by difficulty', () {
      final questions = [
        QuizQuestion(
          question: 'Q1',
          options: ['A', 'B', 'C', 'D'],
          correctIndex: 0,
          difficulty: 'easy',
          sourceNoteIds: [1],
        ),
        QuizQuestion(
          question: 'Q2',
          options: ['A', 'B', 'C', 'D'],
          correctIndex: 1,
          difficulty: 'medium',
          sourceNoteIds: [1],
        ),
        QuizQuestion(
          question: 'Q3',
          options: ['A', 'B', 'C', 'D'],
          correctIndex: 2,
          difficulty: 'easy',
          sourceNoteIds: [1],
        ),
      ];

      final dist = service.getDifficultyDistribution(questions);

      expect(dist['easy'], 2);
      expect(dist['medium'], 1);
      expect(dist['hard'], 0);
    });
  });
}
