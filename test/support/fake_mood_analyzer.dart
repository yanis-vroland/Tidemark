import 'package:tidemark/analysis/mood_analyzer.dart';

/// Implémentation factice, déterministe, pour les tests et la CI : elle n'exécute
/// aucun modèle. Elle rend le résultat prévu pour un texte, ou [fallback].
class FakeMoodAnalyzer implements MoodAnalyzer {
  FakeMoodAnalyzer({this.results = const {}, this.fallback = const Untagged()});

  /// Résultat prévu pour chaque texte.
  final Map<String, AnalysisResult> results;
  final AnalysisResult fallback;

  /// Textes reçus, dans l'ordre, pour vérifier ce qui a été transmis au modèle.
  final List<String> received = [];

  @override
  Future<AnalysisResult> analyze(String text) async {
    received.add(text);
    return results[text] ?? fallback;
  }
}
