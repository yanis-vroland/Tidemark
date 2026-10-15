import 'dart:async';

import 'package:tidemark/analysis/mood_analyzer.dart';

/// Implémentation factice, déterministe, pour les tests et la CI : elle n'exécute
/// aucun modèle. Elle rend le résultat prévu pour un texte, ou [fallback].
class FakeMoodAnalyzer implements MoodAnalyzer {
  FakeMoodAnalyzer({
    this.results = const {},
    this.fallback = const Untagged(),
    this.prepareResult = true,
    this.delays = const {},
  });

  /// Résultat prévu pour chaque texte.
  final Map<String, AnalysisResult> results;
  final AnalysisResult fallback;

  /// Résultat de [prepare] : `false` simule un modèle impossible à charger.
  bool prepareResult;

  /// Durée de l'analyse par texte ; `null` : l'analyse ne se termine jamais d'elle-
  /// même, seulement par [cancel] (CA14).
  final Map<String, Duration?> delays;

  /// Textes reçus, dans l'ordre, pour vérifier ce qui a été transmis au modèle.
  final List<String> received = [];

  int prepareCalls = 0;
  int cancelCalls = 0;
  int releaseCalls = 0;

  /// Analyses en cours, et le plus grand nombre observé en même temps (CA14).
  int running = 0;
  int maxConcurrent = 0;

  Completer<void>? _pending;

  @override
  Future<bool> prepare() async {
    prepareCalls++;
    return prepareResult;
  }

  @override
  Future<AnalysisResult> analyze(String text) async {
    received.add(text);
    running++;
    if (running > maxConcurrent) maxConcurrent = running;
    try {
      if (delays.containsKey(text)) {
        final delay = delays[text];
        final pending = Completer<void>();
        _pending = pending;
        if (delay != null) {
          Timer(delay, () {
            if (!pending.isCompleted) pending.complete();
          });
        }
        await pending.future;
        if (_cancelled) {
          _cancelled = false;
          return const Untagged();
        }
      }
      return results[text] ?? fallback;
    } finally {
      running--;
    }
  }

  bool _cancelled = false;

  @override
  Future<void> cancel() async {
    cancelCalls++;
    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      _cancelled = true;
      pending.complete();
    }
  }

  @override
  Future<void> release() async => releaseCalls++;
}
