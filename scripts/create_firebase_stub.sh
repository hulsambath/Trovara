#!/usr/bin/env bash
set -euo pipefail

mkdir -p lib/firebase_options
cat > lib/firebase_options/staging.dart << 'DART'
// CI stub – real keys are injected at build time
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError('Platform not supported');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'x',
    appId: 'x',
    messagingSenderId: 'x',
    projectId: 'x',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'x',
    appId: 'x',
    messagingSenderId: 'x',
    projectId: 'x',
    iosBundleId: 'x',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'x',
    appId: 'x',
    messagingSenderId: 'x',
    projectId: 'x',
    iosBundleId: 'x',
  );
}
DART

cp lib/firebase_options/staging.dart lib/firebase_options/prod.dart
