import 'dart:async';
import 'dart:ui' show AppLifecycleState;

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

  /// Une entrée est en cours d'analyse ([AnalysisQueue.currentEntryId]), du
  /// chargement du modèle à l'écriture de son résultat.
  running,

  /// Le modèle n'a pas pu être chargé alors que son empreinte est juste : rien
  /// jusqu'au démarrage suivant (CA15, CA31).
  unavailable,
}

/// File d'analyse (glossaire : `AnalysisQueue`, spec 004, RM34, RM35) : analyse les
/// entrées « en attente » une à la fois, la plus récente d'abord, quand le modèle
/// est prêt et l'app au premier plan. Elle observe les entrées, l'état du modèle et
/// le cycle de vie de l'app : un enregistrement, la fin d'un téléchargement, le
/// démarrage ou le retour au premier plan la relancent d'eux-mêmes.
class AnalysisQueue extends ChangeNotifier {
  AnalysisQueue({
    required this.repository,
    required this.analyzer,
    required this.downloader,
    this.detector = const DistressDetector(),
    this.timeout = const Duration(seconds: 30),
    this.lifecycle,
  });

  final EntryRepository repository;
  final MoodAnalyzer analyzer;
  final ModelDownloader downloader;
  final DistressDetector detector;

  /// Durée maximale d'une analyse (CA9, CA14).
  final Duration timeout;

  /// Cycle de vie de l'app (CA32, CA33) ; `null` : non observé.
  final Stream<AppLifecycleState>? lifecycle;

  int? _current;
  AnalysisQueueState _state = AnalysisQueueState.idle;
  StreamSubscription<ModelState>? _model;
  StreamSubscription<List<Entry>>? _entries;
  StreamSubscription<AppLifecycleState>? _lifecycle;
  bool _modelReady = false;
  bool _prepared = false;
  bool _running = false;
  bool _analyzing = false;
  bool _again = false;
  bool _stopped = false;
  bool _background = false;
  Future<void>? _stopping;

  /// Entrées dont l'écriture du résultat (CA39) ou le marquage « non analysée »
  /// (CA40) a échoué : aux séries suivantes, elles passent après les autres. En
  /// mémoire seulement ; une écriture réussie les en retire.
  final Set<int> _failureOrder = <int>{}; // ordre d'échec (LinkedHashSet)

  /// L'écriture d'un résultat ou un marquage « non analysée » a échoué pendant
  /// ce passage : la file s'arrête jusqu'au prochain événement, sans tenir compte
  /// de ceux reçus pendant ce passage (CA39, CA40).
  bool _writeFailed = false;

  /// Nombre de mises en arrière-plan : un résultat obtenu pendant que ce nombre a
  /// changé vient d'une analyse interrompue (CA32, CA33).
  int _interruptions = 0;
  Completer<void> _done = Completer<void>()..complete();

  /// Complété par [stop] : la file n'attend pas la fin du calcul de l'empreinte
  /// (CA37).
  final Completer<void> _halted = Completer<void>();

  /// Entrée en cours d'analyse, ou `null`.
  int? get currentEntryId => _current;

  AnalysisQueueState get state => _state;

  /// Écoute les entrées, l'état du modèle et le cycle de vie, et lance les analyses.
  void start() {
    _lifecycle ??= lifecycle?.listen(_onLifecycle, onError: (Object _) {});
    _model ??= downloader.watch().listen((model) {
      _modelReady = model is ModelReady;
      _kick();
    });
    _entries ??= repository.watchEntries().listen(
      (_) => _kick(),
      onError: (Object _) {},
    );
  }

  /// Se termine quand plus rien n'est à analyser pour l'instant.
  @visibleForTesting
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

  /// Arrête la file, et la génération en cours. Le modèle est libéré par la file
  /// elle-même, une fois l'analyse terminée. Idempotent : un second appel, pendant
  /// le premier arrêt ou après, rend le même futur, sans refaire l'arrêt (CA34).
  Future<void> stop() => _stopping ??= _stop();

  Future<void> _stop() async {
    _stopped = true;
    if (!_halted.isCompleted) _halted.complete();
    await _lifecycle?.cancel();
    await _model?.cancel();
    await _entries?.cancel();
    await _cancelAnalysis();
    await _done.future;
    // Filet : rien ne tourne, mais le modèle serait resté chargé.
    await _release();
  }

