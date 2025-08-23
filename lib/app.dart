import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:noteminds/core/provider/theme_provider.dart';
import 'package:noteminds/core/route/app_router.dart';
import 'package:provider/provider.dart';

class App extends StatelessWidget {
  const App({super.key, required this.appRouter});

  final AppRouter appRouter;

  @override
  Widget build(BuildContext context) {
    final ThemeProvider themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [...context.localizationDelegates, FlutterQuillLocalizations.delegate],
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      themeMode: themeProvider.themeMode,
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      routerConfig: appRouter.config(
        navigatorObservers: () => [...AutoRouterDelegate.defaultNavigatorObserversBuilder(), AutoRouteObserver()],
        deepLinkBuilder: (deepLink) => deepLink,
      ),
    );
  }
}
