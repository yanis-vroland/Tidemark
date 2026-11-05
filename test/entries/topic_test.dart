// Sujets (spec 010, « Définitions », CA1) : la liste fixe et ordonnée de six, leurs
// libellés, et l'absence de sujet par défaut sur une entrée. Code Dart pur.
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/entries/topic.dart';

import '../support/fake_entry_repository.dart';

void main() {
  group('la liste des sujets', () {
    test('CA1 : six sujets, dans l\'ordre de la liste de la spec', () {
      expect(Topic.values.map((t) => t.name), [
        'sommeil',
        'travail',
        'amis',
        'famille',
        'sport',
        'nature',
      ]);
    });

    test('CA1 : le libellé affiché est le nom du sujet', () {
      expect(Topic.values.map((t) => t.label), [
        'sommeil',
        'travail',
        'amis',
        'famille',
        'sport',
        'nature',
      ]);
    });
  });

  group('un sujet sur une entrée', () {
    Entry entryWith({List<Topic>? topics}) => topics == null
        ? Entry(
            id: 1,
            mood: 3,
            text: null,
            createdAt: DateTime.utc(2026, 10, 14, 19, 40),
            utcOffset: Duration.zero,
            analysisStatus: AnalysisStatus.skipped,
          )
        : Entry(
            id: 1,
            mood: 3,
            text: null,
            createdAt: DateTime.utc(2026, 10, 14, 19, 40),
            utcOffset: Duration.zero,
            analysisStatus: AnalysisStatus.skipped,
            topics: topics,
          );

    test('CA4 : une entrée construite sans sujet n\'en a aucun', () {
      expect(entryWith().topics, isEmpty);
    });

    test('CA4 : une entrée garde les sujets qu\'on lui donne', () {
      expect(entryWith(topics: [Topic.amis, Topic.sport]).topics, [
        Topic.amis,
        Topic.sport,
      ]);
    });
  });

  group('le dépôt factice des tests (support)', () {
    test('CA4 : addEntry range les sujets dans l\'ordre de la liste', () async {
      final repo = FakeEntryRepository();

      final saved = await repo.addEntry(
        mood: 4,
        topics: [Topic.nature, Topic.sommeil, Topic.amis],
      );

      expect(saved.topics, [Topic.sommeil, Topic.amis, Topic.nature]);
      expect(repo.entries.single.topics, saved.topics);
    });

    test('CA4 : seed accepte des sujets', () {
      final repo = FakeEntryRepository();

      final seeded = repo.seed(
        mood: 3,
        createdAt: DateTime(2026, 10, 14, 8),
        topics: [Topic.famille],
      );

      expect(seeded.topics, [Topic.famille]);
    });
  });
}
