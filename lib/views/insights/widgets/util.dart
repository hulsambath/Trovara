import 'package:flutter/material.dart';

Color colorForValue(int v, ColorScheme scheme) {
  switch (v) {
    case 0:
      return scheme.surfaceContainerHighest.withValues(alpha: 0.6);
    case 1:
      return scheme.primary.withValues(alpha: 0.20);
    case 2:
      return scheme.primary.withValues(alpha: 0.35);
    case 3:
      return scheme.primary.withValues(alpha: 0.55);
    case 4:
    default:
      return scheme.primary.withValues(alpha: 0.80);
  }
}
