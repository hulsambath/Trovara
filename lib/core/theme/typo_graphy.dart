import 'package:flutter/material.dart';

class AppTypography {
  static const String fontFamily = 'Garet';

  /// Applies Trovara typography on top of a Material `TextTheme`.
  ///
  /// This uses only the bundled `Garet` font (see `pubspec.yaml`), no Google
  /// Fonts or runtime font loading.
  static TextTheme applyTo(TextTheme base) {
    final themed = base.apply(fontFamily: fontFamily);

    // Material 3 defaults are good; we mainly enforce consistent weights.
    // You can still override per-widget via `copyWith(...)` in UI code.
    return themed.copyWith(
      displayLarge: themed.displayLarge?._w(FontWeight.w700),
      displayMedium: themed.displayMedium?._w(FontWeight.w700),
      displaySmall: themed.displaySmall?._w(FontWeight.w600),
      headlineLarge: themed.headlineLarge?._w(FontWeight.w700),
      headlineMedium: themed.headlineMedium?._w(FontWeight.w600),
      headlineSmall: themed.headlineSmall?._w(FontWeight.w600),
      titleLarge: themed.titleLarge?._w(FontWeight.w600),
      titleMedium: themed.titleMedium?._w(FontWeight.w600),
      titleSmall: themed.titleSmall?._w(FontWeight.w500),
      bodyLarge: themed.bodyLarge?._w(FontWeight.w400),
      bodyMedium: themed.bodyMedium?._w(FontWeight.w400),
      bodySmall: themed.bodySmall?._w(FontWeight.w400),
      labelLarge: themed.labelLarge?._w(FontWeight.w600),
      labelMedium: themed.labelMedium?._w(FontWeight.w500),
      labelSmall: themed.labelSmall?._w(FontWeight.w500),
    );
  }
}

extension on TextStyle {
  TextStyle _w(FontWeight weight) => copyWith(fontWeight: weight);
}
