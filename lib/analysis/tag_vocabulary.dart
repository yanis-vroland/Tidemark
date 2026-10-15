/// Liste fermée des étiquettes (glossaire : `Tag`, spec 004, RM19, RM33). Reprise à
/// l'identique du bloc « Liste fermée des étiquettes » de la spec : un test le
/// vérifie.
abstract final class TagVocabulary {
  /// Émotions, dans l'ordre de la spec.
  static const emotions = <String>[];

  /// Thèmes, dans l'ordre de la spec.
  static const themes = <String>[];

  /// Schéma JSON de la sortie, passé au moteur ; ses listes `enum` sont tirées
  /// de [emotions] et [themes].
  static Map<String, Object?> get outputSchema => throw UnimplementedError();
}
