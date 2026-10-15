import 'dart:async';

import 'package:flutter/foundation.dart';

import '../distress/distress_detector.dart';
import '../entries/entry.dart';
import '../entries/entry_repository.dart';
import '../model/model_downloader.dart';
import '../model/model_state.dart';
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
/// est prêt. Elle observe les entrées et l'état du modèle : un enregistrement, la
/// fin d'un téléchargement ou le démarrage la relancent d'eux-mêmes.
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

  int? _current;
  AnalysisQueueState _state = AnalysisQueueState.idle;
  StreamSubscription<ModelState>? _model;
  StreamSubscription<List<Entry>>? _entries;
  bool _modelReady = false;
  bool _prepared = false;
  bool _running = false;
  bool _again = false;
  bool _stopped = false;
  Completer<void> _done = Completer<void>()..complete();

  /// Entrée en cours d'analyse, ou `null`.
  int? get currentEntryId => _current;

  AnalysisQueueState get state => _state;

  /// Écoute les entrées et l'état du modèle, et lance les analyses.
  void start() {
    _model ??= downloader.watch().listen((model) {
      _modelReady = model is ModelReady;
      _kick();
    });
    _entries ??= repository.watchEntries().listen(
      (_) => _kick(),
      onError: (Object _) {},
    );
  }

  /// Se termine quand plus rien n'est à analyser pour l'instant (tests).
  Future<void> get whenIdle async {
    // Laisse arriver les événements des flux observés.
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    while (_running) {
      await _done.future;
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Arrête la file, et la génération en cours.
  Future<void> stop() async {
    _stopped = true;
    await _model?.cancel();
    await _entries?.cancel();
    if (_running) {
      await analyzer.cancel();
      await _done.future;
    }
    if (_prepared) {
      _prepared = false;
      await analyzer.release();
    }
  }

  void _setState(AnalysisQueueState state, {int? current}) {
    _state = state;
    _current = current;
    notifyListeners();
  }

  void _kick() {
    if (_stopped || !_modelReady) return;
    if (_state == AnalysisQueueState.unavailable) return;
    if (_running) {
      _again = true;
      return;
    }
    unawaited(_run());
  }

  Future<void> _run() async {
    _running = true;
    _done = Completer<void>();
    try {
      while (!_stopped && _modelReady) {
        final List<Entry> pending;
        try {
          pending = await repository.pendingEntriesWithText();
        } catch (_) {
          break;
        }
        if (pending.isEmpty) break;
        // La plus récente d'abord : celle qu'on vient d'écrire passe devant (CA13).
        pending.sort((a, b) {
          final byTime = b.createdAt.compareTo(a.createdAt);
          return byTime != 0 ? byTime : b.id.compareTo(a.id);
        });
        final entry = pending.first;
        final text = entry.text!;
        // Défense en profondeur (spec 002) : aucune entrée en détresse n'atteint
        // le modèle, même si la vérification au démarrage a échoué (RM8, CA7).
        if (detector.detectInText(text)) {
          try {
            await repository.markSkipped([entry.id]);
          } catch (_) {
            break;
          }
          continue;
        }
        if (!_prepared) {
          if (!await analyzer.prepare()) {
            await _onLoadFailure();
            break;
          }
          _prepared = true;
        }
        _setState(AnalysisQueueState.running, current: entry.id);
        final result = await _analyze(text);
        _setState(AnalysisQueueState.idle);
        // Interrompue : l'entrée reste « en attente » (spec 004, « Interruption »).
        if (_stopped) break;
        try {
          await repository.saveAnalysis(entry.id, result);
        } catch (_) {
          // Écriture impossible : l'entrée reste « en attente » (CA8).
          break;
        }
      }
    } finally {
      // Modèle libéré quand la file est vide : la mémoire revient au téléphone.
      if (_prepared && !_stopped) {
        _prepared = false;
        await analyzer.release();
      }
      _running = false;
      _done.complete();
      if (_again) {
        _again = false;
        _kick();
      }
    }
  }

  /// Analyse avec un délai : au-delà, la génération est arrêtée et la file attend
  /// que l'analyseur rende la main avant d'aller plus loin (CA9, CA14).
  Future<AnalysisResult> _analyze(String text) async {
    final analysis = analyzer.analyze(text);
    try {
      return await analysis.timeout(timeout);
    } on TimeoutException {
      await analyzer.cancel();
      try {
        await analysis;
      } catch (_) {}
      return const Untagged();
    } catch (_) {
      return const Untagged();
    }
  }

  /// Modèle impossible à charger (CA15) : empreinte recalculée ; juste, la file
  /// est « indisponible » jusqu'au démarrage suivant ; fausse, le modèle redevient
  /// absent et un nouveau téléchargement la relancera.
  Future<void> _onLoadFailure() async {
    try {
      await downloader.verifyAfterLoadFailure();
    } catch (_) {}
    if (downloader.current is ModelReady) {
      _setState(AnalysisQueueState.unavailable);
    }
  }
}
