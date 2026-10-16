import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/analysis/mood_analyzer.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/entries/entry_repository.dart';
import 'package:tidemark/storage/app_database.dart';

import '../support/fake_entry_repository.dart';

/// Dépôt à tester, et ce qu'il faut fermer à la fin du test.
typedef RepositoryHandle = ({
  EntryRepository repo,
  Future<void> Function() close,
});

const _tags = [
  Tag('tristesse', TagKind.emotion),
  Tag('joie', TagKind.emotion),
  Tag('travail', TagKind.theme),
];

const _settle = Duration(milliseconds: 150);

/// Laisse le temps à une émission tardive d'arriver.
Future<void> _settleStreams() async {
  await pumpEventQueue();
  await Future<void>.delayed(_settle);
  await pumpEventQueue();
}

/// Déclare les mêmes cas pour une fabrique de dépôt : le faux doit se comporter
/// comme le vrai.
void _watchEntryCases(String name, RepositoryHandle Function() create) {
  group('watchEntry ($name)', () {
    late EntryRepository repo;
    late Future<void> Function() close;
    final subscriptions = <StreamSubscription<Object?>>[];

    setUp(() {
      final handle = create();
      repo = handle.repo;
      close = handle.close;
    });

    tearDown(() async {
      for (final s in subscriptions) {
        await s.cancel();
      }
      subscriptions.clear();
      await close();
    });

    /// Collecte les émissions de `watchEntry(id)`, dans l'ordre.
    List<Entry?> collect(int id) {
      final emitted = <Entry?>[];
      subscriptions.add(repo.watchEntry(id).listen(emitted.add));
      return emitted;
    }

    test('première émission : l\'entrée avec son texte, son humeur et son '
        'statut', () async {
      final added = await repo.addEntry(mood: 4, text: 'Journée calme.');

      final entry = await repo.watchEntry(added.id).first;

      expect(entry, isNotNull);
      expect(entry!.id, added.id);
      expect(entry.text, 'Journée calme.');
      expect(entry.mood, 4);
      expect(entry.analysisStatus, AnalysisStatus.pending);
      expect(entry.tags, isEmpty);
    });

    test(
      'première émission : les étiquettes, dans l\'ordre enregistré',
      () async {
        final added = await repo.addEntry(mood: 2, text: 'Réunion pénible.');
        await repo.saveAnalysis(added.id, const Tagged(_tags));

        final entry = await repo.watchEntry(added.id).first;

        expect(entry, isNotNull);
        expect(entry!.analysisStatus, AnalysisStatus.tagged);
        expect(entry.tags, _tags);
      },
    );

    test('entrée modifiée : saveAnalysis émet l\'entrée « étiquetée » avec ses '
        'étiquettes', () async {
      final added = await repo.addEntry(mood: 3, text: 'Je cours demain.');
      final emitted = collect(added.id);
      await _settleStreams();
      expect(emitted.single?.analysisStatus, AnalysisStatus.pending);

      await repo.saveAnalysis(added.id, const Tagged(_tags));
      await _settleStreams();

      final last = emitted.last;
      expect(last, isNotNull);
      expect(last!.analysisStatus, AnalysisStatus.tagged);
      expect(last.tags, _tags);
    });

    test(
      'entrée modifiée : markSkipped émet le statut « non analysée »',
      () async {
        final added = await repo.addEntry(mood: 1, text: 'Tout va mal.');
        final emitted = collect(added.id);
        await _settleStreams();
        expect(emitted.single?.analysisStatus, AnalysisStatus.pending);

        await repo.markSkipped([added.id]);
        await _settleStreams();

        final last = emitted.last;
        expect(last, isNotNull);
        expect(last!.analysisStatus, AnalysisStatus.skipped);
      },
    );

    test('entrée supprimée : le flux émet null', () async {
      final added = await repo.addEntry(mood: 3, text: 'À effacer.');
      final emitted = collect(added.id);
      await _settleStreams();
      expect(emitted.single, isNotNull);

      await repo.deleteEntry(added.id);
      await _settleStreams();

      expect(emitted.last, isNull);
      expect(emitted, hasLength(2));
    });

    test('identifiant inexistant : la première émission est null', () async {
      expect(await repo.watchEntry(9999).first, isNull);
    });

    test('autres entrées : aucune émission quand elles sont ajoutées, '
        'étiquetées ou supprimées', () async {
      final observed = await repo.addEntry(mood: 3, text: 'Entrée observée.');
      final emitted = collect(observed.id);
      await _settleStreams();
      expect(emitted, hasLength(1));

      final other = await repo.addEntry(mood: 5, text: 'Une autre entrée.');
      await _settleStreams();
      await repo.saveAnalysis(other.id, const Tagged(_tags));
      await _settleStreams();
      await repo.deleteEntry(other.id);
      await _settleStreams();

      expect(emitted, hasLength(1));

      // Le flux reste vivant : une modification de l'entrée observée émet.
      await repo.saveAnalysis(observed.id, const Tagged(_tags));
      await _settleStreams();

      expect(emitted, hasLength(2));
      expect(emitted.last?.analysisStatus, AnalysisStatus.tagged);
      expect(emitted.last?.tags, _tags);
    });
  });
}

void main() {
  _watchEntryCases('base en mémoire', () {
    final db = AppDatabase.memory();
    final repo = DriftEntryRepository(
      db,
      clock: () => DateTime(2026, 10, 14, 21, 40),
    );
    return (repo: repo, close: db.close);
  });

  _watchEntryCases('dépôt factice', () {
    return (repo: FakeEntryRepository(), close: () async {});
  });
}
