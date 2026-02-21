import 'dart:io';

import 'package:dynamic_app_icon_plus/dynamic_app_icon_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';

/// Abstraction over dynamic app icon functionality for both Android and iOS.
/// Android uses [DynamicAppIconPlus], iOS uses [FlutterDynamicIconPlus].
class AppIconService {
  /// Whether dynamic app icons are supported on the current platform.
  static Future<bool> get isSupported async {
    if (Platform.isAndroid) {
      return DynamicAppIconPlus.isInitialized;
    }
    if (Platform.isIOS) {
      return FlutterDynamicIconPlus.supportsAlternateIcons;
    }
    return false;
  }

  /// Gets the currently active icon identifier.
  /// Returns 'default' when using the default/primary icon.
  static Future<String> getCurrentIcon() async {
    if (Platform.isAndroid) {
      final name = await DynamicAppIconPlus.getCurrentIcon();
      return name ?? 'default';
    }
    if (Platform.isIOS) {
      final name = await FlutterDynamicIconPlus.alternateIconName;
      return name ?? 'default';
    }
    return 'default';
  }

  /// Changes the app icon to the specified identifier.
  /// Use 'default' to restore the primary icon.
  static Future<void> changeIcon(String iconIdentifier) async {
    try {
      debugPrint('AppIconService: Attempting to change icon to "$iconIdentifier"');
      if (Platform.isAndroid) {
        await DynamicAppIconPlus.changeIcon(iconIdentifier);
        debugPrint('AppIconService: Android icon changed successfully');
        return;
      }
      if (Platform.isIOS) {
        await FlutterDynamicIconPlus.setAlternateIconName(
          iconName: iconIdentifier == 'default' ? null : iconIdentifier,
        );
        debugPrint('AppIconService: iOS icon changed successfully');
      }
    } catch (e, stackTrace) {
      debugPrint('AppIconService: Failed to change icon to "$iconIdentifier"');
      debugPrint('AppIconService: Error: $e');
      debugPrint('AppIconService: StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Returns icon details for UI display (identifier, path, label, description).
  static List<Map<String, String?>> getIconDetails() {
    const details = [
      {
        'identifier': 'default',
        'path': 'assets/app_icon/1024x1024.png',
        'label': 'Default',
        'description': 'The default NoteMyMinds app icon',
      },
      {
        'identifier': 'happy',
        'path': 'assets/app_icon/happy.png',
        'label': 'Happy',
        'description': 'A cheerful smiley icon',
      },
      {
        'identifier': 'sleepy',
        'path': 'assets/app_icon/sleepy.png',
        'label': 'Sleepy',
        'description': 'A relaxed sleepy icon',
      },
    ];
    if (Platform.isAndroid && DynamicAppIconPlus.isInitialized) {
      return DynamicAppIconPlus.availableIconDetails;
    }
    return details;
  }
}
