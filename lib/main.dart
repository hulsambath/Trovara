import 'package:flutter/material.dart';
import 'package:noteminds/app.dart' deferred as app show App;
import 'package:noteminds/app_scope.dart' deferred as app_scope show AppScope;
import 'package:noteminds/initializer.dart' deferred as initializer show Initializer;

void main() async {
  await initializer.loadLibrary();
  await app_scope.loadLibrary();
  await app.loadLibrary();

  await initializer.Initializer.load();
  runApp(app_scope.AppScope(builder: (context, router) => app.App(appRouter: router)));
}
