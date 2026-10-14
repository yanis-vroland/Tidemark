import 'package:flutter/material.dart';

/// Couleurs de la charte (docs/maquettes/000-charte/tokens.json), une par jeton,
/// nommées comme lui en camelCase (`surface-raised` → `surfaceRaised`).
///
/// Seul fichier de l'app, avec le reste de `lib/ui/theme/`, autorisé à écrire une
/// couleur en dur : test/guards/no_hardcoded_colors_test.dart le vérifie.
@immutable
class TidemarkColors extends ThemeExtension<TidemarkColors> {
  const TidemarkColors({
    required this.surface,
    required this.surfaceRaised,
    required this.ink,
    required this.inkMuted,
    required this.line,
    required this.tide,
    required this.onTide,
    required this.tideSoft,
    required this.danger,
    required this.mood1,
    required this.mood2,
    required this.mood3,
    required this.mood4,
    required this.mood5,
    required this.onMood1,
    required this.onMood,
  });

  static const light = TidemarkColors(
    surface: Color(0xFFF3F6F5),
    surfaceRaised: Color(0xFFFFFFFF),
    ink: Color(0xFF13272C),
    inkMuted: Color(0xFF4B5E64),
    line: Color(0xFF76898D),
    tide: Color(0xFF1D5F6B),
    onTide: Color(0xFFFFFFFF),
    tideSoft: Color(0xFFDBEAE9),
    danger: Color(0xFFA3392A),
    mood1: Color(0xFF3C4F7C),
    mood2: Color(0xFF6684B0),
    mood3: Color(0xFF86B2AB),
    mood4: Color(0xFFE2B55A),
    mood5: Color(0xFFEF8C59),
    onMood1: Color(0xFFFFFFFF),
    onMood: Color(0xFF13272C),
  );

  static const dark = TidemarkColors(
    surface: Color(0xFF0E191C),
    surfaceRaised: Color(0xFF172529),
    ink: Color(0xFFE4EEEC),
    inkMuted: Color(0xFF9DB0B1),
    line: Color(0xFF5D7579),
    tide: Color(0xFF7CC5C9),
    onTide: Color(0xFF0A2226),
    tideSoft: Color(0xFF1E383C),
    danger: Color(0xFFF39582),
    mood1: Color(0xFF8FA3D6),
    mood2: Color(0xFF7F9CC8),
    mood3: Color(0xFF86B9B1),
    mood4: Color(0xFFE6BE6A),
    mood5: Color(0xFFF29A6A),
    onMood1: Color(0xFF0E191C),
    onMood: Color(0xFF0E191C),
  );

  final Color surface;
  final Color surfaceRaised;
  final Color ink;
  final Color inkMuted;
  final Color line;
  final Color tide;
  final Color onTide;
  final Color tideSoft;
  final Color danger;
  final Color mood1;
  final Color mood2;
  final Color mood3;
  final Color mood4;
  final Color mood5;
  final Color onMood1;
  final Color onMood;

  /// Pastille de l'humeur [mood], de 1 à 5.
  Color moodColor(int mood) => switch (mood) {
    1 => mood1,
    2 => mood2,
    3 => mood3,
    4 => mood4,
    5 => mood5,
    _ => throw RangeError.range(mood, 1, 5, 'mood'),
  };

  /// Chiffre posé sur la pastille de l'humeur [mood].
  Color onMoodColor(int mood) => mood == 1 ? onMood1 : onMood;

  /// Couleurs indexées par le nom du jeton de la charte, pour les tests de fidélité.
  Map<String, Color> toTokenMap() => {
    'surface': surface,
    'surface-raised': surfaceRaised,
    'ink': ink,
    'ink-muted': inkMuted,
    'line': line,
    'tide': tide,
    'on-tide': onTide,
    'tide-soft': tideSoft,
    'danger': danger,
    'mood-1': mood1,
    'mood-2': mood2,
    'mood-3': mood3,
    'mood-4': mood4,
    'mood-5': mood5,
    'on-mood-1': onMood1,
    'on-mood': onMood,
  };

  /// Jetons figés : aucune surcharge prévue.
  @override
  TidemarkColors copyWith() => this;

  @override
  TidemarkColors lerp(TidemarkColors? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

extension TidemarkColorsContext on BuildContext {
  TidemarkColors get colors => Theme.of(this).extension<TidemarkColors>()!;
}
