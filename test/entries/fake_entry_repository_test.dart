// Le faux dépôt suit le contrat du vrai (`DriftEntryRepository.saveAnalysis`, spec
// 004, CA16) : un résultat n'est écrit que sur une entrée « en attente ».
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/analysis/mood_analyzer.dart';
import 'package:tidemark/entries/entry.dart';

import '../support/fake_entry_repository.dart';

void main() {
  final oct10 = DateTime(2026, 10, 10, 9);

  for (final status in [
    AnalysisStatus.tagged,
    AnalysisStatus.untagged,
    AnalysisStatus.skipped,
  ]) {
    test('saveAnalysis ne touche pas une entrée « ${status.name} », comme le '
        'vrai dépôt', () async {
      final repo = FakeEntryRepository();
      final e = repo.seed(
        mood: 3,
        text: 'Un texte',
        createdAt: oct10,
        status: status,
      );

      await repo.saveAnalysis(
        e.id,
        const Tagged([Tag('joie', TagKind.emotion)]),
      );

      final after = repo.entries.single;
      expect(after.analysisStatus, status);
      expect(after.tags, isEmpty);
    });
  }

  test('saveAnalysis écrit sur une entrée « en attente »', () async {
    final repo = FakeEntryRepository();
    final e = repo.seed(mood: 3, text: 'Un texte', createdAt: oct10);

    await repo.saveAnalysis(e.id, const Tagged([Tag('joie', TagKind.emotion)]));

    expect(repo.entries.single.analysisStatus, AnalysisStatus.tagged);
  });

  group('entriesBetween, comme le vrai dépôt (issue #51)', () {
    final from = DateTime.utc(2026, 10, 12);
    final to = DateTime.utc(2026, 10, 19);

    test('rend les entrées de la fenêtre, début compris et fin exclue, de la '
        'plus ancienne à la plus récente, puis par identifiant', () async {
      final repo = FakeEntryRepository();
      repo.seed(mood: 1, createdAt: from.subtract(const Duration(seconds: 1)));
      final atFrom = repo.seed(mood: 2, createdAt: from);
      final later = repo.seed(mood: 4, createdAt: DateTime.utc(2026, 10, 15));
      final sameA = repo.seed(mood: 3, createdAt: DateTime.utc(2026, 10, 13));
      final sameB = repo.seed(mood: 3, createdAt: DateTime.utc(2026, 10, 13));
      repo.seed(mood: 5, createdAt: to);

      final read = await repo.entriesBetween(from, to);

      expect(read.map((e) => e.id), [atFrom.id, sameA.id, sameB.id, later.id]);
    });

    test('lève l\'erreur de lecture configurée', () async {
      final repo = FakeEntryRepository()
        ..entriesBetweenError = StateError('illisible');
      repo.seed(mood: 3, createdAt: DateTime.utc(2026, 10, 14));

      await expectLater(repo.entriesBetween(from, to), throwsStateError);
    });

    test('garde la trace de ses appels et de leurs bornes', () async {
      final repo = FakeEntryRepository();

      await repo.entriesBetween(from, to);

      expect(repo.entriesBetweenCalls, [(fromUtc: from, toUtc: to)]);
    });
  });
}
