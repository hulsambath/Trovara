import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/storage/theme_mode_storage.dart';

class Initializer {
  static Future<void> load({FirebaseOptions? firebaseOptions}) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (firebaseOptions != null) {
      await Firebase.initializeApp(options: firebaseOptions);
    }
    await ThemeModeStorage.instance.initialize();
    await ServiceLocator().initialize();
    // Initialize Google Drive session (silent restore if previously signed in)
    await ServiceLocator().googleDriveService.initialize();
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
