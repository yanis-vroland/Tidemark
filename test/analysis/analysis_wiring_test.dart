// Branchement de la file au démarrage de l'app (spec 004, CA6, CA7, CA12) : `startApp`
// crée et démarre la file quand `Journal.analyzer` est fourni, après la vérification
// de détresse. Journal de faux : aucun modèle, aucune base, aucun réseau.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/analysis/analysis_queue.dart';
import 'package:tidemark/analysis/mood_analyzer.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/main.dart';
import 'package:tidemark/model/model_state.dart';

import '../support/analysis_harness.dart';
import '../support/fake_entry_repository.dart';
import '../support/fake_model_downloader.dart';
import '../support/fake_mood_analyzer.dart';
import '../support/fake_settings_repository.dart';
import '../support/ui_harness.dart';

final oct10 = DateTime(2026, 10, 10, 9);
final oct11 = DateTime(2026, 10, 11, 9);
final oct12 = DateTime(2026, 10, 12, 9);

Journal journalOf(
  FakeEntryRepository repo,
  FakeModelDownloader downloader, {
  FakeMoodAnalyzer? analyzer,
}) => Journal(
  entries: repo,
  settings: FakeSettingsRepository(),
  downloader: downloader,
  analyzer: analyzer,
);

AnalysisQueue queueOf(Widget app) {
  expect(app, isA<TidemarkApp>());
  final queue = (app as TidemarkApp).analysisQueue;
  expect(queue, isNotNull, reason: 'la file doit être donnée à l\'app');
  return queue!;
}

