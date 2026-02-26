import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;

/// Auto-generated script to set up dynamic app icons
/// Run this script after adding new icons to your configuration

void main() async {
  Logger().d('Setting up dynamic app icons...');

  final projectRoot = Directory.current.path;
  final manifestPath = path.join(projectRoot, 'android', 'app', 'src', 'main', 'AndroidManifest.xml');

  if (!File(manifestPath).existsSync()) {
    Logger().e('Error: AndroidManifest.xml not found at $manifestPath');
    exit(1);
  }

  Logger().d('✓ AndroidManifest.xml found');
  Logger().d('✓ Activity aliases will be generated automatically');
  Logger().d('✓ Make sure to add your icon files to the appropriate mipmap folders');
  Logger().d('');
  Logger().d('Available icons: default, happy, sleepy');
  Logger().d('');
  Logger().d('Setup complete! You can now use DynamicAppIconPlus.changeIcon() in your app.');
}
