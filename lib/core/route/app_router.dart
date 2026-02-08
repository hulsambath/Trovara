import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:noteminds/views/main/main_view.dart';
import 'package:noteminds/views/notes/note/note_view.dart';

class AppRouter {
  static final GoRouter _router = GoRouter(
    initialLocation: '/',
    restorationScopeId: 'router',
    debugLogDiagnostics: true,
    onException: (context, state, router) {
      debugPrint('GoRouter exception: ${router.routerDelegate.currentConfiguration}');
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'main',
        pageBuilder: (context, state) =>
            MaterialPage(key: state.pageKey, restorationId: 'main', child: const MainView()),
      ),
      GoRoute(
        path: '/note',
        name: 'note',
        pageBuilder: (context, state) {
          final title = state.uri.queryParameters['title'];
          return MaterialPage(
            key: state.pageKey,
            restorationId: 'note',
            child: NoteView(title: title),
          );
        },
      ),
    ],
  );

  static GoRouter get router => _router;
}
