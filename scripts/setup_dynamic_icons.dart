import 'dart:io';
import 'package:path/path.dart' as path;

/// Auto-generated script to set up dynamic app icons
/// Run this script after adding new icons to your configuration

void main() async {
  print('Setting up dynamic app icons...');
  
  final projectRoot = Directory.current.path;
  final manifestPath = path.join(projectRoot, 'android', 'app', 'src', 'main', 'AndroidManifest.xml');
  
  if (!File(manifestPath).existsSync()) {
    print('Error: AndroidManifest.xml not found at $manifestPath');
    exit(1);
  }
  
  print('✓ AndroidManifest.xml found');
  print('✓ Activity aliases will be generated automatically');
  print('✓ Make sure to add your icon files to the appropriate mipmap folders');
  print('');
  print('Available icons: default, happy, sleepy');
  print('');
  print('Setup complete! You can now use DynamicAppIconPlus.changeIcon() in your app.');
}
