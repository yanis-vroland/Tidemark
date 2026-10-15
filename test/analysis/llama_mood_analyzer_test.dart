// Consigne de `LlamaMoodAnalyzer` (spec 004, « Ce qui est envoyé au modèle »). Le
// moteur n'est jamais exécuté par les tests : seule la consigne fixe est vérifiée,
// contre le texte de la spec. Le schéma passé au moteur est celui de
// `TagVocabulary.outputSchema` (test/analysis/tag_vocabulary_test.dart, CA1) ; les
// paramètres du moteur (température 0,2, 128 jetons, GPU sur iOS) ne sont pas exposés
// par l'interface publique et ne sont vérifiés qu'au test humain.
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/analysis/llama_mood_analyzer.dart';

import '../support/analysis_harness.dart';

void main() {
  test('la consigne fixe est celle de la spec, mot pour mot', () {
    expect(readSpec(), contains('« $analysisInstruction »'));
  });

  test('la consigne demande 0 à 3 émotions, 0 à 2 thèmes, au moins une '
      'étiquette, aucun conseil, et seulement l\'objet JSON', () {
    expect(analysisInstruction, contains('de 0 à 3 émotions'));
    expect(analysisInstruction, contains('de 0 à 2 thèmes'));
    expect(analysisInstruction, contains('au moins une étiquette'));
    expect(analysisInstruction, contains('Ne donne aucun conseil'));
    expect(analysisInstruction, contains('seulement par l\'objet JSON'));
  });
}
