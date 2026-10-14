import 'package:flutter/material.dart';

import 'tidemark_colors.dart';
import 'tidemark_typography.dart';

/// Thème Material construit uniquement à partir des jetons de la charte.
ThemeData buildTidemarkTheme(Brightness brightness) {
  final colors = brightness == Brightness.dark
      ? TidemarkColors.dark
      : TidemarkColors.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: colors.tide,
    onPrimary: colors.onTide,
    secondary: colors.tide,
    onSecondary: colors.onTide,
    error: colors.danger,
    onError: colors.surfaceRaised,
    surface: colors.surface,
    onSurface: colors.ink,
    surfaceContainer: colors.surfaceRaised,
    onSurfaceVariant: colors.inkMuted,
    outline: colors.line,
    secondaryContainer: colors.tideSoft,
    onSecondaryContainer: colors.ink,
  );
  final textTheme = TextTheme(
    displaySmall: TidemarkTypography.display,
    titleLarge: TidemarkTypography.title,
    titleMedium: TidemarkTypography.headline,
    bodyLarge: TidemarkTypography.body,
    labelLarge: TidemarkTypography.label,
    bodySmall: TidemarkTypography.caption,
  ).apply(bodyColor: colors.ink, displayColor: colors.ink);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.surface,
    fontFamily: TidemarkTypography.bodyFamily,
    textTheme: textTheme,
    extensions: [colors],
  );
}
