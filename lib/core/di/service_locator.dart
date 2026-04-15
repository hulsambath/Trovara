import 'package:trovara/constants/config_constants.dart';
import 'package:trovara/core/repository/base/objectbox_store_manager.dart';
import 'package:trovara/core/repository/implementations/objectbox_chat_message_repository.dart';
import 'package:trovara/core/repository/implementations/objectbox_chat_thread_repository.dart';
import 'package:trovara/core/repository/implementations/objectbox_custom_tag_repository.dart';
import 'package:trovara/core/repository/implementations/objectbox_embedding_repository.dart';
import 'package:trovara/core/repository/implementations/objectbox_folder_repository.dart';
import 'package:trovara/core/repository/implementations/objectbox_note_repository.dart';
import 'package:trovara/core/repository/interfaces/chat_message_repository.dart';
import 'package:trovara/core/repository/interfaces/chat_thread_repository.dart';
import 'package:trovara/core/repository/interfaces/custom_tag_repository.dart';
import 'package:trovara/core/repository/interfaces/embedding_repository.dart';
import 'package:trovara/core/repository/interfaces/folder_repository.dart';
import 'package:trovara/core/repository/interfaces/note_repository.dart';
import 'package:trovara/core/services/chat/chat_drive_sync_service.dart';
import 'package:trovara/core/services/chat/chat_service.dart';
import 'package:trovara/core/services/custom_tag_service.dart';
import 'package:trovara/core/services/document_resolver_service.dart';
import 'package:trovara/core/services/embedding_service.dart';
import 'package:trovara/core/services/google_drive_service.dart';
import 'package:trovara/core/services/google_drive_sync_service.dart';
import 'package:trovara/core/services/llm_client.dart';
import 'package:trovara/core/services/multi_query_expansion_service.dart';
import 'package:trovara/core/services/note_service.dart';
import 'package:trovara/core/services/prompt_builder_service.dart';
import 'package:trovara/core/services/query_rewrite_service.dart';
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
  LlmClient? _rewriteLlmClient;
  QueryRewriteService? _queryRewriteService;
  MultiQueryExpansionService? _multiQueryExpansionService;
  RagService? _ragService;
  GoogleDriveService? _googleDriveService;
  GoogleDriveSyncService? _googleDriveSyncService;
  IChatThreadRepository? _chatThreadRepository;
  IChatMessageRepository? _chatMessageRepository;
  ChatService? _chatService;
  ChatDriveSyncService? _chatDriveSyncService;

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
    if (_embeddingService == null) {
      if (ConfigConstants.geminiApiKey.isNotEmpty) {
        _embeddingService = EmbeddingService(
          embeddingRepository: embeddingRepository,
          provider: EmbeddingProvider.gemini,
          apiKey: ConfigConstants.geminiApiKey,
          modelName: EmbeddingService.defaultGeminiEmbeddingModel,
        );
      } else if (ConfigConstants.openAiApiKey.isNotEmpty) {
        _embeddingService = EmbeddingService(
          embeddingRepository: embeddingRepository,
          provider: EmbeddingProvider.openAiCompatible,
          baseUrl: 'https://api.openai.com/v1',
          apiKey: ConfigConstants.openAiApiKey,
          modelName: ConfigConstants.openAiEmbeddingModel,
        );
      } else {
        // Fallback to OpenRouter (default or empty)
        _embeddingService = EmbeddingService(
          embeddingRepository: embeddingRepository,
          provider: EmbeddingProvider.openAiCompatible,
          apiKey: ConfigConstants.openRouterApiKey,
          modelName: ConfigConstants.openRouterEmbeddingModel,
          siteUrl: ConfigConstants.openRouterSiteUrl,
          appName: ConfigConstants.openRouterAppName,
        );
      }
    }
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
    if (_llmClient == null) {
      if (ConfigConstants.geminiApiKey.isNotEmpty) {
        _llmClient = LlmClient(
          provider: LlmProvider.gemini,
          apiKey: ConfigConstants.geminiApiKey,
          modelName: LlmClient.defaultGeminiModel,
        );
      } else if (ConfigConstants.openAiApiKey.isNotEmpty) {
        _llmClient = LlmClient(
          provider: LlmProvider.openAiCompatible,
          baseUrl: 'https://api.openai.com/v1',
          apiKey: ConfigConstants.openAiApiKey,
          modelName: 'gpt-4o-mini',
        );
      } else {
        // Fallback to OpenRouter
        _llmClient = LlmClient(
          provider: LlmProvider.openAiCompatible,
          apiKey: ConfigConstants.openRouterApiKey,
          modelName: ConfigConstants.openRouterModel,
          siteUrl: ConfigConstants.openRouterSiteUrl,
          appName: ConfigConstants.openRouterAppName,
        );
      }
    }
    return _llmClient!;
  }

  /// LLM client used for query rewriting/expansion (separate config).
  LlmClient get rewriteLlmClient {
    if (_rewriteLlmClient == null) {
      if (ConfigConstants.geminiApiKey.isNotEmpty) {
        _rewriteLlmClient = LlmClient(
          provider: LlmProvider.gemini,
          apiKey: ConfigConstants.geminiApiKey,
          modelName: LlmClient.defaultGeminiModel,
          temperature: 0.0,
          topP: 1.0,
          maxOutputTokens: 256,
        );
      } else if (ConfigConstants.openAiApiKey.isNotEmpty) {
        _rewriteLlmClient = LlmClient(
          provider: LlmProvider.openAiCompatible,
          baseUrl: 'https://api.openai.com/v1',
          apiKey: ConfigConstants.openAiApiKey,
          modelName: 'gpt-4o-mini',
          temperature: 0.0,
          topP: 1.0,
          maxOutputTokens: 256,
        );
      } else {
        _rewriteLlmClient = LlmClient(
          provider: LlmProvider.openAiCompatible,
          apiKey: ConfigConstants.openRouterApiKey,
          modelName: ConfigConstants.openRouterModel,
          siteUrl: ConfigConstants.openRouterSiteUrl,
          appName: ConfigConstants.openRouterAppName,
          temperature: 0.0,
          topP: 1.0,
          maxOutputTokens: 256,
        );
      }
    }
    return _rewriteLlmClient!;
  }

  QueryRewriteService get queryRewriteService {
    _queryRewriteService ??= QueryRewriteService(llmClient: rewriteLlmClient);
    return _queryRewriteService!;
  }

  MultiQueryExpansionService get multiQueryExpansionService {
    _multiQueryExpansionService ??= MultiQueryExpansionService(llmClient: rewriteLlmClient);
    return _multiQueryExpansionService!;
  }

  /// Get the RAG service instance
  RagService get ragService {
    _ragService ??= RagService(
      embeddingService: embeddingService,
      vectorSearchService: vectorSearchService,
      documentResolverService: documentResolverService,
      promptBuilderService: promptBuilderService,
      llmClient: llmClient,
      queryRewriteService: queryRewriteService,
      multiQueryExpansionService: multiQueryExpansionService,
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
      customTagService: customTagService,
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

  /// Get the chat thread repository instance
  IChatThreadRepository get chatThreadRepository {
    _chatThreadRepository ??= ObjectBoxChatThreadRepository();
    return _chatThreadRepository!;
  }

  /// Get the chat message repository instance
  IChatMessageRepository get chatMessageRepository {
    _chatMessageRepository ??= ObjectBoxChatMessageRepository();
    return _chatMessageRepository!;
  }

  /// Get the chat service instance
  ChatService get chatService {
    _chatService ??= ChatService(threadRepository: chatThreadRepository, messageRepository: chatMessageRepository);
    return _chatService!;
  }

  /// Get the chat Drive sync service instance
  ChatDriveSyncService get chatDriveSyncService {
    _chatDriveSyncService ??= ChatDriveSyncService();
    return _chatDriveSyncService!;
  }

  /// Initialize all services
  Future<void> initialize() async {
    await noteService.initialize();
    await customTagService.initialize();
    await embeddingService.initialize();
    await llmClient.initialize();
    await rewriteLlmClient.initialize();
    await chatService.initialize();
  }

  /// Dispose all services
  void dispose() {
    _chatService?.dispose();
    _noteService?.dispose();
    _noteRepository?.dispose();
    _folderRepository?.dispose();
    _embeddingRepository?.dispose();
    _googleDriveService = null;
    _googleDriveSyncService = null;
    _chatDriveSyncService = null;

    // Close the shared ObjectBox Store
    ObjectBoxStoreManager().close();

    _chatService = null;
    _chatThreadRepository = null;
    _chatMessageRepository = null;
    _noteService = null;
    _noteRepository = null;
    _folderRepository = null;
    _embeddingRepository = null;
    _embeddingService = null;
    _vectorSearchService = null;
    _documentResolverService = null;
    _promptBuilderService = null;
    _llmClient = null;
    _rewriteLlmClient = null;
    _queryRewriteService = null;
    _multiQueryExpansionService = null;
    _ragService = null;
  }
}
