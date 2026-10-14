import '../distress/distress_detector.dart';

/// Réglages de la personne (glossaire : `SettingsRepository`, spec 002).
abstract interface class SettingsRepository {
  /// Degré de sensibilité choisi, `normal` si rien n'est choisi, mis à jour à chaque
  /// changement.
  Stream<LowMoodSensitivity> watchLowMoodSensitivity();

  /// Degré de sensibilité actuel, `normal` si rien n'est choisi.
  Future<LowMoodSensitivity> readLowMoodSensitivity();

  /// Enregistre le degré choisi.
  Future<void> setLowMoodSensitivity(LowMoodSensitivity sensitivity);
}
