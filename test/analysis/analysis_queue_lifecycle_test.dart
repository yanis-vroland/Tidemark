// File d'analyse et cycle de vie de l'app (spec 004, correction
// `fix/etiquetage-interruption` : CA32, CA33, CA34, règle « Entrée en cours »).
// Faux seulement : aucun modèle, aucune base. Le cycle de vie est un flux injecté.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/analysis/analysis_queue.dart';
import 'package:tidemark/analysis/mood_analyzer.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/main.dart';

import '../support/analysis_harness.dart';
import '../support/fake_entry_repository.dart';
import '../support/fake_model_downloader.dart';
import '../support/fake_mood_analyzer.dart';
import '../support/fake_settings_repository.dart';

final oct10 = DateTime(2026, 10, 10, 9);

const textA = 'Texte A';
const textB = 'Texte B';

// ---------------------------------------------------------------------------
// Faux propres à ces tests
// ---------------------------------------------------------------------------

/// Analyseur dont `prepare()` attend [gate] (le premier appel seulement) ; les
/// appels suivants rendent [prepareResult].
class GatedPrepareAnalyzer extends FakeMoodAnalyzer {
  GatedPrepareAnalyzer({super.results, super.fallback});

  Completer<bool>? gate = Completer<bool>();

  @override
  Future<bool> prepare() {
    prepareCalls++;
    final current = gate;
    if (current != null) {
      gate = null;
      return current.future;
    }
    return Future.value(prepareResult);
  }
}

/// Analyseur dont `release()` lève, comme un moteur qui échoue à se libérer.
class ThrowingReleaseAnalyzer extends FakeMoodAnalyzer {
  ThrowingReleaseAnalyzer({super.results, super.fallback});

  @override
  Future<void> release() async {
    releaseCalls++;
    throw StateError('libération impossible');
  }
}

/// Première analyse : ne finit qu'avec `cancel()` (rend `Untagged`). Les suivantes
/// rendent [second] tout de suite.
class InterruptedFirstAnalyzer extends FakeMoodAnalyzer {
  InterruptedFirstAnalyzer({required this.second});

  final AnalysisResult second;
  Completer<void>? _gate;

  @override
  Future<AnalysisResult> analyze(String text) async {
    received.add(text);
    running++;
    if (running > maxConcurrent) maxConcurrent = running;
    try {
      if (received.length == 1) {
        final gate = Completer<void>();
        _gate = gate;
        await gate.future;
        return const Untagged();
      }
      return second;
    } finally {
      running--;
    }
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    final gate = _gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }
}

/// Première analyse : le moteur met [stopDelay] à finir malgré `cancel()`, qui
/// n'attend que cette fin ; les suivantes rendent [second] tout de suite.
class SlowToStopAnalyzer extends FakeMoodAnalyzer {
  SlowToStopAnalyzer({required this.second, required this.stopDelay});

  final AnalysisResult second;
  final Duration stopDelay;
  Completer<void>? _inFlight;

  @override
  Future<AnalysisResult> analyze(String text) async {
    received.add(text);
    running++;
    if (running > maxConcurrent) maxConcurrent = running;
    try {
      if (received.length == 1) {
        final inFlight = Completer<void>();
        _inFlight = inFlight;
        await Future<void>.delayed(stopDelay);
        inFlight.complete();
        return const Untagged();
      }
      return second;
    } finally {
      running--;
    }
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    await _inFlight?.future;
  }
}

/// Dépôt dont `saveAnalysis` attend [gate] avant d'écrire.
class GatedSaveRepository extends FakeEntryRepository {
  final Completer<void> gate = Completer<void>();
  bool saveStarted = false;

  @override
  Future<void> saveAnalysis(int entryId, AnalysisResult result) async {
    saveStarted = true;
    await gate.future;
    return super.saveAnalysis(entryId, result);
  }
}

/// Dépôt dont l'abonnement de `watchEntries()` compte les appels à `cancel()`.
/// Comme drift dans le temps simulé, le premier `cancel()` rend un futur terminé et
/// les suivants un futur qui ne se termine jamais (tant que [hangLaterCancels]).
class CancelCountingRepository extends FakeEntryRepository {
  int cancelCalls = 0;

  /// Faux : les `cancel()` suivants se terminent normalement (nettoyage de fin de
  /// test, pour ne pas faire attendre les `tearDown`).
  bool hangLaterCancels = true;