void main() {
  group('startApp et la file d\'analyse', () {
    test('CA6 : modèle prêt et trois entrées en attente, au démarrage elles '
        'sont analysées une à la fois, de la plus récente à la plus ancienne, '
        'avec le statut de leur résultat', () async {
      final repo = FakeEntryRepository();
      final old = repo.seed(mood: 2, text: 'Texte ancien', createdAt: oct10);
      final mid = repo.seed(mood: 3, text: 'Texte milieu', createdAt: oct11);
      final recent = repo.seed(mood: 4, text: 'Texte récent', createdAt: oct12);
      final analyzer = FakeMoodAnalyzer(
        results: {
          'Texte récent': Tagged(fatigueCalmeTravail),
          'Texte ancien': Tagged([emotion('joie')]),
        },
      );

      final app = await startApp(
        open: () async => journalOf(
          repo,
          FakeModelDownloader(readyModel),
          analyzer: analyzer,
        ),
      );
      final queue = queueOf(app);
      addTearDown(queue.stop);
      await queue.whenIdle.timeout(const Duration(seconds: 5));
      await pumpEventQueue();

      expect(analyzer.received, [
        'Texte récent',
        'Texte milieu',
        'Texte ancien',
      ]);
      expect(analyzer.maxConcurrent, 1);
      Entry byId(Entry e) => repo.entries.firstWhere((x) => x.id == e.id);
      expect(byId(recent).analysisStatus, AnalysisStatus.tagged);
      expect(byId(recent).tags, fatigueCalmeTravail);
      expect(byId(mid).analysisStatus, AnalysisStatus.untagged);
      expect(byId(old).analysisStatus, AnalysisStatus.tagged);
    });

    test('CA6 : la file ne démarre qu\'après la vérification de détresse au '
        'démarrage', () async {
      final repo = FirstReadRepository(gated: true)
        ..seed(mood: 3, text: 'Texte A', createdAt: oct10)
        ..seed(mood: 3, text: 'Texte B', createdAt: oct11);
      final downloader = WatchCountingDownloader(readyModel);
      final analyzer = FakeMoodAnalyzer();

      final started = startApp(
        open: () async => journalOf(repo, downloader, analyzer: analyzer),
      );
      await until(() => repo.pendingReads == 1);
      await wait();

      // La vérification de détresse est en cours (lecture bloquée) : la file n'a
      // encore rien observé ni analysé.
      expect(analyzer.received, isEmpty);
      expect(analyzer.prepareCalls, 0);
      expect(downloader.watchCalls, 0);

      repo.gate.complete();
      final app = await started;
      final queue = queueOf(app);
      addTearDown(queue.stop);
      await queue.whenIdle.timeout(const Duration(seconds: 5));

      expect(analyzer.received, ['Texte B', 'Texte A']);
    });

    test(
      'CA7 : si la vérification au démarrage échoue, la file écarte '
      'quand même l\'entrée en détresse, sans la transmettre au modèle',
      () async {
        final repo = FirstReadRepository(failFirstRead: true);
        final distress = repo.seed(
          mood: 1,
          text: 'J’ai envie de mourir.',
          createdAt: oct11,
        );
        final calm = repo.seed(
          mood: 4,
          text: 'Belle journée.',
          createdAt: oct12,
        );
        final analyzer = FakeMoodAnalyzer();

        final app = await startApp(
          open: () async => journalOf(
            repo,
            FakeModelDownloader(readyModel),
            analyzer: analyzer,
          ),
        );
        final queue = queueOf(app);
        addTearDown(queue.stop);
        await queue.whenIdle.timeout(const Duration(seconds: 5));
        await pumpEventQueue();

        expect(analyzer.received, ['Belle journée.']);
        Entry byId(Entry e) => repo.entries.firstWhere((x) => x.id == e.id);
        expect(byId(distress).analysisStatus, AnalysisStatus.skipped);
        expect(byId(calm).analysisStatus, AnalysisStatus.untagged);
      },
    );

    test(
      'CA12 : modèle absent au démarrage, rien n\'est analysé ; dès que le '
      'téléchargement se termine, la file se lance sans redémarrage',
      () async {
        final repo = FakeEntryRepository();
        final a = repo.seed(mood: 3, text: 'Texte A', createdAt: oct10);
        final downloader = FakeModelDownloader();
        final analyzer = FakeMoodAnalyzer();

        final app = await startApp(
          open: () async => journalOf(repo, downloader, analyzer: analyzer),
        );
        final queue = queueOf(app);
        addTearDown(queue.stop);
        await wait();
        expect(analyzer.received, isEmpty);
        expect(repo.entries.single.analysisStatus, AnalysisStatus.pending);

        downloader.emit(
          const ModelDownloading(receivedBytes: 5, totalBytes: 10),
        );
        await wait(const Duration(milliseconds: 50));
        expect(analyzer.received, isEmpty);
        downloader.emit(readyModel);
        await until(() => analyzer.received.isNotEmpty);
        await queue.whenIdle.timeout(const Duration(seconds: 5));
        await pumpEventQueue();

        expect(analyzer.received, ['Texte A']);
        expect(
          repo.entries.firstWhere((e) => e.id == a.id).analysisStatus,
          AnalysisStatus.untagged,
        );
      },
    );

    test('sans analyseur dans le journal, aucune file n\'est donnée à l\'app '
        'et rien n\'est analysé', () async {
      final repo = FakeEntryRepository()
        ..seed(mood: 3, text: 'Texte A', createdAt: oct10);

      final app = await startApp(
        open: () async => journalOf(repo, FakeModelDownloader(readyModel)),
      );
      await wait();

      expect(app, isA<TidemarkApp>());
      expect((app as TidemarkApp).analysisQueue, isNull);
      expect(repo.entries.single.analysisStatus, AnalysisStatus.pending);
    });
  });

  group('l\'app démarrée affiche le résultat', () {
    testWidgets('CA6, CA19 : après l\'analyse au démarrage, la liste montre '
        'les puces de l\'entrée étiquetée, sans la mention du détail', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final repo = FakeEntryRepository();
      repo.seed(
        mood: 4,
        text: 'Longue journée au travail.',
        createdAt: DateTime(2026, 10, 14, 21, 40),
      );
      final analyzer = FakeMoodAnalyzer(
        results: {'Longue journée au travail.': Tagged(fatigueCalmeTravail)},
      );
      final app = await tester.runAsync(
        () => startApp(
          open: () async => journalOf(
            repo,
            FakeModelDownloader(readyModel),
            analyzer: analyzer,
          ),
        ),
      );
      final queue = queueOf(app!);
      try {
        await tester.runAsync(
          () => queue.whenIdle.timeout(const Duration(seconds: 5)),
        );

        await tester.pumpWidget(app);
        await settle(tester);

        expect(find.text('fatigue'), findsOneWidget);
        expect(find.text('calme'), findsOneWidget);
        expect(find.text('travail'), findsOneWidget);
        expect(find.text('Analysé sur ton téléphone'), findsNothing);
      } finally {
        await tester.runAsync(queue.stop);
      }
    });

    testWidgets('CA20, cas limite : une analyse en cours se voit sur la carte, '
        'et la saisie d\'une nouvelle entrée n\'est pas bloquée', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final repo = FakeEntryRepository(clock: () => fixedNow);
      repo.seed(
        mood: 3,
        text: 'Appel avec ma sœur.',
        createdAt: DateTime(2026, 10, 14, 18, 5),
      );
      final analyzer = FakeMoodAnalyzer(delays: {'Appel avec ma sœur.': null});
      final app = await tester.runAsync(
        () => startApp(
          open: () async => journalOf(
            repo,
            FakeModelDownloader(readyModel),
            analyzer: analyzer,
          ),
        ),
      );
      final queue = queueOf(app!);
      try {
        await tester.runAsync(() => until(() => analyzer.received.isNotEmpty));
        await tester.pumpWidget(app);
        await settle(tester);

        expect(
          find.text('Analyse en cours sur ton téléphone…'),
          findsOneWidget,
        );

        await openForm(tester);
        await pickMood(tester, 4);
        await tester.enterText(textInput, 'Journée calme.');
        await tester.pump();
        await tester.tap(find.text('Enregistrer'));
        await settle(tester);

        expect(find.text('Ton journal'), findsOneWidget);
        expect(find.textContaining('Journée calme.'), findsOneWidget);
        expect(repo.entries, hasLength(2));
        expect(analyzer.maxConcurrent, 1);
        expect(analyzer.received, ['Appel avec ma sœur.']);
      } finally {
        await tester.runAsync(queue.stop);
      }
    });
  });
}
