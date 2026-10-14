/// Moteur d'inférence comparé par le spike. Le futur `MoodAnalyzer` de l'app
/// reposera sur l'un d'eux ; ici, seule la génération de texte brut compte.
abstract class SpikeEngine {
  String get name;

  /// Charge le modèle depuis un fichier présent sur l'appareil.
  Future<void> load(String modelPath);

  /// Génère la réponse au prompt, sans état partagé entre deux appels.
  Future<String> generate(String prompt);

  Future<void> dispose();
}
