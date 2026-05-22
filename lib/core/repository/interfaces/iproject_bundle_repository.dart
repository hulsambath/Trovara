import 'package:trovara/models/project_bundle.dart';

abstract class IProjectBundleRepository {
  /// Create new project
  Future<ProjectBundle> createProject({
    required String name,
    String? description,
    List<int> noteIds = const [],
  });

  /// Get project by ID
  Future<ProjectBundle?> getProject(int projectId);

  /// Get all projects (or shared projects if filter applied)
  Future<List<ProjectBundle>> getAllProjects({bool sharedOnly = false});

  /// Update project
  Future<ProjectBundle> updateProject(ProjectBundle project);

  /// Delete project by ID
  Future<void> deleteProject(int projectId);

  /// Get project by share token
  Future<ProjectBundle?> getProjectByShareToken(String token);

  /// Add note to project (preserves order)
  Future<void> addNoteToProject(int projectId, int noteId);

  /// Remove note from project
  Future<void> removeNoteFromProject(int projectId, int noteId);

  /// Reorder notes in project
  Future<void> reorderNotes(int projectId, List<int> noteIds);
}
