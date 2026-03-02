// ignore_for_file: constant_identifier_names

enum ConfigConstants {
  APP_NAME,
  APP_SCHEME,
  APP_COLOR,
  GEMINI_API_KEY,
  OPENAI_API_KEY,
  OPENROUTER_API_KEY,
  OPENROUTER_MODEL,
  OPENROUTER_SITE_URL,
  OPENROUTER_APP_NAME,
  OPENROUTER_EMBEDDING_MODEL;

  static final String appName = APP_NAME.value;
  static final String appScheme = APP_SCHEME.value;
  static final String brandColor = APP_COLOR.value;
  static final String geminiApiKey = GEMINI_API_KEY.value;
  static final String openAiApiKey = OPENAI_API_KEY.value;
  static final String openRouterApiKey = OPENROUTER_API_KEY.value;
  static final String openRouterModel = OPENROUTER_MODEL.value;
  static final String openRouterSiteUrl = OPENROUTER_SITE_URL.value;
  static final String openRouterAppName = OPENROUTER_APP_NAME.value;
  static final String openRouterEmbeddingModel = OPENROUTER_EMBEDDING_MODEL.value;

  String get value {
    switch (this) {
      case APP_NAME:
        return const String.fromEnvironment('APP_NAME');
      case APP_SCHEME:
        return const String.fromEnvironment('APP_SCHEME');
      case APP_COLOR:
        return const String.fromEnvironment('APP_COLOR');
      case GEMINI_API_KEY:
        return const String.fromEnvironment('GEMINI_API_KEY');
      case OPENAI_API_KEY:
        return const String.fromEnvironment('OPENAI_API_KEY');
      case OPENROUTER_API_KEY:
        return const String.fromEnvironment('OPENROUTER_API_KEY');
      case OPENROUTER_MODEL:
        return const String.fromEnvironment('OPENROUTER_MODEL', defaultValue: 'openrouter/auto');
      case OPENROUTER_SITE_URL:
        return const String.fromEnvironment('OPENROUTER_SITE_URL');
      case OPENROUTER_APP_NAME:
        return const String.fromEnvironment('OPENROUTER_APP_NAME', defaultValue: 'Trovara');
      case OPENROUTER_EMBEDDING_MODEL:
        return const String.fromEnvironment(
          'OPENROUTER_EMBEDDING_MODEL',
          defaultValue: 'openai/text-embedding-3-small',
        );
    }
  }
}
