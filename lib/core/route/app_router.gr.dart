// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i6;
import 'package:flutter/material.dart' as _i7;
import 'package:noteminds/views/main/main_view.dart' as _i1;
import 'package:noteminds/views/notes/note/note_view.dart' as _i2;
import 'package:noteminds/views/notes/notes_view.dart' as _i3;
import 'package:noteminds/views/search/search_view.dart' as _i4;
import 'package:noteminds/views/setting/setting_view.dart' as _i5;

/// generated route for
/// [_i1.MainView]
class MainRoute extends _i6.PageRouteInfo<void> {
  const MainRoute({List<_i6.PageRouteInfo>? children})
    : super(MainRoute.name, initialChildren: children);

  static const String name = 'MainRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return const _i1.MainView();
    },
  );
}

/// generated route for
/// [_i2.NoteView]
class NoteRoute extends _i6.PageRouteInfo<NoteRouteArgs> {
  NoteRoute({_i7.Key? key, String? title, List<_i6.PageRouteInfo>? children})
    : super(
        NoteRoute.name,
        args: NoteRouteArgs(key: key, title: title),
        rawQueryParams: {'title': title},
        initialChildren: children,
      );

  static const String name = 'NoteRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      final queryParams = data.queryParams;
      final args = data.argsAs<NoteRouteArgs>(
        orElse: () => NoteRouteArgs(title: queryParams.optString('title')),
      );
      return _i2.NoteView(key: args.key, title: args.title);
    },
  );
}

class NoteRouteArgs {
  const NoteRouteArgs({this.key, this.title});

  final _i7.Key? key;

  final String? title;

  @override
  String toString() {
    return 'NoteRouteArgs{key: $key, title: $title}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! NoteRouteArgs) return false;
    return key == other.key && title == other.title;
  }

  @override
  int get hashCode => key.hashCode ^ title.hashCode;
}

/// generated route for
/// [_i3.NotesView]
class NotesRoute extends _i6.PageRouteInfo<void> {
  const NotesRoute({List<_i6.PageRouteInfo>? children})
    : super(NotesRoute.name, initialChildren: children);

  static const String name = 'NotesRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return const _i3.NotesView();
    },
  );
}

/// generated route for
/// [_i4.SearchView]
class SearchRoute extends _i6.PageRouteInfo<void> {
  const SearchRoute({List<_i6.PageRouteInfo>? children})
    : super(SearchRoute.name, initialChildren: children);

  static const String name = 'SearchRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return const _i4.SearchView();
    },
  );
}

/// generated route for
/// [_i5.SettingView]
class SettingRoute extends _i6.PageRouteInfo<void> {
  const SettingRoute({List<_i6.PageRouteInfo>? children})
    : super(SettingRoute.name, initialChildren: children);

  static const String name = 'SettingRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return const _i5.SettingView();
    },
  );
}