  void _onLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // Sur iOS, le GPU est refusé en arrière-plan : la génération échouerait
        // et l'entrée deviendrait « sans étiquette » à tort (CA32).
        if (_background) return;
        _background = true;
        _interruptions++;
        unawaited(_cancelAnalysis());
      case AppLifecycleState.resumed:
        if (!_background) return;
        _background = false;
        _kick();
      case AppLifecycleState.inactive:
        // Centre de contrôle, appel entrant : le GPU reste permis.
        break;
    }
  }

  Future<void> _cancelAnalysis() async {
    if (!_analyzing) return;
    try {
      await analyzer.cancel();
    } catch (_) {}
  }

  Future<void> _release() async {
    if (!_prepared) return;
    _prepared = false;
    try {
      await analyzer.release();
    } catch (_) {
      // Libération impossible : la file reste utilisable (CA34).
    }
  }

  void _setState(AnalysisQueueState state, {int? current}) {
    _state = state;
    _current = current;
    notifyListeners();
  }

  bool get _canRun => !_stopped && !_background && _modelReady;

  void _kick() {
    if (!_canRun) return;
    if (_state == AnalysisQueueState.unavailable) return;
    if (_running) {
      _again = true;
      return;
    }
    unawaited(_run());
  }

  Future<void> _run() async {
    _running = true;
    _writeFailed = false;
    _done = Completer<void>();
    try {
      while (_canRun) {
        final List<Entry> pending;
        try {
          pending = await repository.pendingEntriesWithText();
        } catch (_) {
          break;
        }
        _failureOrder.retainAll(pending.map((e) => e.id));
        if (pending.isEmpty || !_canRun) break;
        // La plus récente d'abord : celle qu'on vient d'écrire passe devant (CA13) ;
        // celles dont l'écriture a échoué passent après les autres (CA36).
        // Entre deux entrées en échec, la plus anciennement en échec d'abord :
        // aucune n'est délaissée.
        final failures = _failureOrder.toList();
        pending.sort((a, b) {
          final byFailure = failures
              .indexOf(a.id)
              .compareTo(failures.indexOf(b.id));
          if (byFailure != 0) return byFailure;
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
            // Marquage impossible : l'entrée reste « en attente », sans jamais
            // atteindre le modèle ; même règle que l'écriture du résultat
            // impossible (RM57, CA40).
            _recordWriteFailure(entry.id);
            break;
          }
          // Marquage réussi : l'entrée n'est plus « en attente » et sort du rang.
          _failureOrder.remove(entry.id);
          continue;
        }
        // « En cours » dès le chargement du modèle, jusqu'à l'écriture du
        // résultat (spec 004, « Entrée en cours »).
        _setState(AnalysisQueueState.running, current: entry.id);
        try {
          if (!await _analyzeAndSave(entry.id, text)) break;
        } finally {
          if (_state == AnalysisQueueState.running) {
            _setState(AnalysisQueueState.idle);
          }
        }
      }
    } finally {
      // Modèle libéré quand la file est vide, arrêtée ou en arrière-plan : la
      // mémoire revient au téléphone.
      try {
        await _release();
      } finally {
        _running = false;
        _done.complete();
        // Après un échec d'écriture, les événements reçus pendant ce passage (dont
        // ceux de ses propres écritures) ne relancent pas la file : sinon, elle
        // reprendrait la même entrée en boucle (CA36).
        final again = _again && !_writeFailed;
        _again = false;
        if (again) _kick();
      }
    }
  }

  /// Charge le modèle si besoin, analyse [text] et enregistre le résultat. Rend
  /// `false` si la file doit s'arrêter là.
  Future<bool> _analyzeAndSave(int entryId, String text) async {
    final interruptions = _interruptions;
    bool interrupted() => _stopped || _interruptions != interruptions;
    if (!_prepared) {
      // Empreinte vérifiée avant toute lecture du modèle par le moteur, calculée
      // une fois par lancement par le téléchargeur (CA36, ADR-004) ; l'arrêt de
      // la file n'attend pas la fin du calcul (CA37).
      final verified = await Future.any([
        downloader.verifyBeforeFirstLoad().catchError((Object _) => false),
        _halted.future.then((_) => false),
      ]);
      if (interrupted()) return false;
      if (!verified) {
        // Empreinte fausse : modèle absent, l'entrée reste « en attente » et la
        // file attend un nouveau téléchargement (CA12). Erreur du calcul :
        // pas de nouvel essai immédiat, seulement au prochain événement (CA36).
        _again = false;
        return false;
      }
      bool loaded;
      try {
        loaded = await analyzer.prepare();
      } catch (_) {
        loaded = false;
      }
      if (loaded) _prepared = true;
      // Arrêt ou arrière-plan pendant le chargement : ni analyse, ni échec de
      // chargement (CA33, CA34).
      if (interrupted()) return false;
      if (!loaded) {
        await _onLoadFailure();
        return false;
      }
    }
    if (interrupted()) return false;
    final result = await _analyze(text);
    // Interrompue : l'entrée reste « en attente », quel que soit le résultat
    // (spec 004, « Interruption », « Arrière-plan », CA32).
    if (interrupted()) return false;
    try {
      await repository.saveAnalysis(entryId, result);
    } catch (_) {
      // Écriture impossible : l'entrée reste « en attente » (CA8) ; la file s'arrête
      // jusqu'au prochain événement, sans la reprendre dans cette série (CA36).
      // En fin d'ordre : la plus récemment en échec passera après les autres.
      _recordWriteFailure(entryId);
      return false;
    }
    _failureOrder.remove(entryId);
    return true;
  }

  /// Écriture impossible pour [entryId] (résultat, CA39, ou marquage « non
  /// analysée », CA40) : la file s'arrête jusqu'au prochain événement, sans tenir
  /// compte de ceux reçus pendant ce passage, et l'entrée passe en fin d'ordre :
  /// la plus récemment en échec passera après les autres.
  void _recordWriteFailure(int entryId) {
    _failureOrder
      ..remove(entryId)
      ..add(entryId);
    _writeFailed = true;
  }

  /// Analyse avec un délai : au-delà, la génération est arrêtée et la file attend
  /// que l'analyseur rende la main avant d'aller plus loin (CA9, CA14).
  Future<AnalysisResult> _analyze(String text) async {
    _analyzing = true;
    try {
      final analysis = analyzer.analyze(text);
      try {
        return await analysis.timeout(timeout);
      } on TimeoutException {
        await _cancelAnalysis();
        try {
          await analysis;
        } catch (_) {}
        // L'analyseur a pu libérer son moteur pour l'arrêter : la file le
        // libère aussi, et l'entrée suivante le recharge (CA35), au lieu de
        // devenir « sans étiquette » faute de moteur.
        await _release();
        return const Untagged();
      } catch (_) {
        return const Untagged();
      }
    } finally {
      _analyzing = false;
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
