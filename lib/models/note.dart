import 'package:objectbox/objectbox.dart';
import 'package:trovara/core/services/text_parser_service.dart';
import 'package:trovara/models/activity_tag.dart';
import 'package:trovara/models/custom_tag.dart';
import 'package:trovara/models/mood_tag.dart';
import 'package:trovara/models/personal_growth_tag.dart';
import 'package:trovara/models/time_tag.dart';
import 'package:uuid/uuid.dart';

@Entity()
class Note {
  int id;

  /// Stable, device-independent unique identifier for sync.
  ///
  /// This UUID is assigned once when a note is created and never changes,
  /// even across devices or after the note is re-imported from a backup.
  /// The sync engine uses this instead of the ObjectBox integer [id] to
  /// match notes across devices (similar to a Git object hash).
  @Index()
  String syncId;

  String title;
  String contentJson;
  DateTime createdAt;
  DateTime updatedAt;
  bool isFavorite;
  bool isArchived;

  /// Soft delete flag. When true, the note is in the "Recently Deleted" list.
  bool isDeleted;

  /// Timestamp when the note was soft-deleted.
  /// Used to automatically purge notes after 30 days.
  DateTime? deletedAt;

  /// Google Drive file ID for this note.
  /// Used to sync trash state with Google Drive.
  /// Can be null for notes that haven't been synced to Drive yet.
  String? driveFileId;

  /// Google account `sub` (unique identifier) of the note owner.
  /// Null means the note was created anonymously (not signed in).
  /// Assigned when the user syncs with Google Drive for the first time.
  String? userId;

  String folderId;
  List<int> customTagIds;
  List<String> moodTags;
  List<String> activityTags;
  List<String> timeTags;
  List<String> personalGrowthTags;

  /// The platform this note was originally created or imported from.
  ///
  /// One of: 'trovara' | 'obsidian' | 'notion' | 'storypad' | 'manual'
  /// Defaults to 'trovara' for notes created natively.
  String source;

  /// Internal link targets extracted from Obsidian [[wikilinks]] or
  /// Notion @-mentions during import.
  ///
  /// Each entry is the raw link target string (e.g. `"Meeting Notes"`).
  /// Used to preserve graph relationships for future RAG graph traversal.
  List<String> internalLinks;

  Note({
    this.id = 0,
    String? syncId,
    required this.title,
    required this.contentJson,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isFavorite = false,
    this.isArchived = false,
    this.isDeleted = false,
    this.deletedAt,
    this.driveFileId,
    this.userId,
    this.folderId = 'default',
    List<int>? customTagIds,
    List<String>? moodTags,
    List<String>? activityTags,
    List<String>? timeTags,
    List<String>? personalGrowthTags,
    this.source = 'trovara',
    List<String>? internalLinks,
  }) : syncId = syncId ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now(),
       customTagIds = customTagIds ?? [],
       moodTags = moodTags ?? [],
       activityTags = activityTags ?? [],
       timeTags = timeTags ?? [],
       personalGrowthTags = personalGrowthTags ?? [],
       internalLinks = internalLinks ?? [];

  String get content => TextParserService.parseQuillContent(contentJson);
  int get wordCount => TextParserService.calculateWordCount(contentJson);
  int get characterCount => TextParserService.calculateCharacterCount(contentJson);

  /// Flat list of all tag labels across every tag category.
  /// Used by exporters to produce a unified frontmatter `tags:` list.
  List<String> get allTags => [
    ...moodTags,
    ...activityTags,
    ...timeTags,
    ...personalGrowthTags,
    ...customTagObjects.map((t) => t.name),
  ];

  void toggleFavorite() {
    isFavorite = !isFavorite;
    updatedAt = DateTime.now();
  }

  void toggleArchived() {
    isArchived = !isArchived;
    updatedAt = DateTime.now();
  }

  /// Mark this note as softly deleted.
  ///
  /// The note will appear in the "Recently Deleted" list and can be restored
  /// until it is permanently removed (e.g. after 30 days).
  void softDelete() {
    isDeleted = true;
    deletedAt = DateTime.now();
    updatedAt = DateTime.now();
  }

  /// Restore this note from the "Recently Deleted" list.
  void restoreFromTrash() {
    isDeleted = false;
    deletedAt = null;
    updatedAt = DateTime.now();
  }

  void moveToFolder(String newFolderId) {
    folderId = newFolderId;
    updatedAt = DateTime.now();
  }

  void addCustomTag(int customTagId) {
    if (!customTagIds.contains(customTagId)) {
      customTagIds.add(customTagId);
      updatedAt = DateTime.now();
    }
  }

