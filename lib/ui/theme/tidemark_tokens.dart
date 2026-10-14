/// Espacements, rayons et tailles de la charte (docs/maquettes/000-charte/tokens.json),
/// en points logiques, nommés comme les jetons en camelCase.
abstract final class TidemarkSpacing {
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space6 = 24;
  static const double space8 = 32;

  static const Map<String, double> tokens = {
    'space-1': space1,
    'space-2': space2,
    'space-3': space3,
    'space-4': space4,
    'space-6': space6,
    'space-8': space8,
  };
}

abstract final class TidemarkRadius {
  static const double radiusSm = 8;
  static const double radiusMd = 16;
  static const double radiusPill = 999;

  static const Map<String, double> tokens = {
    'radius-sm': radiusSm,
    'radius-md': radiusMd,
    'radius-pill': radiusPill,
  };
}

abstract final class TidemarkSize {
  /// Taille minimale de toute cible tactile.
  static const double tapMin = 44;

  /// Diamètre d'une pastille du sélecteur d'humeur.
  static const double moodDot = 56;

  static const Map<String, double> tokens = {
    'tap-min': tapMin,
    'mood-dot': moodDot,
  };
}
