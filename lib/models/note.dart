import 'package:noteminds/core/services/text_parser_service.dart';
import 'package:noteminds/models/mood_tag.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class Note {
  int id;
  String title;
  String contentJson;
  DateTime createdAt;
  DateTime updatedAt;
  bool isFavorite;
  bool isArchived;
  String folderId;
  List<String> tags;
  List<String> moodTags;

  Note({
    this.id = 0,
    required this.title,
    required this.contentJson,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isFavorite = false,
    this.isArchived = false,
    this.folderId = 'default',
    List<String>? tags,
    List<String>? moodTags,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now(),
       tags = tags ?? [],
       moodTags = moodTags ?? [];

  String get content => TextParserService.parseQuillContent(contentJson);
  int get wordCount => TextParserService.calculateWordCount(contentJson);
  int get characterCount => TextParserService.calculateCharacterCount(contentJson);

  void toggleFavorite() {
    isFavorite = !isFavorite;
    updatedAt = DateTime.now();
  }

  void toggleArchived() {
    isArchived = !isArchived;
    updatedAt = DateTime.now();
  }

  void moveToFolder(String newFolderId) {
    folderId = newFolderId;
    updatedAt = DateTime.now();
  }

  void addTag(String tag) {
    if (!tags.contains(tag)) {
      tags.add(tag);
      updatedAt = DateTime.now();
    }
  }

  void removeTag(String tag) {
    if (tags.remove(tag)) {
      updatedAt = DateTime.now();
    }
  }

  void addMoodTag(String moodTagId) {
    if (!moodTags.contains(moodTagId) && MoodTags.exists(moodTagId)) {
      moodTags.add(moodTagId);
      updatedAt = DateTime.now();
    }
  }

  void removeMoodTag(String moodTagId) {
    if (moodTags.remove(moodTagId)) {
      updatedAt = DateTime.now();
    }
  }

  void setMoodTags(List<String> newMoodTags) {
    moodTags = newMoodTags.where((id) => MoodTags.exists(id)).toList();
    updatedAt = DateTime.now();
  }

  List<MoodTag> get moodTagObjects => MoodTags.getByIds(moodTags);

  void updateContent(String newContentJson) {
    contentJson = newContentJson;
    updatedAt = DateTime.now();
  }

  void updateTitle(String newTitle) {
    title = newTitle;
    updatedAt = DateTime.now();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'contentJson': contentJson,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isFavorite': isFavorite,
    'isArchived': isArchived,
    'folderId': folderId,
    'tags': tags,
    'moodTags': moodTags,
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'] as int? ?? 0,
    title: json['title'] as String,
    contentJson: json['contentJson'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    isFavorite: json['isFavorite'] as bool? ?? false,
    isArchived: json['isArchived'] as bool? ?? false,
    folderId: json['folderId'] as String? ?? 'default',
    tags: List<String>.from(json['tags'] as List? ?? []),
    moodTags: List<String>.from(json['moodTags'] as List? ?? []),
  );

  @override
  String toString() => 'Note(id: $id, title: $title, isFavorite: $isFavorite)';
}
