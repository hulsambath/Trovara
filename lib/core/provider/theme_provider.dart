// ignore_for_file: avoid_function_literals_in_foreach_calls

import 'package:flutter/material.dart';
import 'package:trovara/core/storage/theme_mode_storage.dart';
import 'package:trovara/core/theme/theme_config.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeData get lightTheme => ThemeConfig.light().themeData;
  ThemeData get darkTheme => ThemeConfig.dark().themeData;

  ThemeMode get themeMode => ThemeModeStorage.instance.themeMode;

  ThemeData get theme => isDarkMode() ? ThemeConfig.dark().themeData : ThemeConfig.light().themeData;

  void toggleTheme() {
    final newThemeMode = isDarkMode() ? ThemeMode.light : ThemeMode.dark;
    ThemeModeStorage.instance.writeEnum(newThemeMode);
    notifyListeners();
  }

  void setThemeMode(ThemeMode themeMode) {
    ThemeModeStorage.instance.writeEnum(themeMode);
    notifyListeners();
  }

  bool isDarkMode() => themeMode == ThemeMode.dark;
}
