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

  /// Pastille d'humeur d'une carte d'entrée.
  static const double moodDotSm = 40;

  /// Pastille d'humeur du détail.
  static const double moodDotLg = 72;

  /// Hauteur des boutons pleine largeur.
  static const double buttonHeight = 52;

  /// Petite icône devant une mention.
  static const double iconSm = 16;

  /// Icône de navigation ou d'action seule (Réglages, retour).
  static const double iconMd = 24;

  /// Icône posée dans un bouton, devant son libellé.
  static const double iconButton = 18;

  /// Hauteur de la barre de progression du téléchargement du modèle.
  static const double progressHeight = 8;

  /// Anneau autour de la pastille choisie, et écart qui l'en sépare.
  static const double ringWidth = 3;

  /// Épaisseur d'une barre de la répartition des humeurs (spec 006).
  static const double barThickness = 8;

  /// Hauteur d'une case de jour dans « Jours notés » (spec 006).
  static const double dayCell = 40;

  static const Map<String, double> tokens = {
    'tap-min': tapMin,
    'mood-dot': moodDot,
    'mood-dot-sm': moodDotSm,
    'mood-dot-lg': moodDotLg,
    'button-height': buttonHeight,
    'icon-sm': iconSm,
    'icon-md': iconMd,
    'icon-button': iconButton,
    'progress-height': progressHeight,
    'ring-width': ringWidth,
    'bar-thickness': barThickness,
    'day-cell': dayCell,
  };
}

abstract final class TidemarkOpacity {
  /// Pastilles non choisies quand une humeur est choisie.
  static const double moodDimmed = 0.55;

  static const Map<String, double> tokens = {'mood-dimmed': moodDimmed};
}
