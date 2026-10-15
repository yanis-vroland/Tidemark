/// Liste fermée des étiquettes (glossaire : `Tag`, spec 004, RM19, RM33). Reprise à
/// l'identique du bloc « Liste fermée des étiquettes » de la spec : un test le
/// vérifie.
abstract final class TagVocabulary {
  /// Émotions, dans l'ordre de la spec.
  static const emotions = <String>[
    'joie',
    'calme',
    'gratitude',
    'fierté',
    'espoir',
    'tristesse',
    'anxiété',
    'colère',
    'fatigue',
    'solitude',
    'frustration',
    'ennui',
  ];

  /// Thèmes, dans l'ordre de la spec.
  static const themes = <String>[
    'travail',
    'études',
    'famille',
    'amis',
    'couple',
    'santé',
    'sommeil',
    'sport',
    'nature',
    'argent',
    'maison',
    'loisirs',
  ];

  /// Au plus 3 émotions et 2 thèmes par entrée (spec 004).
  static const maxEmotions = 3;
  static const maxThemes = 2;

  /// Schéma JSON de la sortie, passé au moteur ; ses listes `enum` sont tirées
  /// de [emotions] et [themes].
  static Map<String, Object?> get outputSchema => {
    'type': 'object',
    'properties': {
      'emotions': {
        'type': 'array',
        'items': {'enum': emotions},
        'minItems': 0,
        'maxItems': maxEmotions,
      },
      'themes': {
        'type': 'array',
        'items': {'enum': themes},
        'minItems': 0,
        'maxItems': maxThemes,
      },
    },
    'required': ['emotions', 'themes'],
    'additionalProperties': false,
  };
}
