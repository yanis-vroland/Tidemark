import 'dart:io';

import 'review_writer.dart';
import 'weekly_review.dart';

/// [ReviewWriter] sur `llamadart` 0.12.0 (ADR-001), même modèle que l'étiquetage.
/// Jamais exécuté par les tests ni par la CI : vérifié au test humain.
class LlamaReviewWriter implements ReviewWriter {
  LlamaReviewWriter({required this.modelFile, this.gpuLayers});

  /// Fichier GGUF du modèle local (spec 003).
  final File modelFile;

  /// Couches sur le GPU ; `null` : GPU sur iOS, processeur seul ailleurs (ADR-001).
  final int? gpuLayers;

  @override
  Future<ReviewDraft> write(ReviewFacts facts) => throw UnimplementedError();

  @override
  Future<void> cancel() => throw UnimplementedError();
}
