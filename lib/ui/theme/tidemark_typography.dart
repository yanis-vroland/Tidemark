import 'package:flutter/painting.dart';

/// Styles de texte de la charte (docs/maquettes/000-charte/tokens.json, `type.groups`).
///
/// Les polices sont variables et embarquées (assets/fonts, licence OFL) : la graisse
/// passe par [FontVariation], que les polices variables lisent, et par [FontWeight]
/// pour le repli. Aucune police n'est chargée depuis le réseau (RM1).
abstract final class TidemarkTypography {
  static const String displayFamily = 'BricolageGrotesque';
  static const String bodyFamily = 'Figtree';

  static TextStyle _style(
    String family,
    double size,
    double lineHeight,
    int weight, {
    double letterSpacing = 0,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    height: lineHeight / size,
    fontWeight: FontWeight.values.firstWhere((w) => w.value == weight),
    fontVariations: [FontVariation.weight(weight.toDouble())],
    letterSpacing: letterSpacing,
  );

  static final display = _style(displayFamily, 40, 44, 800, letterSpacing: -1);
  static final title = _style(displayFamily, 22, 28, 700);

  /// Chiffre d'un autocollant du bilan (spec 008).
  static final stat = _style(displayFamily, 30, 34, 800);
  static final headline = _style(bodyFamily, 17, 24, 600);
  static final body = _style(bodyFamily, 16, 24, 400);
  static final button = _style(bodyFamily, 17, 20, 700);
  static final label = _style(bodyFamily, 14, 20, 600, letterSpacing: 0.1);

  /// Texte d'un autocollant (spec 008).
  static final sticker = _style(bodyFamily, 15, 20, 700);
  static final caption = _style(bodyFamily, 13, 18, 400);

  /// Styles indexés par le nom du jeton, pour les tests de fidélité.
  static final Map<String, TextStyle> tokens = {
    'display': display,
    'title': title,
    'stat': stat,
    'headline': headline,
    'body': body,
    'button': button,
    'label': label,
    'sticker': sticker,
    'caption': caption,
  };
}