  /// `cancel()` lève : un désabonnement en échec ne doit pas empêcher le reste
  /// de l'arrêt (revue de sécurité de la PR).
  bool throwOnCancel = false;

  @override
  Stream<List<Entry>> watchEntries() =>
      _CancelCountingStream(super.watchEntries(), this);
}

class _CancelCountingStream extends Stream<List<Entry>> {
  _CancelCountingStream(this._inner, this._owner);

  final Stream<List<Entry>> _inner;
  final CancelCountingRepository _owner;

  @override
  StreamSubscription<List<Entry>> listen(
    void Function(List<Entry> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _CancelCountingSubscription(
    _inner.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    ),
    _owner,
  );
}

class _CancelCountingSubscription implements StreamSubscription<List<Entry>> {
  _CancelCountingSubscription(this._inner, this._owner);

  final StreamSubscription<List<Entry>> _inner;
  final CancelCountingRepository _owner;

  @override
  Future<void> cancel() {
    _owner.cancelCalls++;
    if (_owner.throwOnCancel) throw StateError('désabonnement impossible');
    if (_owner.cancelCalls > 1 && _owner.hangLaterCancels) {
      return Completer<void>().future;
    }
    return _inner.cancel();
  }

  @override
  void onData(void Function(List<Entry> data)? handleData) =>
      _inner.onData(handleData);

  @override
  void onError(Function? handleError) => _inner.onError(handleError);

  @override
  void onDone(void Function()? handleDone) => _inner.onDone(handleDone);

  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);

  @override
  void resume() => _inner.resume();

  @override
  bool get isPaused => _inner.isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) => _inner.asFuture(futureValue);
}

// ---------------------------------------------------------------------------
// Environnement
// ---------------------------------------------------------------------------

class LifeEnv {
  LifeEnv({
    FakeEntryRepository? repo,
    required this.analyzer,
    Duration timeout = const Duration(seconds: 30),
  }) : repo = repo ?? FakeEntryRepository(),
       downloader = FakeModelDownloader(readyModel) {
    queue = AnalysisQueue(
      repository: this.repo,
      analyzer: analyzer,
      downloader: downloader,
      timeout: timeout,
      lifecycle: lifecycle.stream,
    );
    addTearDown(() async {
      try {
        await queue.stop().timeout(const Duration(seconds: 3));
      } catch (_) {}
      await lifecycle.close();
    });
  }

  final FakeEntryRepository repo;
  final FakeMoodAnalyzer analyzer;
  final FakeModelDownloader downloader;
  final StreamController<AppLifecycleState> lifecycle =
      StreamController<AppLifecycleState>.broadcast();
  late final AnalysisQueue queue;

  Future<void> start() async {
    queue.start();
    await pumpEventQueue();
  }

  /// Émet un état du cycle de vie et laisse la file le traiter.
  Future<void> emit(AppLifecycleState state) async {
    lifecycle.add(state);
    await pumpEventQueue();
  }

  Entry entry(int id) => repo.entries.firstWhere((e) => e.id == id);

  AnalysisStatus status(Entry e) => entry(e.id).analysisStatus;
}

/// Attend [condition] (1,5 s au plus) et échoue avec [reason] sinon : un test rouge
/// ne bloque pas la suite.
Future<void> eventually(
  bool Function() condition,
  String reason, {
  Duration limit = const Duration(milliseconds: 1500),
}) async {
  try {
    await until(condition, limit: limit);
  } on TimeoutException {
    fail('condition jamais remplie : $reason');
  }
}

