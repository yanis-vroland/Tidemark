// Vérification au démarrage des entrées « en attente » (spec 002, CA15, CA16, RM5).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/distress/startup_screening.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/entries/entry_repository.dart';
import 'package:tidemark/main.dart';

import '../support/fake_entry_repository.dart';
import '../support/fake_model_downloader.dart';
import '../support/fake_settings_repository.dart';
import '../support/ui_harness.dart';

final day = DateTime.utc(2026, 10, 10, 12);

/// Dépôt dont la lecture des entrées « en attente » échoue.
class UnreadableRepository extends FakeEntryRepository {
  @override
  Future<List<Entry>> pendingEntriesWithText() async =>
      throw StateError('lecture impossible');
}

/// Dépôt qui note les lectures et les tentatives de marquage, pour vérifier que la
/// vérification a bien été tentée même quand elle échoue.
class RecordingRepository extends FakeEntryRepository {
  final List<int> attemptedIds = [];
  int reads = 0;

  @override
  Future<List<Entry>> pendingEntriesWithText() {
    reads++;
    return super.pendingEntriesWithText();
  }

  @override
  Future<void> markSkipped(Iterable<int> ids) {
    attemptedIds.addAll(ids);
    return super.markSkipped(ids);
  }
}

class RecordingUnreadableRepository extends UnreadableRepository {
  int reads = 0;

  @override
  Future<List<Entry>> pendingEntriesWithText() {
    reads++;
    return super.pendingEntriesWithText();
  }
}

Map<int, AnalysisStatus> statuses(EntryRepository repo) {
  final fake = repo as FakeEntryRepository;
  return {for (final e in fake.entries) e.id: e.analysisStatus};
}

