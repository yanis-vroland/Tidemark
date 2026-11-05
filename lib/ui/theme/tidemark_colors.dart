import 'package:flutter/material.dart';

/// Couleurs de la charte v2 (docs/maquettes/000-charte/tokens.json, spec 008), une
/// par jeton, nommées comme lui en camelCase (`surface-raised` → `surfaceRaised`).
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
    required this.mood1Soft,
    required this.mood2Soft,
    required this.mood3Soft,
    required this.mood4Soft,
    required this.mood5Soft,
    required this.onMood,
    required this.mood1Night,
    required this.mood2Night,
    required this.mood3Night,
    required this.mood4Night,
    required this.mood5Night,
    required this.bubbleCheek,
    required this.bubbleTear,
    required this.bubbleShine,
    required this.hero,
    required this.heroWave1,
    required this.heroWave2,
    required this.onHero,
    required this.onHeroMuted,
    required this.sky,
    required this.onSky,
    required this.sea,
    required this.sun,
    required this.moon,
    required this.sand,
    required this.onSand,
    required this.brand,
    required this.onBrand,
    required this.brandAccent,
  });

  static const light = TidemarkColors(
    surface: Color(0xFFF7F3EC),
    surfaceRaised: Color(0xFFFFFFFF),
    ink: Color(0xFF14262B),
    inkMuted: Color(0xFF4B5E64),
    line: Color(0xFF76898D),
    tide: Color(0xFF1D5F6B),
    onTide: Color(0xFFFFFFFF),
    tideSoft: Color(0xFFDBEAE9),
    danger: Color(0xFFA3392A),
    mood1: Color(0xFF5868AD),
    mood2: Color(0xFF6B93D3),
    mood3: Color(0xFF62B3A5),
    mood4: Color(0xFFF0B84A),
    mood5: Color(0xFFF78B52),
    mood1Soft: Color(0xFFDFE3F6),
    mood2Soft: Color(0xFFDDE9F9),
    mood3Soft: Color(0xFFD9F1EB),
    mood4Soft: Color(0xFFFDF0CF),
    mood5Soft: Color(0xFFFFE2D1),
    onMood: Color(0xFF14262B),
    mood1Night: Color(0xFFE9EBF5),
    mood2Night: Color(0xFFE8EFF8),
    mood3Night: Color(0xFFE6F2EE),
    mood4Night: Color(0xFFFBF2DC),
    mood5Night: Color(0xFFFDE9DC),
    bubbleCheek: Color(0xFFFF8F7D),
    bubbleTear: Color(0xFF8FC1EF),
    bubbleShine: Color(0xFFFFFFFF),
    hero: Color(0xFF1D5F6B),
    heroWave1: Color(0xFF2A7480),
    heroWave2: Color(0xFF3B8B93),
    onHero: Color(0xFFFFFFFF),
    onHeroMuted: Color(0xFFD5EBEA),
    sky: Color(0xFFCFE9EC),
    onSky: Color(0xFF0F3F48),
    sea: Color(0xFF3B8B93),
    sun: Color(0xFFFDD77A),
    moon: Color(0xFFFDF0CF),
    sand: Color(0xFFF6E4BD),
    onSand: Color(0xFF6B5320),
    brand: Color(0xFF1D5F6B),
    onBrand: Color(0xFFFFFFFF),
    brandAccent: Color(0xFFE2B55A),
  );

  static const dark = TidemarkColors(
    surface: Color(0xFF0C1719),
    surfaceRaised: Color(0xFF15252A),
    ink: Color(0xFFE6EFED),
    inkMuted: Color(0xFFB4C5C5),
    line: Color(0xFF7D9599),
    tide: Color(0xFF7CC5C9),
    onTide: Color(0xFF0A2226),
    tideSoft: Color(0xFF1E383C),
    danger: Color(0xFFF39582),
    mood1: Color(0xFF5868AD),
    mood2: Color(0xFF6B93D3),
    mood3: Color(0xFF62B3A5),
    mood4: Color(0xFFF0B84A),
    mood5: Color(0xFFF78B52),
    mood1Soft: Color(0xFFDFE3F6),
    mood2Soft: Color(0xFFDDE9F9),
    mood3Soft: Color(0xFFD9F1EB),
    mood4Soft: Color(0xFFFDF0CF),
    mood5Soft: Color(0xFFFFE2D1),
    onMood: Color(0xFF14262B),
    mood1Night: Color(0xFF1A2136),
    mood2Night: Color(0xFF172536),
    mood3Night: Color(0xFF142A29),
    mood4Night: Color(0xFF2C271C),
    mood5Night: Color(0xFF30231D),
    bubbleCheek: Color(0xFFFF8F7D),
    bubbleTear: Color(0xFF8FC1EF),
    bubbleShine: Color(0xFFFFFFFF),
    hero: Color(0xFF0F3A41),
    heroWave1: Color(0xFF13454C),
    heroWave2: Color(0xFF185058),
    onHero: Color(0xFFFFFFFF),
    onHeroMuted: Color(0xFFC9DFDF),
    sky: Color(0xFF0F2D3D),
    onSky: Color(0xFFE6EFED),
    sea: Color(0xFF1D5F6B),
    sun: Color(0xFFFDD77A),
    moon: Color(0xFFFDF0CF),
    sand: Color(0xFF3A3222),
    onSand: Color(0xFFE8D9B5),
    brand: Color(0xFF1D5F6B),
    onBrand: Color(0xFFFFFFFF),
    brandAccent: Color(0xFFE2B55A),
  );

  /// Fond de chaque écran : sable clair, plus chaud qu'en v1.
  final Color surface;

  /// Cartes d'entrée, feuilles, champs de texte posés sur `surface`.
  final Color surfaceRaised;

  /// Texte principal sur `surface`, `surface-raised` et `tide-soft`.
  final Color ink;

  /// Texte secondaire (dates, aides, légendes) sur `surface` et `surface-raised`.
  final Color inkMuted;

  /// Bordure des champs et des contrôles, séparateurs utiles, icône d'une flèche désactivée. Au moins 3:1 sur `surface` et `surface-raised`.
  final Color line;

  /// Couleur d'action : bouton principal, lien, anneau de focus, élément sélectionné. Texte en `tide` lisible sur `surface`, `surface-raised` et `tide-soft`.
  final Color tide;

  /// Texte et icône posés sur un fond `tide`.
  final Color onTide;

  /// Fond d'une puce d'étiquette ou d'une option sélectionnée ; texte en `ink` ou `tide` dessus.
  final Color tideSoft;

  /// Message d'erreur et action destructrice (suppression totale), toujours avec un libellé explicite. Jamais pour l'écran d'aide.
  final Color danger;

  /// Eau d'une bulle d'humeur 1 (très basse), coquillage. Identique dans les deux thèmes.
  final Color mood1;

  /// Eau d'une bulle d'humeur 2 (basse), coquillage. Identique dans les deux thèmes.
  final Color mood2;

  /// Eau d'une bulle d'humeur 3 (neutre), coquillage. Identique dans les deux thèmes.
  final Color mood3;

  /// Eau d'une bulle d'humeur 4 (bonne), coquillage. Identique dans les deux thèmes.
  final Color mood4;

  /// Eau d'une bulle d'humeur 5 (très bonne), coquillage. Identique dans les deux thèmes.
  final Color mood5;

  /// Fond d'une bulle d'humeur 1, d'une carte d'entrée ; texte en `on-mood`.
  final Color mood1Soft;

  /// Fond d'une bulle d'humeur 2, d'une carte d'entrée ; texte en `on-mood`.
  final Color mood2Soft;

  /// Fond d'une bulle d'humeur 3, d'une carte d'entrée ; texte en `on-mood`.
  final Color mood3Soft;

  /// Fond d'une bulle d'humeur 4, d'une carte d'entrée ; texte en `on-mood`.
  final Color mood4Soft;

  /// Fond d'une bulle d'humeur 5, d'une carte d'entrée ; texte en `on-mood`.
  final Color mood5Soft;

  /// Texte, visage et icône posés sur `mood-*` ou `mood-*-soft`, dans les deux thèmes.
  final Color onMood;

  /// Fond de l'écran de saisie quand l'humeur 1 est choisie ; texte en `ink`.
  final Color mood1Night;

  /// Fond de l'écran de saisie quand l'humeur 2 est choisie ; texte en `ink`.
  final Color mood2Night;

  /// Fond de l'écran de saisie quand l'humeur 3 est choisie ; texte en `ink`.
  final Color mood3Night;

  /// Fond de l'écran de saisie quand l'humeur 4 est choisie ; texte en `ink`.
  final Color mood4Night;

  /// Fond de l'écran de saisie quand l'humeur 5 est choisie ; texte en `ink`.
  final Color mood5Night;

  /// Joues des bulles 4 et 5.
  final Color bubbleCheek;

  /// Larme de la bulle 1.
  final Color bubbleTear;

  /// Reflet d'une bulle, écume des vagues, étincelle.
  final Color bubbleShine;

  /// Fond de l'en-tête de l'accueil (mer) et de la célébration ; texte en `on-hero`.
  final Color hero;

  /// Vague lointaine de l'en-tête.
  final Color heroWave1;

  /// Vague proche de l'en-tête.
  final Color heroWave2;

  /// Texte sur `hero`.
  final Color onHero;

  /// Texte secondaire sur `hero`.
  final Color onHeroMuted;

  /// Ciel de l'en-tête du bilan et de la bienvenue ; texte en `on-sky`.
  final Color sky;

  /// Texte sur `sky`.
  final Color onSky;

  /// Mer de la plage et de l'en-tête du bilan.
  final Color sea;

  /// Soleil (jour).
  final Color sun;

  /// Lune et étoiles (soir).
  final Color moon;

  /// Sable de la plage ; texte en `on-sand`.
  final Color sand;

  /// Texte sur `sand`.
  final Color onSand;

  /// Tuile du logo, identique dans les deux thèmes (spec 007).
  final Color brand;

  /// Vague et jambage du logo sur `brand` (spec 007).
  final Color onBrand;

  /// Point de la laisse du logo, sur `brand` (spec 007).
  final Color brandAccent;

  /// Eau de la bulle de l'humeur [mood], de 1 à 5.
  Color moodColor(int mood) => _pick(mood, [mood1, mood2, mood3, mood4, mood5]);

  /// Fond de la bulle et de la carte de l'humeur [mood].
  Color moodSoftColor(int mood) =>
      _pick(mood, [mood1Soft, mood2Soft, mood3Soft, mood4Soft, mood5Soft]);

  /// Fond de l'écran de saisie quand l'humeur [mood] est choisie.
  Color moodNightColor(int mood) =>
      _pick(mood, [mood1Night, mood2Night, mood3Night, mood4Night, mood5Night]);

  static Color _pick(int mood, List<Color> colors) {
    if (mood < 1 || mood > 5) throw RangeError.range(mood, 1, 5, 'mood');
    return colors[mood - 1];
  }

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
    'mood-1-soft': mood1Soft,
    'mood-2-soft': mood2Soft,
    'mood-3-soft': mood3Soft,
    'mood-4-soft': mood4Soft,
    'mood-5-soft': mood5Soft,
    'on-mood': onMood,
    'mood-1-night': mood1Night,
    'mood-2-night': mood2Night,
    'mood-3-night': mood3Night,
    'mood-4-night': mood4Night,
    'mood-5-night': mood5Night,
    'bubble-cheek': bubbleCheek,
    'bubble-tear': bubbleTear,
    'bubble-shine': bubbleShine,
    'hero': hero,
    'hero-wave-1': heroWave1,
    'hero-wave-2': heroWave2,
    'on-hero': onHero,
    'on-hero-muted': onHeroMuted,
    'sky': sky,
    'on-sky': onSky,
    'sea': sea,
    'sun': sun,
    'moon': moon,
    'sand': sand,
    'on-sand': onSand,
    'brand': brand,
    'on-brand': onBrand,
    'brand-accent': brandAccent,
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
