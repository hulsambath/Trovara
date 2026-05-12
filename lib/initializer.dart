import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/storage/theme_mode_storage.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class Initializer {
  static Future<void> load({FirebaseOptions? firebaseOptions}) async {
    WidgetsFlutterBinding.ensureInitialized();

    // Required for easy_localization to load assets before runApp
    await EasyLocalization.ensureInitialized();

    if (firebaseOptions != null) {
      await Firebase.initializeApp(options: firebaseOptions);
    }
    await ThemeModeStorage.instance.initialize();
    await ServiceLocator().initialize();
    // Initialize Google Drive session (silent restore if previously signed in)
    await ServiceLocator().googleDriveService.initialize();

    // Initialize Shorebird Code Push updater (non-blocking).
    // auto_update is disabled in shorebird.yaml, so trigger a background check.
    try {
      // Import is optional; if the package isn't available this will fail gracefully.
      // The Shorebird updater is lightweight and won't block startup.
      final updater = ShorebirdUpdater();
      updater.readCurrentPatch().catchError((_) {});
      updater.checkForUpdate().then((status) {
        if (status == UpdateStatus.outdated) {
          // Download and apply update in background.
          updater.update().catchError((_) {});
        }
      }).catchError((_) {});
    } catch (_) {
      // Ignore if shorebird package is not present or initialization fails.
    }
  }

  static String get deviceType {
    if (kIsWeb) return 'web';

    if (Platform.isAndroid) return 'android';
    if (Platform.isFuchsia) return 'fuchsia';
    if (Platform.isIOS) return 'ios';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'window';

    return 'default';
  }
}
