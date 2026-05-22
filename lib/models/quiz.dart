/// Data models for quiz generation and tracking
class QuizQuestion {
  /// The text of the question
  final String question;

  /// 4 multiple choice options
  final List<String> options;

  /// Index of the correct answer (0-3)
  final int correctIndex;

  /// Difficulty level: 'easy', 'medium', or 'hard'
  final String difficulty;

  /// IDs of source notes that this question was generated from
  final List<int> sourceNoteIds;

  /// Optional explanation for the correct answer
  final String? explanation;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.difficulty,
    required this.sourceNoteIds,
    this.explanation,
  });

  /// Validate that options list has exactly 4 items
  bool get isValid => options.length == 4 && correctIndex >= 0 && correctIndex < 4;
}

/// A quiz session with questions and user answers
class QuizSession {
  /// List of quiz questions in this session
  final List<QuizQuestion> questions;

  /// User's selected answer index for each question (null if skipped)
  final List<int?> userAnswers;

  /// When this quiz session was created
  final DateTime createdAt;

  QuizSession({
    required this.questions,
    required this.userAnswers,
    required this.createdAt,
  });

  /// Calculate the score (number of correct answers)
  int get score {
    int correct = 0;
    for (int i = 0; i < questions.length; i++) {
      if (i < userAnswers.length && userAnswers[i] == questions[i].correctIndex) {
        correct++;
      }
    }
    return correct;
  }

  /// Total number of questions
  int get total => questions.length;

  /// Calculate percentage score
  double get percentageScore => total > 0 ? (score / total) * 100 : 0.0;
}
