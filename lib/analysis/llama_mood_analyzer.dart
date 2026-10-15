import 'dart:io';

import 'package:llamadart/llamadart.dart' as llama;

import 'mood_analyzer.dart';
import 'tag_output_parser.dart';
import 'tag_vocabulary.dart';

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

  /// Couches sur le GPU ; `null` : GPU sur iOS, processeur seul ailleurs (ADR-001 :
  /// l'accélération GPU n'est pas vérifiée sur Android).
  final int? gpuLayers;

  llama.LlamaEngine? _engine;

  int get _layers => gpuLayers ?? (Platform.isIOS ? 99 : 0);

  @override
  Future<bool> prepare() async {
    if (_engine != null) return true;
    final engine = llama.LlamaEngine(llama.LlamaBackend());
    try {
      // Chemin local seulement : `llamadart` n'ouvre aucune connexion (ADR-001).
      await engine.setModel(
        llama.LlamaModel(llama.ModelSource.path(modelFile.path)),
        params: llama.ModelParams(gpuLayers: _layers),
      );
      _engine = engine;
      return true;
    } catch (_) {
      await engine.dispose();
      return false;
    }
  }

  @override
  Future<AnalysisResult> analyze(String text) async {
    final engine = _engine;
    if (engine == null) return const Untagged();
    try {
      // Une session neuve par entrée : aucun historique partagé entre entrées.
      final session = llama.ChatSession(
        engine,
        systemPrompt: analysisInstruction,
      );
      final completion = await session.send(
        text,
        params: const llama.GenerationParams(maxTokens: 128, temp: 0.2),
        enableThinking: false,
        responseFormat: {
          'type': 'json_schema',
          'json_schema': {'schema': TagVocabulary.outputSchema},
        },
      );
      // La sortie brute n'est ni gardée, ni affichée, ni journalisée (RM9).
      return TagOutputParser.parse(completion.text);
    } catch (_) {
      return const Untagged();
    }
  }

  @override
  Future<void> cancel() async => _engine?.cancelGeneration();

  @override
  Future<void> release() async {
    final engine = _engine;
    _engine = null;
    await engine?.dispose();
  }
}
