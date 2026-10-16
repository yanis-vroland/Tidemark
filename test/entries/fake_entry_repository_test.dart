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
}