void main() {
  group('screenPendingEntries', () {
    test('CA15 : les entrées en détresse passent en « non analysée », les '
        'autres restent « en attente »', () async {
      final repo = FakeEntryRepository();
      final distress = repo.seed(
        mood: 2,
        text: 'J’ai envie de mourir.',
        createdAt: day,
      );
      final calm = repo.seed(
        mood: 4,
        text: 'Belle journée.',
        createdAt: day.add(const Duration(days: 1)),
      );
      final distressToo = repo.seed(
        mood: 3,
        text: 'je suis FATIGUÉE\nde vivre',
        createdAt: day.add(const Duration(days: 2)),
      );

      await screenPendingEntries(repo);

      final after = statuses(repo);
      expect(after[distress.id], AnalysisStatus.skipped);
      expect(after[distressToo.id], AnalysisStatus.skipped);
      expect(after[calm.id], AnalysisStatus.pending);
    });

    test('CA15 : le texte et l\'humeur des entrées ne changent pas', () async {
      final repo = FakeEntryRepository();
      final distress = repo.seed(
        mood: 2,
        text: 'envie de mourir',
        createdAt: day,
      );

      await screenPendingEntries(repo);

      final after = repo.entries.single;
      expect(after.id, distress.id);
      expect(after.text, 'envie de mourir');
      expect(after.mood, 2);
      expect(after.createdAt, distress.createdAt);
    });

    test('CA15 : les entrées sans texte ou déjà analysées ne sont pas '
        'touchées', () async {
      final repo = FakeEntryRepository();
      final noText = repo.seed(mood: 1, createdAt: day);
      final tagged = repo.seed(
        mood: 3,
        text: 'Journée calme.',
        createdAt: day.add(const Duration(days: 1)),
        status: AnalysisStatus.tagged,
      );
      final alreadySkipped = repo.seed(
        mood: 2,
        text: 'envie de mourir',
        createdAt: day.add(const Duration(days: 2)),
        status: AnalysisStatus.skipped,
      );

      await screenPendingEntries(repo);

      final after = statuses(repo);
      expect(after[noText.id], AnalysisStatus.skipped);
      expect(after[tagged.id], AnalysisStatus.tagged);
      expect(after[alreadySkipped.id], AnalysisStatus.skipped);
    });

    test('CA15 : un journal sans entrée en attente ne pose pas de '
        'problème', () async {
      final repo = FakeEntryRepository();

      await screenPendingEntries(repo);

      expect(repo.entries, isEmpty);
    });

    test('CA15 : une seconde vérification ne change rien', () async {
      final repo = FakeEntryRepository();
      repo.seed(mood: 2, text: 'envie de mourir', createdAt: day);
      repo.seed(mood: 4, text: 'Belle journée.', createdAt: day);
      await screenPendingEntries(repo);
      final once = statuses(repo);

      await screenPendingEntries(repo);

      expect(statuses(repo), once);
    });

    test('CA15 : le détecteur ne regarde pas l\'humeur, un texte en détresse à '
        '5 est aussi « non analysée »', () async {
      final repo = FakeEntryRepository();
      final entry = repo.seed(mood: 5, text: 'plutôt mourir', createdAt: day);

      await screenPendingEntries(repo);

      expect(statuses(repo)[entry.id], AnalysisStatus.skipped);
    });

    test('CA16 : une erreur pendant le marquage ne remonte pas, les entrées '
        'restent « en attente »', () async {
      final repo = FakeEntryRepository()
        ..markSkippedError = StateError('écriture impossible');
      final distress = repo.seed(
        mood: 2,
        text: 'envie de mourir',
        createdAt: day,
      );

      await screenPendingEntries(repo);

      expect(statuses(repo)[distress.id], AnalysisStatus.pending);
    });

    test('CA16 : une erreur de lecture ne remonte pas non plus', () async {
      await screenPendingEntries(UnreadableRepository());
    });

    test('CA16 : la vérification est refaite au démarrage suivant', () async {
      final repo = FakeEntryRepository()
        ..markSkippedError = StateError('écriture impossible');
      final distress = repo.seed(
        mood: 2,
        text: 'envie de mourir',
        createdAt: day,
      );
      await screenPendingEntries(repo);
      expect(statuses(repo)[distress.id], AnalysisStatus.pending);

      repo.markSkippedError = null;
      await screenPendingEntries(repo);

      expect(statuses(repo)[distress.id], AnalysisStatus.skipped);
    });
  });

  group('au démarrage de l\'app (startApp)', () {
    Future<Widget> start(WidgetTester tester, FakeEntryRepository repo) async {
      final app = await tester.runAsync(
        () => startApp(
          open: () async => Journal(
            entries: repo,
            settings: FakeSettingsRepository(),
            downloader: FakeModelDownloader(),
          ),
        ),
      );
      return app!;
    }

    testWidgets('CA15 : au démarrage, les entrées en détresse passent en « non '
        'analysée » et aucun écran d\'aide ne s\'affiche', (tester) async {
      usePhoneScreen(tester);
      final repo = FakeEntryRepository();
      final distress = repo.seed(
        mood: 2,
        text: 'J’ai envie de mourir.',
        createdAt: DateTime(2026, 10, 13, 22),
      );
      final calm = repo.seed(
        mood: 4,
        text: 'Belle journée.',
        createdAt: DateTime(2026, 10, 14, 8),
      );

      await tester.pumpWidget(await start(tester, repo));
      await settle(tester);

      expect(statuses(repo)[distress.id], AnalysisStatus.skipped);
      expect(statuses(repo)[calm.id], AnalysisStatus.pending);
      expect(find.text('Parler peut aider'), findsNothing);
      expect(find.text('Ton journal'), findsOneWidget);
      expect(find.text('Nouvelle entrée'), findsOneWidget);
    });

    testWidgets('CA16 : si la vérification échoue, l\'app s\'ouvre quand même '
        'sur la liste', (tester) async {
      usePhoneScreen(tester);
      final repo = RecordingRepository()
        ..markSkippedError = StateError('écriture impossible');
      final distress = repo.seed(
        mood: 2,
        text: 'envie de mourir',
        createdAt: DateTime(2026, 10, 13, 22),
      );

      final app = await start(tester, repo);
      await tester.pumpWidget(app);
      await settle(tester);

      expect(repo.attemptedIds, [distress.id], reason: 'vérification tentée');
      expect(app, isA<TidemarkApp>());
      expect(find.text('Ton journal'), findsOneWidget);
      expect(find.text('Parler peut aider'), findsNothing);
      expect(find.text("Ton journal n'a pas pu être ouvert"), findsNothing);
      expect(statuses(repo)[distress.id], AnalysisStatus.pending);
    });

    testWidgets(
      'CA16 : si la lecture des entrées échoue, l\'app s\'ouvre quand '
      'même sur la liste',
      (tester) async {
        usePhoneScreen(tester);

        final repo = RecordingUnreadableRepository();
        final app = await start(tester, repo);
        await tester.pumpWidget(app);
        await settle(tester);

        expect(repo.reads, 1, reason: 'vérification tentée');
        expect(app, isA<TidemarkApp>());
        expect(find.text('Parler peut aider'), findsNothing);
        expect(find.text("Ton journal n'a pas pu être ouvert"), findsNothing);
      },
    );
  });
}
