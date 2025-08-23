import 'package:auto_route/auto_route.dart';
import 'package:noteminds/core/route/app_router.gr.dart';

final routers = [
  AutoRoute(
    page: MainRoute.page,
    path: '/',
    children: [
      AutoRoute(page: NotesRoute.page, path: 'note', initial: true),
      AutoRoute(page: SearchRoute.page, path: 'search'),
      AutoRoute(page: SettingRoute.page, path: 'setting'),
    ],
  ),
  AutoRoute(page: NoteRoute.page, path: '/note'),
];