  void removeCustomTag(int customTagId) {
    if (customTagIds.remove(customTagId)) {
      updatedAt = DateTime.now();
    }
  }

  void setCustomTags(List<int> newCustomTagIds) {
    customTagIds = newCustomTagIds;
    updatedAt = DateTime.now();
  }

  List<CustomTag> get customTagObjects => CustomTags.getByIds(customTagIds);

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

  void addActivityTag(String activityTagId) {
    if (!activityTags.contains(activityTagId) && ActivityTags.exists(activityTagId)) {
      activityTags.add(activityTagId);
      updatedAt = DateTime.now();
    }
  }

  void removeActivityTag(String activityTagId) {
    if (activityTags.remove(activityTagId)) {
      updatedAt = DateTime.now();
    }
  }

  void setActivityTags(List<String> newActivityTags) {
    activityTags = newActivityTags.where((id) => ActivityTags.exists(id)).toList();
    updatedAt = DateTime.now();
  }

  List<ActivityTag> get activityTagObjects => ActivityTags.getByIds(activityTags);

  void addTimeTag(String timeTagId) {
    if (!timeTags.contains(timeTagId) && TimeTags.exists(timeTagId)) {
      timeTags.add(timeTagId);
      updatedAt = DateTime.now();
    }
  }

  void removeTimeTag(String timeTagId) {
    if (timeTags.remove(timeTagId)) {
      updatedAt = DateTime.now();
    }
  }

  void setTimeTags(List<String> newTimeTags) {
    timeTags = newTimeTags.where((id) => TimeTags.exists(id)).toList();
    updatedAt = DateTime.now();
  }

  List<TimeTag> get timeTagObjects => TimeTags.getByIds(timeTags);

  void addPersonalGrowthTag(String personalGrowthTagId) {
    if (!personalGrowthTags.contains(personalGrowthTagId) && PersonalGrowthTags.exists(personalGrowthTagId)) {
      personalGrowthTags.add(personalGrowthTagId);
      updatedAt = DateTime.now();
    }
  }

  void removePersonalGrowthTag(String personalGrowthTagId) {
    if (personalGrowthTags.remove(personalGrowthTagId)) {
      updatedAt = DateTime.now();
    }
  }

  void setPersonalGrowthTags(List<String> newPersonalGrowthTags) {
    personalGrowthTags = newPersonalGrowthTags.where((id) => PersonalGrowthTags.exists(id)).toList();
    updatedAt = DateTime.now();
  }

  List<PersonalGrowthTag> get personalGrowthTagObjects => PersonalGrowthTags.getByIds(personalGrowthTags);

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
    'syncId': syncId,
    'title': title,
    'contentJson': contentJson,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isFavorite': isFavorite,
    'isArchived': isArchived,
    'isDeleted': isDeleted,
    'deletedAt': deletedAt?.toIso8601String(),
    'driveFileId': driveFileId,
    'userId': userId,
    'folderId': folderId,
    'customTagIds': customTagIds,
    'moodTags': moodTags,
    'activityTags': activityTags,
    'timeTags': timeTags,
    'personalGrowthTags': personalGrowthTags,
    'source': source,
    'internalLinks': internalLinks,
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'] as int? ?? 0,
    syncId: json['syncId'] as String?,
    title: json['title'] as String,
    contentJson: json['contentJson'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    isFavorite: json['isFavorite'] as bool? ?? false,
    isArchived: json['isArchived'] as bool? ?? false,
    isDeleted: json['isDeleted'] as bool? ?? false,
    deletedAt: json['deletedAt'] != null && (json['deletedAt'] as String).isNotEmpty
        ? DateTime.tryParse(json['deletedAt'] as String)
        : null,
    driveFileId: json['driveFileId'] as String?,
    userId: json['userId'] as String?,
    folderId: json['folderId'] as String? ?? 'default',
    customTagIds: List<int>.from(json['customTagIds'] as List? ?? []),
    moodTags: List<String>.from(json['moodTags'] as List? ?? []),
    activityTags: List<String>.from(json['activityTags'] as List? ?? []),
    timeTags: List<String>.from(json['timeTags'] as List? ?? []),
    personalGrowthTags: List<String>.from(json['personalGrowthTags'] as List? ?? []),
    source: json['source'] as String? ?? 'trovara',
    internalLinks: List<String>.from(json['internalLinks'] as List? ?? []),
  );

  @override
  String toString() => 'Note(id: $id, title: $title, isFavorite: $isFavorite)';
}
