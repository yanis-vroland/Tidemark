import 'package:flutter/foundation.dart';

import '../distress/distress_detector.dart';
import '../entries/entry_repository.dart';
import '../model/model_downloader.dart';
import 'mood_analyzer.dart';

/// État de la file d'analyse (spec 004).
enum AnalysisQueueState {
  /// Rien à analyser, ou modèle absent.
  idle,

  /// Une entrée est en cours d'analyse ([AnalysisQueue.currentEntryId]).
  running,

  /// Le modèle n'a pas pu être chargé alors que son empreinte est juste : rien
  /// jusqu'au démarrage suivant (CA15, CA31).
  unavailable,
}

/// File d'analyse (glossaire : `AnalysisQueue`, spec 004, RM34, RM35) : analyse les
/// entrées « en attente » une à la fois, la plus récente d'abord, quand le modèle
/// est prêt.
class AnalysisQueue extends ChangeNotifier {
  AnalysisQueue({
    required this.repository,
    required this.analyzer,
    required this.downloader,
    this.detector = const DistressDetector(),
    this.timeout = const Duration(seconds: 30),
  });

  final EntryRepository repository;
  final MoodAnalyzer analyzer;
  final ModelDownloader downloader;
  final DistressDetector detector;

  /// Durée maximale d'une analyse (CA9, CA14).
  final Duration timeout;

  /// Entrée en cours d'analyse, ou `null`.
  int? get currentEntryId => throw UnimplementedError();

  AnalysisQueueState get state => throw UnimplementedError();

  /// Écoute les entrées et l'état du modèle, et lance les analyses.
  void start() => throw UnimplementedError();

  /// Se termine quand plus rien n'est à analyser pour l'instant (tests).
  Future<void> get whenIdle => throw UnimplementedError();

  /// Arrête la file, et la génération en cours.
  Future<void> stop() => throw UnimplementedError();
}
