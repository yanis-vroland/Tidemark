import 'dart:io';

import 'package:llamadart/llamadart.dart' as llama;

import '../analysis/llama_mood_analyzer.dart' show silenceLlamaLogs;

import 'review_writer.dart';
import 'weekly_review.dart';

/// [ReviewWriter] sur `llamadart` 0.12.0 (ADR-001), même modèle que l'étiquetage.
/// Charge le modèle pour une mise en mots et le libère aussitôt après : l'accès
/// exclusif au modèle est tenu par `GatedReviewWriter` (ADR-005). Jamais exécuté
/// par les tests ni par la CI : vérifié au test humain.
class LlamaReviewWriter implements ReviewWriter {
  LlamaReviewWriter({
    required this.modelFile,
    this.gpuLayers,
    this.silenceLogs = silenceLlamaLogs,
  });

  /// Fichier GGUF du modèle local (spec 003).
  final File modelFile;

  /// Couches sur le GPU ; `null` : GPU sur iOS, processeur seul ailleurs (ADR-001).
  final int? gpuLayers;

  llama.LlamaEngine? _engine;
  bool _cancelled = false;

  /// Fixe les journaux de `llamadart` à `none` ; remplacé dans les tests.
  final Future<void> Function() silenceLogs;

  int get _layers => gpuLayers ?? (Platform.isIOS ? 99 : 0);

  @override
  Future<ReviewDraft> write(ReviewFacts facts) async {
    _cancelled = false;
    // Journaux de `llamadart` à `none` avant tout chargement (ADR-004, décision 4).
    // Échec : aucun chargement, comme l'analyseur (RM9, RM53).
    try {
      await silenceLogs();
    } catch (_) {
      return const WriterFailed();
    }
    if (!modelFile.existsSync()) return const ModelMissing();
    final engine = llama.LlamaEngine(llama.LlamaBackend());
    _engine = engine;
    try {
      // Chemin local seulement : `llamadart` n'ouvre aucune connexion (ADR-001).
      await engine.setModel(
        llama.LlamaModel(llama.ModelSource.path(modelFile.path)),
        params: llama.ModelParams(gpuLayers: _layers),
      );
      if (_cancelled) return const WriterFailed();
      // Une session neuve à chaque bilan : aucun historique, aucune entrée.
      final session = llama.ChatSession(
        engine,
        systemPrompt: reviewInstruction,
      );
      final completion = await session.send(
        facts.toPrompt(),
        params: const llama.GenerationParams(
          maxTokens: reviewMaxTokens,
          temp: reviewTemperature,
        ),
        enableThinking: false,
        responseFormat: {
          'type': 'json_schema',
          'json_schema': {'schema': reviewOutputSchema},
        },
      );
      if (_cancelled) return const WriterFailed();
      // Sortie brute, validée par l'appelant ; jamais journalisée (RM53).
      return RawReview(completion.text);
    } catch (_) {
      return const WriterFailed();
    } finally {
      _engine = null;
      await engine.dispose();
    }
  }

  /// Arrête la génération ; [write] rend alors [WriterFailed] une fois le moteur
  /// libéré. Le chargement du modèle, lui, ne s'interrompt pas : l'abandon prend
  /// effet juste après.
  @override
  Future<void> cancel() async {
    _cancelled = true;
    _engine?.cancelGeneration();
  }
}
