import 'dart:convert';
import 'package:trovara/core/repository/base/base_repository.dart';
import 'package:trovara/core/repository/base/objectbox_store_manager.dart';
import 'package:trovara/core/repository/interfaces/iproject_bundle_repository.dart';
import 'package:trovara/models/project_bundle.dart';
import 'package:trovara/objectbox.g.dart';

class ObjectBoxProjectBundleRepository extends BaseRepository
    implements IProjectBundleRepository {
  final ObjectBoxStoreManager storeManager;

  ObjectBoxProjectBundleRepository(this.storeManager);

  @override
  Future<ProjectBundle> createProject({
    required String name,
    String? description,
    List<int> noteIds = const [],
  }) async {
    final store = await storeManager.store;
    final box = store.box<ProjectBundle>();

    final project = ProjectBundle(
      name: name,
      description: description,
      noteIdsJson: jsonEncode(noteIds),
    );
    box.put(project);
    notifyListeners();
    return project;
  }

  @override
  Future<ProjectBundle?> getProject(int projectId) async {
    final store = await storeManager.store;
    final box = store.box<ProjectBundle>();
    return box.get(projectId);
  }

  @override
  Future<List<ProjectBundle>> getAllProjects({bool sharedOnly = false}) async {
    final store = await storeManager.store;
    final box = store.box<ProjectBundle>();

    if (sharedOnly) {
      final query = box.query(ProjectBundle_.isShared.equals(true))
          .order(ProjectBundle_.updatedAt, flags: Order.descending)
          .build();
      final results = query.find();
      query.close();
      return results;
    }

    return box.getAll();
  }

  @override
  Future<ProjectBundle> updateProject(ProjectBundle project) async {
    final store = await storeManager.store;
    final box = store.box<ProjectBundle>();
    project.updatedAt = DateTime.now();
    box.put(project);
    notifyListeners();
    return project;
  }

  @override
  Future<void> deleteProject(int projectId) async {
    final store = await storeManager.store;
    final box = store.box<ProjectBundle>();
    box.remove(projectId);
    notifyListeners();
  }

  @override
  Future<ProjectBundle?> getProjectByShareToken(String token) async {
    final store = await storeManager.store;
    final box = store.box<ProjectBundle>();

    final query = box.query(ProjectBundle_.shareToken.equals(token)).build();
    final result = query.findFirst();
    query.close();

    return result;
  }

  @override
  Future<void> addNoteToProject(int projectId, int noteId) async {
    final store = await storeManager.store;
    final box = store.box<ProjectBundle>();

    final project = box.get(projectId);
    if (project != null) {
      final noteIds = project.noteIds;
      if (!noteIds.contains(noteId)) {
        noteIds.add(noteId);
        project.setNoteIds(noteIds);
        box.put(project);
        notifyListeners();
      }
    }
  }

  @override
  Future<void> removeNoteFromProject(int projectId, int noteId) async {
    final store = await storeManager.store;
    final box = store.box<ProjectBundle>();

    final project = box.get(projectId);
    if (project != null) {
      final noteIds = project.noteIds;
      noteIds.remove(noteId);
      project.setNoteIds(noteIds);
      box.put(project);
      notifyListeners();
    }
  }

  @override
  Future<void> reorderNotes(int projectId, List<int> noteIds) async {
    final store = await storeManager.store;
    final box = store.box<ProjectBundle>();

    final project = box.get(projectId);
    if (project != null) {
      project.setNoteIds(noteIds);
      box.put(project);
      notifyListeners();
    }
  }
}
