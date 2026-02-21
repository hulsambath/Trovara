import 'package:flutter/material.dart';
import 'package:trovara/app.dart' deferred as app show App;
import 'package:trovara/app_scope.dart' deferred as app_scope show AppScope;
import 'package:trovara/initializer.dart' deferred as initializer show Initializer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializer.loadLibrary();
  await app_scope.loadLibrary();
  await app.loadLibrary();

  await initializer.Initializer.load();
  runApp(app_scope.AppScope(builder: (context) => app.App()));
}
