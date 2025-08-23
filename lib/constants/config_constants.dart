// ignore_for_file: constant_identifier_names

enum ConfigConstants {
  APP_NAME,
  APP_SCHEME,
  APP_COLOR;

  static final String appName = APP_NAME.value;
  static final String appScheme = APP_SCHEME.value;
  static final String brandColor = APP_COLOR.value;

  String get value {
    switch (this) {
      case APP_NAME:
        return const String.fromEnvironment('APP_NAME');
      case APP_SCHEME:
        return const String.fromEnvironment('APP_SCHEME');
      case APP_COLOR:
        return const String.fromEnvironment('APP_COLOR');
    }
  }
}
