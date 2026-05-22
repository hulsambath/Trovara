import 'package:objectbox/objectbox.dart';

@Entity()
class Citation {
  @Id()
  int id = 0;

  /// URL or internal note title
  @Index()
  late String source;

  /// Display title
  late String title;

  /// Author name (if known)
  late String? author;

  /// Publication date (ISO string)
  late String? datePublished;

  /// Citation format: APA, MLA, Chicago
  late String format = 'APA';

  /// Whether source is confirmed (internal = always true, external = may be false)
  bool isConfirmed = true;

  /// Timestamp when citation was added
  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  Citation({
    required this.source,
    required this.title,
    this.author,
    this.datePublished,
    this.format = 'APA',
    this.isConfirmed = true,
  });
}
