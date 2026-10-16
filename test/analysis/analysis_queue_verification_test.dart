// File d'analyse et vérification de l'empreinte avant le chargement (spec 004, règle
// « Vérification avant le chargement », CA36, CA37 ; spec 003, CA34 ; ADR-004).
// Faux seulement : aucun modèle, aucune base, aucun calcul d'empreinte réel. Le
// calcul « en cours » est simulé par `verifyBeforeLoadGate` du téléchargeur factice.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/analysis/analysis_queue.dart';
import 'package:tidemark/analysis/mood_analyzer.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/model/model_state.dart';

import '../support/analysis_harness.dart';
import '../support/fake_entry_repository.dart';
import '../support/fake_model_downloader.dart';
import '../support/fake_mood_analyzer.dart';

final oct10 = DateTime(2026, 10, 10, 9);
final oct11 = DateTime(2026, 10, 11, 9);
final oct12 = DateTime(2026, 10, 12, 9);

const textA = 'Texte A';
const textB = 'Texte B';
const textC = 'Texte C';

/// Analyseur qui note, à chaque `prepare()`, combien de vérifications avaient été
/// demandées au téléchargeur : c'est l'ordre « vérifier, puis charger ».
class OrderRecordingAnalyzer extends FakeMoodAnalyzer {
  OrderRecordingAnalyzer(this.downloader, {super.results, super.delays});

  final FakeModelDownloader downloader;

  /// Appels de `verifyBeforeFirstLoad` déjà faits au moment de chaque `prepare()`.
  final List<int> verificationsAtPrepare = [];

  @override
  Future<bool> prepare() {
    verificationsAtPrepare.add(downloader.verifyBeforeLoadCalls);
    return super.prepare();
  }
}

/// Téléchargeur dont la vérification rend `false` tout en laissant le modèle
/// `ready` : une erreur du calcul autre qu'une empreinte fausse (spec 003, CA35).
class FailingVerificationDownloader extends FakeModelDownloader {
  FailingVerificationDownloader(super.initial);

  bool failing = true;

  @override
  Future<bool> verifyBeforeFirstLoad() async {
    verifyBeforeLoadCalls++;
    return !failing;
  }
}

/// Attend [condition] (1,5 s au plus) et échoue avec [reason] sinon.
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

class Env {
  Env({
    FakeMoodAnalyzer? analyzer,
    FakeModelDownloader? downloader,
    Duration timeout = const Duration(seconds: 30),
  }) : downloader = downloader ?? FakeModelDownloader(readyModel),
       repo = FakeEntryRepository() {
    this.analyzer = analyzer ?? OrderRecordingAnalyzer(this.downloader);
    queue = AnalysisQueue(
      repository: repo,
      analyzer: this.analyzer,
      downloader: this.downloader,
      timeout: timeout,
      lifecycle: lifecycle.stream,
    );
    addTearDown(() async {
      // Libère un calcul retenu, puis arrête la file sans bloquer la suite.
      final gate = this.downloader.verifyBeforeLoadGate;
      if (gate != null && !gate.isCompleted) gate.complete();
      try {
        await queue.stop().timeout(const Duration(seconds: 3));
      } catch (_) {}
      await lifecycle.close();
    });
  }

  final FakeEntryRepository repo;
  final FakeModelDownloader downloader;
  late final FakeMoodAnalyzer analyzer;
  final StreamController<AppLifecycleState> lifecycle =
      StreamController<AppLifecycleState>.broadcast();
  late final AnalysisQueue queue;

  Future<void> start() async {
    queue.start();
    await pumpEventQueue();
  }

  Future<void> emitLifecycle(AppLifecycleState state) async {
    lifecycle.add(state);
    await pumpEventQueue();
  }

  /// Retient le calcul de l'empreinte jusqu'à `gate.complete()`.
  Completer<void> holdVerification() {
    final gate = Completer<void>();
    downloader.verifyBeforeLoadGate = gate;
    return gate;
  }

  Entry entry(int id) => repo.entries.firstWhere((e) => e.id == id);

  AnalysisStatus status(Entry e) => entry(e.id).analysisStatus;
}

