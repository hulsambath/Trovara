import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trovara/app_localization_loader.dart';
import 'package:trovara/constants/app_constants.dart';
import 'package:trovara/core/route/app_router.dart';
import 'package:trovara/provider_scope.dart';

class AppScope extends StatefulWidget {
  static BuildContext? get globalContext => _AppScopeState.instance._router.routerDelegate.navigatorKey.currentContext;

  const AppScope({super.key, required this.builder});

  final Widget Function(BuildContext context) builder;

  static void rebirth(BuildContext context) async {
    try {
      context.go('/');
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
  final GoRouter _router = AppRouter.router;

  @override
  void initState() {
    _key = UniqueKey();
    super.initState();
  }

  void restartApp() {
    setState(() {
      _key = UniqueKey();
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
        child: widget.builder(context),
      ),
    ),
  );
}
