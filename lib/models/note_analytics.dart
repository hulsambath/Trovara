class NoteAnalytics {
  final DateTime date;
  final int entryCount;
  final int wordCount;
  final double sentimentScore;
  final Map<String, int> tagFrequency;

  NoteAnalytics({
    required this.date,
    required this.entryCount,
    required this.wordCount,
    required this.sentimentScore,
    required this.tagFrequency,
  });

  factory NoteAnalytics.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rawTagFrequency = (json['tagFrequency'] as Map?)?.cast<String, dynamic>() ?? const {};

    final Map<String, int> parsedTagFrequency = rawTagFrequency.map(
      (key, value) => MapEntry(key, (value as num).toInt()),
    );

    return NoteAnalytics(
      date: DateTime.parse(json['date'] as String),
      entryCount: (json['entryCount'] as num).toInt(),
      wordCount: (json['wordCount'] as num).toInt(),
      sentimentScore: (json['sentimentScore'] as num).toDouble(),
      tagFrequency: parsedTagFrequency,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'entryCount': entryCount,
    'wordCount': wordCount,
    'sentimentScore': sentimentScore,
    'tagFrequency': tagFrequency,
  };
}