void main() {
  group('CA36 : la vérification précède le chargement', () {
    test(
      'spec 004 CA36 : verifyBeforeFirstLoad() est appelé avant prepare()',
      () async {
        final downloader = FakeModelDownloader(readyModel);
        final analyzer = OrderRecordingAnalyzer(
          downloader,
          results: {
            textA: Tagged([emotion('calme')]),
          },
        );
        final env = Env(analyzer: analyzer, downloader: downloader);
        final entry = env.repo.seed(mood: 3, text: textA, createdAt: oct10);

        await env.start();
        await eventually(
          () => env.status(entry) == AnalysisStatus.tagged,
          'l\'entrée doit être analysée',
        );

        expect(analyzer.verificationsAtPrepare, isNotEmpty);
        expect(
          analyzer.verificationsAtPrepare.first,
          greaterThanOrEqualTo(1),
          reason:
              'prepare() ne doit pas précéder la vérification de l\'empreinte',
        );
      },
    );

    test('spec 004 CA36 : empreinte fausse : ni prepare(), ni analyze(), ni '
        'verifyAfterLoadFailure() ; entrée en attente, file idle (pas '
        'unavailable)', () async {
      final downloader = FakeModelDownloader(readyModel)
        ..fingerprintMatches = false;
      final env = Env(downloader: downloader);
      final entry = env.repo.seed(mood: 3, text: textA, createdAt: oct10);

      await env.start();
      await eventually(
        () => downloader.verifyBeforeLoadCalls >= 1,
        'la vérification doit avoir lieu avant tout chargement',
      );
      await wait();

      expect(env.analyzer.prepareCalls, 0);
      expect(env.analyzer.received, isEmpty);
      expect(downloader.verifyCalls, 0);
      expect(env.repo.saveAnalysisCalls, isEmpty);
      expect(env.status(entry), AnalysisStatus.pending);
      expect(downloader.current, isA<ModelAbsent>());
      expect(env.queue.state, AnalysisQueueState.idle);
      expect(env.queue.currentEntryId, isNull);
    });

    test('spec 004 CA36 : après un nouveau téléchargement (modèle ready de '
        'nouveau), la file se relance et analyse l\'entrée', () async {
      final downloader = FakeModelDownloader(readyModel)
        ..fingerprintMatches = false;
      final env = Env(
        downloader: downloader,
        analyzer: OrderRecordingAnalyzer(
          downloader,
          results: {
            textA: Tagged([emotion('joie')]),
          },
        ),
      );
      final entry = env.repo.seed(mood: 3, text: textA, createdAt: oct10);
      await env.start();
      await eventually(
        () => downloader.current is ModelAbsent,
        'le modèle doit repasser à absent',
      );
      await wait();
      expect(env.status(entry), AnalysisStatus.pending);

      downloader.fingerprintMatches = true;
      downloader.emit(readyModel);
      await eventually(
        () => env.status(entry) == AnalysisStatus.tagged,
        'l\'entrée doit être analysée après le retéléchargement',
      );

      expect(env.entry(entry.id).tags, [emotion('joie')]);
      expect(env.analyzer.prepareCalls, 1);
      expect(downloader.verifyCalls, 0);
    });

    test('spec 004 CA36 : vérification qui rend false, modèle resté ready '
        '(erreur du calcul) : aucun prepare(), entrée en attente, file idle, '
        'sans boucle', () async {
      final downloader = FailingVerificationDownloader(readyModel);
      final env = Env(downloader: downloader);
      final entry = env.repo.seed(mood: 3, text: textA, createdAt: oct10);

      await env.start();
      await eventually(
        () => downloader.verifyBeforeLoadCalls >= 1,
        'la vérification doit avoir lieu',
      );
      await wait(const Duration(milliseconds: 300));

      expect(env.analyzer.prepareCalls, 0);
      expect(env.analyzer.received, isEmpty);
      expect(downloader.verifyCalls, 0);
      expect(env.status(entry), AnalysisStatus.pending);
      expect(env.queue.state, AnalysisQueueState.idle);
      expect(
        downloader.verifyBeforeLoadCalls,
        1,
        reason: 'la file s\'arrête là, elle ne réessaie pas en boucle',
      );
    });

    test('spec 004 CA36 : après une vérification en erreur, un nouvel '
        'enregistrement relance la file et la vérification', () async {
      final downloader = FailingVerificationDownloader(readyModel);
      final env = Env(downloader: downloader);
      env.repo.seed(mood: 3, text: textA, createdAt: oct10);
      await env.start();
      await eventually(
        () => downloader.verifyBeforeLoadCalls == 1,
        'première vérification',
      );
      await wait();

      downloader.failing = false;
      final added = await env.repo.addEntry(mood: 4, text: textB);

      await eventually(
        () => env.status(added) != AnalysisStatus.pending,
        'la nouvelle entrée doit être analysée',
      );
      expect(downloader.verifyBeforeLoadCalls, 2);
      expect(env.analyzer.prepareCalls, 1);
    });

    test('spec 004 CA36 : pendant le calcul retenu, l\'entrée est « en cours '
        'd\'analyse » (currentEntryId, état running) mais reste en attente '
        'en base ; prepare() n\'a pas eu lieu', () async {
      final env = Env();
      final gate = env.holdVerification();
      final entry = env.repo.seed(mood: 3, text: textA, createdAt: oct10);

      await env.start();
      await eventually(
        () => env.downloader.verifyBeforeLoadCalls == 1,
        'la vérification doit commencer',
      );
      await wait();

      expect(env.queue.currentEntryId, entry.id);
      expect(env.queue.state, AnalysisQueueState.running);
      expect(env.analyzer.prepareCalls, 0);
      expect(env.status(entry), AnalysisStatus.pending);

      gate.complete();
      await eventually(
        () => env.status(entry) != AnalysisStatus.pending,
        'l\'entrée doit être analysée une fois le calcul fini',
      );
      expect(env.queue.currentEntryId, isNull);
      expect(env.queue.state, AnalysisQueueState.idle);
    });

    test('spec 004 CA36 : chaque prepare() est précédé d\'une vérification, '
        'même après une libération du modèle entre deux entrées', () async {
      final downloader = FakeModelDownloader(readyModel);
      final analyzer = OrderRecordingAnalyzer(
        downloader,
        results: {
          textA: Tagged([emotion('calme')]),
          textB: Tagged([emotion('joie')]),
          textC: Tagged([emotion('fatigue')]),
        },
        // La plus récente (C) ne finit pas : le délai de la file la coupe, ce qui
        // libère le modèle ; A et B le rechargent.
        delays: {textC: null},
      );
      final env = Env(
        analyzer: analyzer,
        downloader: downloader,
        timeout: const Duration(milliseconds: 100),
      );
      final a = env.repo.seed(mood: 3, text: textA, createdAt: oct10);
      final b = env.repo.seed(mood: 3, text: textB, createdAt: oct11);
      env.repo.seed(mood: 3, text: textC, createdAt: oct12);

      await env.start();
      await eventually(
        () =>
            env.status(a) == AnalysisStatus.tagged &&
            env.status(b) == AnalysisStatus.tagged,
        'A et B doivent être analysées',
      );

      expect(
        analyzer.prepareCalls,
        greaterThanOrEqualTo(2),
        reason: 'le test suppose une libération du modèle entre deux entrées',
      );
      for (var i = 0; i < analyzer.verificationsAtPrepare.length; i++) {
        expect(
          analyzer.verificationsAtPrepare[i],
          greaterThanOrEqualTo(i + 1),
          reason:
              'prepare() n°${i + 1} sans vérification préalable : '
              '${analyzer.verificationsAtPrepare}',
        );
      }
    });
  });

  group('CA37 : interruption pendant le calcul', () {
    test(
      'spec 004 CA37 : arrière-plan pendant le calcul : pas de prepare(), '
      'entrée en attente ; reprise au premier plan : entrée analysée',
      () async {
        final env = Env();
        final gate = env.holdVerification();
        final entry = env.repo.seed(mood: 3, text: textA, createdAt: oct10);
        await env.start();
        await eventually(
          () => env.downloader.verifyBeforeLoadCalls == 1,
          'la vérification doit commencer',
        );

        await env.emitLifecycle(AppLifecycleState.paused);
        gate.complete();
        await wait(const Duration(milliseconds: 300));

        expect(env.analyzer.prepareCalls, 0);
        expect(env.analyzer.received, isEmpty);
        expect(env.repo.saveAnalysisCalls, isEmpty);
        expect(env.status(entry), AnalysisStatus.pending);
        expect(env.queue.state, AnalysisQueueState.idle);
        expect(env.queue.currentEntryId, isNull);

        await env.emitLifecycle(AppLifecycleState.resumed);
        await eventually(
          () =>
              env.status(entry) == AnalysisStatus.tagged ||
              env.status(entry) == AnalysisStatus.untagged,
          'l\'entrée doit être analysée au retour au premier plan',
        );
        expect(env.analyzer.prepareCalls, 1);
        expect(env.analyzer.received, [textA]);
      },
    );

    test('spec 004 CA37 : stop() pendant le calcul rend la main sans attendre '
        'sa fin, et prepare() n\'est jamais appelé', () async {
      final env = Env();
      env.holdVerification(); // jamais complété pendant le test
      final entry = env.repo.seed(mood: 3, text: textA, createdAt: oct10);
      await env.start();
      await eventually(
        () => env.downloader.verifyBeforeLoadCalls == 1,
        'la vérification doit commencer',
      );

      await env.queue.stop().timeout(
        const Duration(seconds: 2),
        onTimeout: () => fail('stop() attend la fin du calcul de l\'empreinte'),
      );

      expect(env.analyzer.prepareCalls, 0);
      expect(env.analyzer.received, isEmpty);
      expect(env.status(entry), AnalysisStatus.pending);
    });

    test('spec 004 CA37 : stop() pendant le calcul : même quand le calcul '
        'finit ensuite, prepare() n\'est jamais appelé et l\'entrée reste en '
        'attente', () async {
      final env = Env();
      final gate = env.holdVerification();
      final entry = env.repo.seed(mood: 3, text: textA, createdAt: oct10);
      await env.start();
      await eventually(
        () => env.downloader.verifyBeforeLoadCalls == 1,
        'la vérification doit commencer',
      );
      await env.queue.stop().timeout(
        const Duration(seconds: 2),
        onTimeout: () => fail('stop() attend la fin du calcul de l\'empreinte'),
      );

      gate.complete();
      await wait(const Duration(milliseconds: 300));

      expect(env.analyzer.prepareCalls, 0);
      expect(env.analyzer.received, isEmpty);
      expect(env.repo.saveAnalysisCalls, isEmpty);
      expect(env.status(entry), AnalysisStatus.pending);
    });
  });
}
