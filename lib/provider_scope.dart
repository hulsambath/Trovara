import 'package:flutter/material.dart';
import 'package:notemyminds/core/provider/in_app_update_provider.dart';
import 'package:notemyminds/core/provider/theme_provider.dart';
import 'package:provider/provider.dart';

class ProviderScope extends StatelessWidget {
  final Widget child;

  const ProviderScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ChangeNotifierProvider(create: (context) => InAppUpdateProvider()),
    ],
    child: child,
  );
}
