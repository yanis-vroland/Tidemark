import 'package:flutter/painting.dart';

/// Espacements, rayons et tailles de la charte (docs/maquettes/000-charte/tokens.json),
/// en points logiques, nommés comme les jetons en camelCase. Les demi-pas
/// (`space-0-5`, `space-1-5`, `space-2-5`) prennent un `_` entre les chiffres.
abstract final class TidemarkSpacing {
  /// Sous le surtitre de l'en-tête de l'accueil.
  static const double space0_5 = 2;
  static const double space1 = 4;

  /// Petite icône et sa mention ; au-dessus du compteur de l'accueil.
  static const double space1_5 = 6;
  static const double space2 = 8;

  /// Logo et nom sur la bienvenue.
  static const double space2_5 = 10;
  static const double space3 = 12;
  static const double space4 = 16;

  /// Blocs de la bienvenue ; marge latérale de l'en-tête de l'accueil.
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;

  static const Map<String, double> tokens = {
    'space-0-5': space0_5,
    'space-1': space1,
    'space-1-5': space1_5,
    'space-2': space2,
    'space-2-5': space2_5,
    'space-3': space3,
    'space-4': space4,
    'space-5': space5,
    'space-6': space6,
    'space-8': space8,
  };
}

abstract final class TidemarkRadius {
  static const double radiusSm = 8;
  static const double radiusMd = 16;

  /// Cartes d'entrée, cartes de section, autocollants du bilan (spec 008).
  static const double radiusLg = 24;

  /// Carte du check-in, barre de navigation (spec 008).
  static const double radiusXl = 28;
  static const double radiusPill = 999;

  static const Map<String, double> tokens = {
    'radius-sm': radiusSm,
    'radius-md': radiusMd,
    'radius-lg': radiusLg,
    'radius-xl': radiusXl,
    'radius-pill': radiusPill,
  };
}

abstract final class TidemarkSize {
  /// Taille minimale de toute cible tactile.
  static const double tapMin = 44;

  /// Hauteur des boutons pleine largeur.
  static const double buttonHeight = 56;

  /// Bulle d'un jour sur la plage de la semaine (spec 009).
  static const double bubbleSm = 36;

  /// Bulle d'une carte d'entrée.
  static const double bubbleMd = 48;

  /// Bulle du check-in de l'accueil (spec 009).
  static const double bubbleCheck = 54;

  /// Bulle du sélecteur d'humeur.
  static const double bubbleSelect = 44;

  /// Bulle choisie du sélecteur.
  static const double bubbleSelectOn = 52;

  /// Bulle du détail d'une entrée.
  static const double bubbleLg = 120;

  /// Grande bulle de l'écran de saisie.
  static const double bubbleXl = 150;

  /// Bouton « Nouvelle entrée » de la barre de navigation (spec 009).
  static const double navBubble = 64;

  /// Petite icône devant une mention.
  static const double iconSm = 16;

  /// Icône de navigation ou d'action seule (Réglages, retour).
  static const double iconMd = 24;

  /// Icône posée dans un bouton, devant son libellé.
  static const double iconButton = 18;

  /// Hauteur de la barre de progression du téléchargement du modèle.
  static const double progressHeight = 8;

  /// Anneau autour de la bulle choisie, et écart qui l'en sépare.
  static const double ringWidth = 3;

  /// Épaisseur d'une barre de la répartition des humeurs (spec 006).
  static const double barThickness = 8;

  /// Hauteur d'une case de jour dans « Jours notés » (spec 006).
  static const double dayCell = 40;

  /// Logo sur l'état vide de la liste (spec 007).
  static const double logoMd = 64;

  /// Pastille du numéro d'une étape de la bienvenue : taille minimale, elle
  /// grandit avec le texte (spec 009, CA27).
  static const double stepBadge = 40;

  /// Largeur réservée au bouton « Nouvelle entrée » dans la barre de navigation.
  static const double navCreateSlot = 108;

  static const Map<String, double> tokens = {
    'tap-min': tapMin,
    'button-height': buttonHeight,
    'bubble-sm': bubbleSm,
    'bubble-md': bubbleMd,
    'bubble-check': bubbleCheck,
    'bubble-select': bubbleSelect,
    'bubble-select-on': bubbleSelectOn,
    'bubble-lg': bubbleLg,
    'bubble-xl': bubbleXl,
    'nav-bubble': navBubble,
    'icon-sm': iconSm,
    'icon-md': iconMd,
    'icon-button': iconButton,
    'progress-height': progressHeight,
    'ring-width': ringWidth,
    'bar-thickness': barThickness,
    'day-cell': dayCell,
    'logo-md': logoMd,
    'step-badge': stepBadge,
    'nav-create-slot': navCreateSlot,
  };
}

/// Ombres de la charte v2 (spec 008), identiques dans les deux thèmes.
abstract final class TidemarkShadows {
  /// Carte du check-in, barre de navigation.
  static const shadowCard = [
    BoxShadow(
      color: Color.fromRGBO(20, 38, 43, 0.12),
      offset: Offset(0, 12),
      blurRadius: 32,
    ),
  ];

  /// Autocollants.
  static const shadowSticker = [
    BoxShadow(color: Color.fromRGBO(20, 38, 43, 0.14), offset: Offset(0, 3)),
  ];

  /// Sous les boutons pleins : bouton en relief.
  static const shadowPress = [
    BoxShadow(color: Color.fromRGBO(10, 34, 38, 0.3), offset: Offset(0, 4)),
  ];

  /// Valeurs CSS de tokens.json, pour les tests de fidélité.
  static const Map<String, String> tokens = {
    'shadow-card': '0px 12px 32px rgba(20, 38, 43, 0.12)',
    'shadow-sticker': '0px 3px 0px rgba(20, 38, 43, 0.14)',
    'shadow-press': '0px 4px 0px rgba(10, 34, 38, 0.3)',
  };
}
