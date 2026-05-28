import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trovara/constants/config_constants.dart';
import 'package:trovara/core/theme/app_typography.dart';

class ThemeConfig {
  static Color brandColor = Color(int.parse(ConfigConstants.brandColor.replaceFirst('#', 'FF'), radix: 16));

  final bool isDarkMode;

  ThemeConfig(this.isDarkMode);

  ThemeConfig.fromDarkMode(this.isDarkMode);

  final lightScheme = ColorScheme.fromSeed(
    seedColor: brandColor,
    brightness: Brightness.light,
  ).copyWith(primary: brandColor);

  final darkScheme = ColorScheme.fromSeed(
    seedColor: brandColor,
    brightness: Brightness.dark,
  ).copyWith(primary: brandColor);

  factory ThemeConfig.light() => ThemeConfig.fromDarkMode(false);

  factory ThemeConfig.dark() => ThemeConfig.fromDarkMode(true);

  ThemeData get themeData {
    ThemeData themeData = isDarkMode ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
    ColorScheme colorScheme = isDarkMode ? darkScheme : lightScheme;

    TargetPlatform platform = defaultTargetPlatform;

    return themeData.copyWith(
      appBarTheme: appBarTheme(colorScheme),
      brightness: colorScheme.brightness,
      primaryColor: colorScheme.primary,
      primaryColorDark: darkScheme.primaryContainer,
      primaryColorLight: lightScheme.primaryContainer,
      scaffoldBackgroundColor: colorScheme.surface,
      colorScheme: colorScheme,
      inputDecorationTheme: _inputDecorationTheme(colorScheme),
      platform: platform,
      splashFactory: splashFactory(platform),
      textTheme: AppTypography.applyTo(themeData.textTheme),
      primaryTextTheme: AppTypography.applyTo(themeData.primaryTextTheme),
      textButtonTheme: TextButtonThemeData(
        style: (themeData.textButtonTheme.style ?? const ButtonStyle()).copyWith(
          splashFactory: splashFactory(themeData.platform),
        ),
      ),
      iconTheme: themeData.iconTheme.copyWith(color: colorScheme.onSurface),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(ColorScheme colorScheme) => InputDecorationTheme(
    border: const OutlineInputBorder(borderSide: BorderSide.none),
    enabledBorder: const OutlineInputBorder(borderSide: BorderSide.none),
    focusedBorder: const OutlineInputBorder(borderSide: BorderSide.none),
    errorBorder: const OutlineInputBorder(borderSide: BorderSide.none),
    focusedErrorBorder: const OutlineInputBorder(borderSide: BorderSide.none),
    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withAlpha(128)),
    labelStyle: TextStyle(color: colorScheme.onSurfaceVariant.withAlpha(128)),
    floatingLabelStyle: TextStyle(color: colorScheme.onSurfaceVariant.withAlpha(128)),
    helperStyle: TextStyle(color: colorScheme.onSurfaceVariant.withAlpha(128)),
    helperMaxLines: 1,
    activeIndicatorBorder: BorderSide(color: colorScheme.primary),
    errorStyle: TextStyle(color: colorScheme.error),
  );

  static AppBarTheme appBarTheme(ColorScheme colorScheme) => AppBarTheme(
    toolbarHeight: kToolbarHeight - 10,
    backgroundColor: colorScheme.surface,
    shadowColor: Colors.transparent,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontFamily: AppTypography.fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    ),
  );

  static InteractiveInkFeatureFactory splashFactory(TargetPlatform platform) =>
      isApple(platform) ? NoSplash.splashFactory : InkSparkle.splashFactory;

  static bool isApple(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return false;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
    }
  }
}
