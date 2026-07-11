import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Routes uncaught Flutter, platform, and zone errors to Firebase Crashlytics.
///
/// Collection is disabled in debug builds so local development crashes don't
/// pollute the console. All entry points no-op when Firebase isn't initialized
/// (e.g. tests, or a flavor started without Firebase options).
class CrashReportingService {
  CrashReportingService._();

  static bool get _available => Firebase.apps.isNotEmpty;

  /// Call once, immediately after `Firebase.initializeApp`.
  static Future<void> initialize() async {
    if (!_available) return;

    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      previousOnError?.call(details);
      crashlytics.recordFlutterFatalError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  }

  /// For manual reporting (e.g. the root `runZonedGuarded` handler).
  static void recordError(Object error, StackTrace stack, {bool fatal = false}) {
    if (!_available) return;
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal);
  }
}
