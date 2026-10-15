import 'dart:io';

import 'mood_analyzer.dart';

/// Consigne fixe passée au modèle (spec 004, « Ce qui est envoyé au modèle »).
const analysisInstruction =
    'Tu étiquettes une entrée de journal d\'humeur écrite en français. Choisis de '
    '0 à 3 émotions et de 0 à 2 thèmes, uniquement dans les listes autorisées, et '
    'au moins une étiquette en tout. Ne donne aucun conseil. Réponds seulement par '
    'l\'objet JSON demandé.';

/// [MoodAnalyzer] sur `llamadart` 0.12.0 (ADR-001). Jamais exécuté par les tests ni
/// par la CI : vérifié au test humain.
class LlamaMoodAnalyzer implements MoodAnalyzer {
  LlamaMoodAnalyzer({required this.modelFile, this.gpuLayers});

  /// Fichier GGUF du modèle local (spec 003).
  final File modelFile;

  /// Couches sur le GPU ; `null` : GPU sur iOS, processeur seul ailleurs.
  final int? gpuLayers;

  @override
  Future<bool> prepare() => throw UnimplementedError();

  @override
  Future<AnalysisResult> analyze(String text) => throw UnimplementedError();

  @override
  Future<void> cancel() => throw UnimplementedError();

  @override
  Future<void> release() => throw UnimplementedError();
}
