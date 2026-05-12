import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:trovara/app.dart' deferred as app show App;
import 'package:trovara/app_scope.dart' deferred as app_scope show AppScope;
import 'package:trovara/initializer.dart' deferred as initializer show Initializer;

void main({FirebaseOptions? firebaseOptions}) async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await initializer.loadLibrary();
      await app_scope.loadLibrary();
      await app.loadLibrary();

      await initializer.Initializer.load(firebaseOptions: firebaseOptions);
      runApp(app_scope.AppScope(builder: (context) => app.App()));
    } catch (e, stack) {
      debugPrint('Startup error: $e');
      debugPrint('Stack trace: $stack');

      // In case of a fatal startup error, show a basic error message
      // instead of a blank screen.
      runApp(MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to start Trovara',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
    }
  }, (error, stack) {
    debugPrint('Uncaught error: $error');
    debugPrint('Stack trace: $stack');
  });
}
