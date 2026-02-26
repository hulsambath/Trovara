import 'package:trovara/constants/config_constants.dart';
import 'package:trovara/core/repository/base/objectbox_store_manager.dart';
import 'package:trovara/core/repository/implementations/objectbox_custom_tag_repository.dart';
import 'package:trovara/core/repository/implementations/objectbox_embedding_repository.dart';
import 'package:trovara/core/repository/implementations/objectbox_folder_repository.dart';
import 'package:trovara/core/repository/implementations/objectbox_note_repository.dart';
import 'package:trovara/core/repository/interfaces/custom_tag_repository.dart';
import 'package:trovara/core/repository/interfaces/embedding_repository.dart';
import 'package:trovara/core/repository/interfaces/folder_repository.dart';
import 'package:trovara/core/repository/interfaces/note_repository.dart';
import 'package:trovara/core/services/custom_tag_service.dart';
import 'package:trovara/core/services/document_resolver_service.dart';
import 'package:trovara/core/services/embedding_service.dart';
import 'package:trovara/core/services/google_drive_service.dart';
import 'package:trovara/core/services/google_drive_sync_service.dart';
import 'package:trovara/core/services/llm_client.dart';
import 'package:trovara/core/services/note_service.dart';
import 'package:trovara/core/services/prompt_builder_service.dart';
import 'package:trovara/core/services/rag_service.dart';
import 'package:trovara/core/services/vector_search_service.dart';

/// Service Locator for dependency injection
/// Follows Dependency Inversion Principle - provides abstractions, not concrete implementations
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  // Lazy initialization of services
  INoteRepository? _noteRepository;
  IFolderRepository? _folderRepository;
  ICustomTagRepository? _customTagRepository;
  IEmbeddingRepository? _embeddingRepository;
  NoteService? _noteService;
  CustomTagService? _customTagService;
  EmbeddingService? _embeddingService;
  VectorSearchService? _vectorSearchService;
  DocumentResolverService? _documentResolverService;
  PromptBuilderService? _promptBuilderService;
  LlmClient? _llmClient;
  RagService? _ragService;
  GoogleDriveService? _googleDriveService;
  GoogleDriveSyncService? _googleDriveSyncService;

  /// Get the note repository instance
  INoteRepository get noteRepository {
    _noteRepository ??= ObjectBoxNoteRepository();
    return _noteRepository!;
  }

  /// Get the folder repository instance
  IFolderRepository get folderRepository {
    _folderRepository ??= ObjectBoxFolderRepository();
    return _folderRepository!;
  }

  /// Get the custom tag repository instance
  ICustomTagRepository get customTagRepository {
    _customTagRepository ??= ObjectBoxCustomTagRepository();
    return _customTagRepository!;
  }

  /// Get the embedding repository instance
  IEmbeddingRepository get embeddingRepository {
    _embeddingRepository ??= ObjectBoxEmbeddingRepository();
    return _embeddingRepository!;
  }

  /// Get the embedding service instance
  EmbeddingService get embeddingService {
    _embeddingService ??= EmbeddingService(
      embeddingRepository: embeddingRepository,
      apiKey: ConfigConstants.geminiApiKey,
    );
    return _embeddingService!;
  }

  /// Get the vector search service instance
  VectorSearchService get vectorSearchService {
    _vectorSearchService ??= VectorSearchService(repository: embeddingRepository);
    return _vectorSearchService!;
  }

  /// Get the document resolver service instance
  DocumentResolverService get documentResolverService {
    _documentResolverService ??= DocumentResolverService(noteService: noteService);
    return _documentResolverService!;
  }

  /// Get the prompt builder service instance
  PromptBuilderService get promptBuilderService {
    _promptBuilderService ??= PromptBuilderService(documentResolver: documentResolverService);
    return _promptBuilderService!;
  }

  /// Get the LLM client instance
  LlmClient get llmClient {
    _llmClient ??= LlmClient(apiKey: ConfigConstants.geminiApiKey);
    return _llmClient!;
  }

  /// Get the RAG service instance
  RagService get ragService {
    _ragService ??= RagService(
      embeddingService: embeddingService,
      vectorSearchService: vectorSearchService,
      promptBuilderService: promptBuilderService,
      llmClient: llmClient,
    );
    return _ragService!;
  }

  /// Get the note service instance
  NoteService get noteService {
    _noteService ??= NoteService(
      noteRepository: noteRepository,
      folderRepository: folderRepository,
      driveService: googleDriveService,
      embeddingService: embeddingService,
    );
    return _noteService!;
  }

  /// Get the custom tag service instance
  CustomTagService get customTagService {
    _customTagService ??= CustomTagService(customTagRepository: customTagRepository);
    return _customTagService!;
  }

  GoogleDriveService get googleDriveService {
    _googleDriveService ??= GoogleDriveService();
    return _googleDriveService!;
  }

  /// Get the Google Drive sync service instance
  GoogleDriveSyncService get googleDriveSyncService {
    _googleDriveSyncService ??= GoogleDriveSyncService();
    return _googleDriveSyncService!;
  }

  /// Initialize all services
  Future<void> initialize() async {
    await noteService.initialize();
    await customTagService.initialize();
    await embeddingService.initialize();
    await llmClient.initialize();
  }

  /// Dispose all services
  void dispose() {
    _noteService?.dispose();
    _noteRepository?.dispose();
    _folderRepository?.dispose();
    _embeddingRepository?.dispose();
    _googleDriveService = null;
    _googleDriveSyncService = null;

    // Close the shared ObjectBox Store
    ObjectBoxStoreManager().close();

    _noteService = null;
    _noteRepository = null;
    _folderRepository = null;
    _embeddingRepository = null;
    _embeddingService = null;
    _vectorSearchService = null;
    _documentResolverService = null;
    _promptBuilderService = null;
    _llmClient = null;
    _ragService = null;
  }
}
