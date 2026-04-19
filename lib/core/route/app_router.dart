import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trovara/views/chat/chat_view.dart';
import 'package:trovara/views/main/main_view.dart';
import 'package:trovara/views/notes/note/note_view.dart';
import 'package:trovara/views/search/search_view.dart';

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
      GoRoute(
        path: '/chat',
        name: 'chat',
        pageBuilder: (context, state) =>
            MaterialPage(key: state.pageKey, restorationId: 'chat', child: const ChatView()),
      ),
      // ── Search + Tag Filter (vertical slide; not the default horizontal MaterialPage) ──
      GoRoute(
        path: '/search',
        name: 'search',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          restorationId: 'search',
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
              child: child,
            );
          },
          child: const SearchView(),
        ),
      ),
    ],
  );

  static GoRouter get router => _router;
}
