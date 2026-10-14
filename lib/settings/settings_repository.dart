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

/// Réglages fixes : degré `normal`, sans enregistrement possible. Valeur par défaut
/// des écrans construits sans réglages (tests de la spec 001) ; l'app démarrée
/// reçoit toujours les réglages de la base (`openJournal`).
class DefaultSettingsRepository implements SettingsRepository {
  const DefaultSettingsRepository();

  @override
  Stream<LowMoodSensitivity> watchLowMoodSensitivity() =>
      Stream.value(LowMoodSensitivity.normal);

  @override
  Future<LowMoodSensitivity> readLowMoodSensitivity() async =>
      LowMoodSensitivity.normal;

  @override
  Future<void> setLowMoodSensitivity(LowMoodSensitivity sensitivity) =>
      throw UnsupportedError('Réglages fixes : rien à enregistrer.');
}
