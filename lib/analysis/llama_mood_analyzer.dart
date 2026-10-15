import 'dart:async';
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

/// Moteur chargé, vu par [LlamaMoodAnalyzer] : la seule couture avec `llamadart`,
/// pour que la logique de l'analyseur (annulation, CA35) soit testée sur un moteur
/// factice, sans jamais charger de modèle.
abstract interface class LocalEngine {
  /// Génère la réponse au [text] d'une entrée, avec la consigne et le schéma de la
  /// spec 004. Peut lever (erreur du moteur, GPU refusé).
  Future<String> generate(String text);

  /// Demande l'arrêt de la génération en cours, sans l'attendre.
  void cancelGeneration();

  /// Libère le modèle et sa mémoire.
  Future<void> dispose();
}

/// Charge le modèle de [modelFile] avec [gpuLayers] couches sur le GPU ; lève s'il
/// ne peut pas l'être.
typedef LocalEngineLoader = Future<LocalEngine> Function(
  File modelFile,
  int gpuLayers,
);

/// [LocalEngineLoader] sur `llamadart` 0.12.0 (ADR-001). Jamais exécuté par les tests
/// ni par la CI : vérifié au test humain.
Future<LocalEngine> loadLlamadartEngine(File modelFile, int gpuLayers) async {
  final engine = llama.LlamaEngine(llama.LlamaBackend());
  try {
    // Chemin local seulement : `llamadart` n'ouvre aucune connexion (ADR-001).
    await engine.setModel(
      llama.LlamaModel(llama.ModelSource.path(modelFile.path)),
      params: llama.ModelParams(gpuLayers: gpuLayers),
    );
    return _LlamadartEngine(engine);
  } catch (_) {
    await engine.dispose();
    rethrow;
  }
}

class _LlamadartEngine implements LocalEngine {
  _LlamadartEngine(this._engine);

  final llama.LlamaEngine _engine;

  @override
  Future<String> generate(String text) async {
    // Une session neuve par entrée : aucun historique partagé entre entrées.
    final session = llama.ChatSession(
      _engine,
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
    return completion.text;
  }

  @override
  void cancelGeneration() => _engine.cancelGeneration();

  @override
  Future<void> dispose() => _engine.dispose();
}

/// [MoodAnalyzer] sur un [LocalEngine], par défaut `llamadart` 0.12.0 (ADR-001).
class LlamaMoodAnalyzer implements MoodAnalyzer {
  LlamaMoodAnalyzer({
    required this.modelFile,
    this.gpuLayers,
    this.loader = loadLlamadartEngine,
    this.cancelGrace = const Duration(seconds: 5),
  });

  /// Fichier GGUF du modèle local (spec 003).
  final File modelFile;

  /// Couches sur le GPU ; `null` : GPU sur iOS, processeur seul ailleurs (ADR-001 :
  /// l'accélération GPU n'est pas vérifiée sur Android).
  final int? gpuLayers;

  /// Chargement du moteur ; un moteur factice dans les tests.
  final LocalEngineLoader loader;

  /// Attente maximale de la fin de la génération par [cancel], avant de libérer le
  /// moteur (CA35).
  final Duration cancelGrace;

  LocalEngine? _engine;

  /// Génération en cours, et son abandon par [cancel] quand le moteur ne rend pas
  /// la main à temps (CA35).
  Future<AnalysisResult>? _generation;
  Completer<AnalysisResult>? _abandon;

  int get _layers => gpuLayers ?? (Platform.isIOS ? 99 : 0);

  @override
  Future<bool> prepare() async {
    if (_engine != null) return true;
    try {
      _engine = await loader(modelFile, _layers);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AnalysisResult> analyze(String text) async {
    final engine = _engine;
    if (engine == null) return const Untagged();
    final generation = _generate(engine, text);
    final abandon = Completer<AnalysisResult>();
    _generation = generation;
    _abandon = abandon;
    try {
      return await Future.any([generation, abandon.future]);
    } finally {
      if (identical(_generation, generation)) {
        _generation = null;
        _abandon = null;
      }
    }
  }

  Future<AnalysisResult> _generate(LocalEngine engine, String text) async {
    try {
      // La sortie brute n'est ni gardée, ni affichée, ni journalisée (RM9).
      return TagOutputParser.parse(await engine.generate(text));
    } catch (_) {
      return const Untagged();
    }
  }

  /// Demande l'arrêt au moteur et attend la fin de la génération, [cancelGrace] au
  /// plus ; au-delà, le moteur est libéré, l'analyse rend [Untagged], et
  /// [prepare] le rechargera (spec 004, « Délai », CA35).
  @override
  Future<void> cancel() async {
    final generation = _generation;
    final engine = _engine;
    if (generation == null || engine == null) return;
    try {
      engine.cancelGeneration();
    } catch (_) {}
    try {
      await generation.timeout(cancelGrace);
    } on TimeoutException {
      final abandon = _abandon;
      if (abandon != null && !abandon.isCompleted) {
        abandon.complete(const Untagged());
      }
      try {
        await release();
      } catch (_) {}
    }
  }

  @override
  Future<void> release() async {
    final engine = _engine;
    _engine = null;
    await engine?.dispose();
  }
}
