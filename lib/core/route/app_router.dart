import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:noteminds/views/main/main_view.dart';
import 'package:noteminds/views/notes/note/note_view.dart';
import 'package:noteminds/views/notes/notes_view.dart';
import 'package:noteminds/views/search/search_view.dart';
import 'package:noteminds/views/setting/setting_view.dart';

class AppRouter {
  static final GoRouter _router = GoRouter(
    initialLocation: '/',
    restorationScopeId: 'router',
    debugLogDiagnostics: true,
    onException: (context, state, router) {
      debugPrint('GoRouter exception: ${router.routerDelegate.currentConfiguration}');
    },
    routes: [
      ShellRoute(
        pageBuilder: (context, state, child) => MaterialPage(
          key: state.pageKey,
          restorationId: 'shell',
          child: MainView(child: child),
        ),
        routes: [
          GoRoute(
            path: '/',
            name: 'notes',
            pageBuilder: (context, state) =>
                MaterialPage(key: state.pageKey, restorationId: 'notes', child: const NotesView()),
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            pageBuilder: (context, state) =>
                MaterialPage(key: state.pageKey, restorationId: 'search', child: const SearchView()),
          ),
          GoRoute(
            path: '/setting',
            name: 'setting',
            pageBuilder: (context, state) =>
                MaterialPage(key: state.pageKey, restorationId: 'setting', child: const SettingView()),
          ),
        ],
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
