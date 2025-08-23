import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:noteminds/app_localization_loader.dart';
import 'package:noteminds/constants/app_constants.dart';
import 'package:noteminds/core/route/app_router.dart';
import 'package:noteminds/provider_scope.dart';

class AppScope extends StatefulWidget {
  static BuildContext? get globalContext => _AppScopeState.instance._router.navigatorKey.currentContext;
  static AppRouter get router => _AppScopeState.instance._router;

  const AppScope({super.key, required this.builder});

  final Widget Function(BuildContext context, AppRouter router) builder;

  static void rebirth(BuildContext context) async {
    try {
      context.router.pushPath('/');
    } catch (e) {
      // handle in case current page is not a router.
    }
    Future.microtask(() => context.findAncestorStateOfType<_AppScopeState>()!.restartApp());
  }

  @override
  State<AppScope> createState() => _AppScopeState();
}

class _AppScopeState extends State<AppScope> {
  _AppScopeState._();

  factory _AppScopeState() => _AppScopeState.instance;
  static final _AppScopeState instance = _AppScopeState._();

  late Key _key;
  late AppRouter _router;

  @override
  void initState() {
    _key = UniqueKey();
    _router = AppRouter();
    super.initState();
  }

  void restartApp() {
    setState(() {
      _key = UniqueKey();
      _router = AppRouter();
    });
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: _key,
    child: ProviderScope(
      child: EasyLocalization(
        path: 'assets/translations',
        useOnlyLangCode: true,
        useFallbackTranslations: true,
        supportedLocales: AppConstants.supportedLocales,
        fallbackLocale: AppConstants.fallbackLocale,
        assetLoader: AppLocalizationLoader(),
        startLocale: AppConstants.fallbackLocale,
        child: widget.builder(context, _router),
      ),
    ),
  );
}