void main() {
  group('CA32 : arrière-plan pendant une analyse', () {
    for (final background in [
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ]) {
      test('CA32 : ${background.name} pendant l\'analyse, cancel() est appelé, '
          'rien n\'est écrit, l\'entrée reste en attente et le modèle est '
          'libéré après la fin de l\'analyse', () async {
        final analyzer = LoggingAnalyzer(delays: {textA: null});
        final env = LifeEnv(analyzer: analyzer);
        final entry = env.repo.seed(mood: 3, text: textA, createdAt: oct10);
        await env.start();
        await eventually(
          () => analyzer.received.length == 1,
          'l\'analyse doit démarrer',
        );

        await env.emit(background);
        await eventually(
          () => analyzer.releaseCalls >= 1,
          'cancel() puis release() attendus en ${background.name}',
        );
        await wait();

        expect(analyzer.cancelCalls, greaterThanOrEqualTo(1));
        expect(env.repo.saveAnalysisCalls, isEmpty);
        expect(env.status(entry), AnalysisStatus.pending);
        final events = analyzer.events;
        expect(
          events.indexOf('release'),
          greaterThan(events.indexOf('done:$textA')),
          reason: 'le modèle est libéré après la fin de l\'analyse : $events',
        );
        expect(env.queue.currentEntryId, isNull);
        expect(env.queue.state, AnalysisQueueState.idle);
      });
    }

    test('CA32 : un analyseur qui ignore cancel() et rend Untagged plus tard '
        'n\'écrit rien, l\'entrée reste en attente', () async {
      final analyzer = LateAnalyzer(
        duration: const Duration(milliseconds: 200),
        lateResult: const Untagged(),
      );
      final env = LifeEnv(analyzer: analyzer);
      final entry = env.repo.seed(mood: 3, text: textA, createdAt: oct10);
      await env.start();
      await eventually(
        () => analyzer.received.length == 1,
        'l\'analyse doit démarrer',
      );

      await env.emit(AppLifecycleState.paused);
      await eventually(
        () => analyzer.releaseCalls >= 1,
        'le modèle doit être libéré',
      );
      await wait();

      expect(env.repo.saveAnalysisCalls, isEmpty);
      expect(env.status(entry), AnalysisStatus.pending);
    });

    test('CA32 : le délai de la file qui tombe pendant l\'arrière-plan ne vaut '
        'pas « sans étiquette »', () async {
      // L'arrêt du moteur prend 300 ms ; le délai (100 ms) expire pendant ce temps.
      final analyzer = LateAnalyzer(
        duration: const Duration(milliseconds: 300),
        lateResult: const Untagged(),
      );
      final env = LifeEnv(
        analyzer: analyzer,
        timeout: const Duration(milliseconds: 100),
      );
      final entry = env.repo.seed(mood: 3, text: textA, createdAt: oct10);
      await env.start();
      await eventually(
        () => analyzer.received.length == 1,
        'l\'analyse doit démarrer',
      );

      await wait(const Duration(milliseconds: 30));
      await env.emit(AppLifecycleState.paused);
      await wait(const Duration(milliseconds: 700));

      expect(env.repo.saveAnalysisCalls, isEmpty);
      expect(env.status(entry), AnalysisStatus.pending);
    });

    test('CA32 : en arrière-plan, une entrée enregistrée n\'est pas analysée ; '
        'au retour (resumed), elle l\'est et prend son statut', () async {
      final analyzer = FakeMoodAnalyzer(
        results: {
          textB: Tagged([emotion('joie')]),
        },
      );
      final env = LifeEnv(analyzer: analyzer);
      await env.start();
      await env.emit(AppLifecycleState.hidden);

      final entry = await env.repo.addEntry(mood: 4, text: textB);
      await wait(const Duration(milliseconds: 300));

      expect(analyzer.received, isEmpty);
      expect(analyzer.prepareCalls, 0);
      expect(env.status(entry), AnalysisStatus.pending);

      await env.emit(AppLifecycleState.resumed);
      await eventually(
        () => env.status(entry) == AnalysisStatus.tagged,
        'l\'entrée doit être analysée au retour au premier plan',
      );
      expect(env.entry(entry.id).tags, [emotion('joie')]);
    });

    test('CA32 : une analyse interrompue repart au retour (resumed) et '
        'l\'entrée finit étiquetée', () async {
      final analyzer = InterruptedFirstAnalyzer(
        second: Tagged([emotion('calme')]),
      );
      final env = LifeEnv(analyzer: analyzer);
      final entry = env.repo.seed(mood: 3, text: textA, createdAt: oct10);
      await env.start();
      await eventually(
        () => analyzer.received.length == 1,
        'l\'analyse doit démarrer',
      );

      await env.emit(AppLifecycleState.hidden);
      await eventually(
        () => analyzer.releaseCalls >= 1,
        'l\'analyse doit être interrompue puis le modèle libéré',
      );
      await wait();
      expect(env.status(entry), AnalysisStatus.pending);
      expect(env.repo.saveAnalysisCalls, isEmpty);

      await env.emit(AppLifecycleState.resumed);
      await eventually(
        () => env.status(entry) == AnalysisStatus.tagged,
        'l\'entrée interrompue doit être analysée de nouveau',
      );
      expect(analyzer.received, [textA, textA]);
      expect(env.entry(entry.id).tags, [emotion('calme')]);
    });

    test('CA32 : inactive pendant l\'analyse n\'interrompt rien, le résultat '
        'est enregistré', () async {
      final analyzer = FakeMoodAnalyzer(
        results: {
          textA: Tagged([emotion('joie')]),
        },
        delays: {textA: const Duration(milliseconds: 300)},
      );
      final env = LifeEnv(analyzer: analyzer);
      final entry = env.repo.seed(mood: 3, text: textA, createdAt: oct10);
      await env.start();
      await eventually(
        () => analyzer.received.length == 1,
        'l\'analyse doit démarrer',
      );

      await env.emit(AppLifecycleState.inactive);
      await eventually(
        () => env.status(entry) == AnalysisStatus.tagged,
        'le résultat doit être enregistré malgré inactive',
      );

      expect(analyzer.cancelCalls, 0);
      expect(env.repo.saveAnalysisCalls, hasLength(1));
    });

    test('CA32 : aller-retour rapide (hidden puis resumed avant la fin de '
        'l\'analyse interrompue) : la file se relance d\'elle-même, jamais '
        'deux analyses en même temps', () async {
      final analyzer = SlowToStopAnalyzer(
        second: Tagged([emotion('joie')]),
        stopDelay: const Duration(milliseconds: 300),
      );
      final env = LifeEnv(analyzer: analyzer);
      final entry = env.repo.seed(mood: 3, text: textA, createdAt: oct10);
      await env.start();
      await eventually(
        () => analyzer.received.length == 1,
        'l\'analyse doit démarrer',
      );

      await env.emit(AppLifecycleState.hidden);
      await wait(const Duration(milliseconds: 50));
      await env.emit(AppLifecycleState.resumed);

      await eventually(
        () => env.status(entry) == AnalysisStatus.tagged,
        'l\'entrée doit finir étiquetée après l\'aller-retour',
      );
      expect(analyzer.maxConcurrent, 1);
      expect(analyzer.received, [textA, textA]);
    });
  });

  group('CA33 : arrière-plan pendant le chargement du modèle', () {
    test('CA33 : un chargement qui échoue en arrière-plan n\'appelle pas '
        'verifyAfterLoadFailure() et la file n\'est pas « indisponible » ; au '
        'retour, l\'entrée est analysée', () async {
      final analyzer = GatedPrepareAnalyzer(
        results: {
          textA: Tagged([emotion('joie')]),
        },
      );
      final env = LifeEnv(analyzer: analyzer);
      final entry = env.repo.seed(mood: 3, text: textA, createdAt: oct10);
      final gate = analyzer.gate!;
      await env.start();
      await eventually(
        () => analyzer.prepareCalls == 1,
        'le chargement doit démarrer',
      );

      await env.emit(AppLifecycleState.paused);
      await wait(const Duration(milliseconds: 50));
      gate.complete(false);
      await wait(const Duration(milliseconds: 300));

      expect(env.downloader.verifyCalls, 0);
      expect(env.queue.state, isNot(AnalysisQueueState.unavailable));
      expect(analyzer.received, isEmpty);
      expect(env.status(entry), AnalysisStatus.pending);

      await env.emit(AppLifecycleState.resumed);
      await eventually(
        () => env.status(entry) == AnalysisStatus.tagged,
        'l\'entrée doit être analysée au retour au premier plan',
      );
      expect(analyzer.prepareCalls, 2);
    });

    test('CA33 : un chargement réussi en arrière-plan n\'analyse rien et le '
        'modèle est libéré', () async {
      final analyzer = GatedPrepareAnalyzer();
      final env = LifeEnv(analyzer: analyzer);
      final entry = env.repo.seed(mood: 3, text: textA, createdAt: oct10);
      final gate = analyzer.gate!;
      await env.start();
      await eventually(
        () => analyzer.prepareCalls == 1,
        'le chargement doit démarrer',
      );

      await env.emit(AppLifecycleState.paused);
      await wait(const Duration(milliseconds: 50));
      gate.complete(true);
      await wait(const Duration(milliseconds: 300));

      expect(analyzer.received, isEmpty);
      expect(analyzer.releaseCalls, 1);
      expect(env.status(entry), AnalysisStatus.pending);
    });
  });

  group('CA34 : une libération qui échoue ne bloque pas la file', () {
    test('CA34 : release() lève : une entrée enregistrée ensuite est '
        'analysée', () async {
      final analyzer = ThrowingReleaseAnalyzer();
      final env = LifeEnv(analyzer: analyzer);
      env.repo.seed(mood: 3, text: textA, createdAt: oct10);
      await env.start();
      await eventually(
        () => analyzer.releaseCalls >= 1,
        'la première entrée doit être analysée puis le modèle libéré',
      );

      await env.repo.addEntry(mood: 4, text: textB);

      await eventually(
        () => analyzer.received.length == 2,
        'la file doit rester utilisable après une libération en échec',
      );
    });

    test('CA34 : release() lève : stop() se termine', () async {
      final analyzer = ThrowingReleaseAnalyzer();
      final env = LifeEnv(analyzer: analyzer);
      env.repo.seed(mood: 3, text: textA, createdAt: oct10);
      await env.start();
      await eventually(
        () => analyzer.releaseCalls >= 1,
        'la première entrée doit être analysée puis le modèle libéré',
      );

      // Décision de test : stop() peut se terminer normalement ou par l'erreur de
      // release(), mais ne doit pas rester bloquée.
      await env.queue
          .stop()
          .then<void>((_) {}, onError: (Object _) {})
          .timeout(const Duration(seconds: 3));
    });

    test('CA34 : stop() pendant le chargement du modèle, puis chargement '
        'réussi : aucune analyse, modèle libéré', () async {
      final analyzer = GatedPrepareAnalyzer();
      final env = LifeEnv(analyzer: analyzer);
      env.repo.seed(mood: 3, text: textA, createdAt: oct10);
      final gate = analyzer.gate!;
      await env.start();
      await eventually(
        () => analyzer.prepareCalls == 1,
        'le chargement doit démarrer',
      );

      final stopping = env.queue.stop();
      await pumpEventQueue();
      gate.complete(true);
      await stopping.timeout(const Duration(seconds: 3));

      expect(analyzer.received, isEmpty);
      expect(analyzer.releaseCalls, greaterThanOrEqualTo(1));
    });
  });

  group('CA34 : second stop() (issue #33)', () {
    /// File démarrée sur un dépôt dont le second `cancel()` ne se termine jamais ;
    /// le faux redevient normal avant le `tearDown` de [LifeEnv].
    Future<
      ({LifeEnv env, CancelCountingRepository repo, LoggingAnalyzer analyzer})
    >
    startedQueue() async {
      final repo = CancelCountingRepository();
      final analyzer = LoggingAnalyzer(delays: {textA: null});
      final env = LifeEnv(repo: repo, analyzer: analyzer);
      addTearDown(() => repo.hangLaterCancels = false);
      repo.seed(mood: 3, text: textA, createdAt: oct10);
      await env.start();
      await eventually(
        () => analyzer.received.length == 1,
        'l\'analyse doit démarrer',
      );
      return (env: env, repo: repo, analyzer: analyzer);
    }

    test('CA34 : stop() puis stop() : le second appel se termine', () async {
      final s = await startedQueue();
      await s.env.queue.stop().timeout(const Duration(seconds: 2));

      await s.env.queue.stop().timeout(const Duration(seconds: 2));
    });

    test('CA34 : deux stop() lancés en même temps se terminent', () async {
      final s = await startedQueue();

      await Future.wait([s.env.queue.stop(), s.env.queue.stop()])
          .timeout(const Duration(seconds: 2));
    });

    test('CA34 : le second stop() ne refait pas l\'arrêt : un seul cancel() '
        'de l\'abonnement, aucun nouvel appel à cancel() ni release() de '
        'l\'analyseur', () async {
      final s = await startedQueue();
      await s.env.queue.stop().timeout(const Duration(seconds: 2));
      final cancelsBefore = s.analyzer.cancelCalls;
      final releasesBefore = s.analyzer.releaseCalls;
      expect(s.repo.cancelCalls, 1);

      // Sans attendre sa fin : le test ne dépend pas d'un blocage éventuel.
      unawaited(s.env.queue.stop());
      await wait();

      expect(
        s.repo.cancelCalls,
        1,
        reason: 'l\'abonnement au journal n\'est annulé qu\'une fois',
      );
      expect(s.analyzer.cancelCalls, cancelsBefore);
      expect(s.analyzer.releaseCalls, releasesBefore);
    });

    test('CA34 : un désabonnement qui lève n\'empêche pas le reste de '
        'l\'arrêt : génération annulée, modèle libéré', () async {
      final s = await startedQueue();
      s.repo.throwOnCancel = true;
      addTearDown(() => s.repo.throwOnCancel = false);

      await s.env.queue
          .stop()
          .then<void>((_) {}, onError: (Object _) {})
          .timeout(const Duration(seconds: 2));

      expect(s.analyzer.cancelCalls, greaterThanOrEqualTo(1));
      expect(s.analyzer.releaseCalls, greaterThanOrEqualTo(1));
    });
  });

  group('Entrée en cours : du chargement du modèle à l\'écriture', () {
    test('CA20 : pendant le chargement du modèle, l\'entrée est « en cours » '
        'et la file est running', () async {
      final analyzer = GatedPrepareAnalyzer();
      final env = LifeEnv(analyzer: analyzer);
      final entry = env.repo.seed(mood: 3, text: textA, createdAt: oct10);
      await env.start();
      await eventually(
        () => analyzer.prepareCalls == 1,
        'le chargement doit démarrer',
      );

      expect(env.queue.currentEntryId, entry.id);
      expect(env.queue.state, AnalysisQueueState.running);

      analyzer.gate?.complete(true);
    });

    test('CA22 : pendant l\'écriture du résultat, l\'entrée est encore « en '
        'cours » ; après l\'écriture, plus aucune', () async {
      final repo = GatedSaveRepository();
      final env = LifeEnv(repo: repo, analyzer: FakeMoodAnalyzer());
      final entry = repo.seed(mood: 3, text: textA, createdAt: oct10);
      await env.start();
      await eventually(() => repo.saveStarted, 'l\'écriture doit commencer');

      expect(env.queue.currentEntryId, entry.id);

      repo.gate.complete();
      await eventually(
        () => env.queue.currentEntryId == null,
        'plus d\'entrée en cours après l\'écriture',
      );
      expect(env.status(entry), AnalysisStatus.untagged);
    });
  });

  group('Branchement de startApp au cycle de vie', () {
    test('CA32 : via startApp, la mise en arrière-plan pendant l\'analyse '
        'laisse l\'entrée en attente, sans saveAnalysis', () async {
      final repo = FakeEntryRepository();
      final entry = repo.seed(mood: 3, text: textA, createdAt: oct10);
      final analyzer = FakeMoodAnalyzer(delays: {textA: null});
      final controller = StreamController<AppLifecycleState>.broadcast();
      addTearDown(controller.close);

      final app = await startApp(
        open: () async => Journal(
          entries: repo,
          settings: FakeSettingsRepository(),
          downloader: FakeModelDownloader(readyModel),
          analyzer: analyzer,
        ),
        lifecycle: controller.stream,
      );
      final queue = (app as TidemarkApp).analysisQueue!;
      addTearDown(queue.stop);
      await eventually(
        () => analyzer.received.length == 1,
        'l\'analyse doit démarrer',
      );

      controller.add(AppLifecycleState.paused);
      await eventually(
        () => analyzer.releaseCalls >= 1,
        'la file doit interrompre l\'analyse puis libérer le modèle',
      );
      await wait();

      expect(analyzer.cancelCalls, greaterThanOrEqualTo(1));
      expect(repo.saveAnalysisCalls, isEmpty);
      expect(
        repo.entries.firstWhere((e) => e.id == entry.id).analysisStatus,
        AnalysisStatus.pending,
      );
    });

    testWidgets('CA32 : appLifecycleStates() émet les changements d\'état du '
        'cycle de vie de l\'app', (tester) async {
      final states = <AppLifecycleState>[];
      final subscription = appLifecycleStates().listen(states.add);
      addTearDown(subscription.cancel);
      await tester.pump();

      const transitions = [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ];
      for (final state in transitions) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
      }

      expect(states, transitions);
    });
  });
}
