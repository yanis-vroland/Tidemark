// EntryRepository.allEntriesWithTags (spec 005, « Données ») : toutes les entrées et
// leurs étiquettes, de la plus ancienne à la plus récente, pour l'export (CA4 à CA7).
// Dépôt réel sur une base en mémoire.
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/analysis/mood_analyzer.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/storage/app_database.dart';

void main() {
  late AppDatabase db;
  late DriftEntryRepository repo;
  late DateTime now;

  setUp(() {
    db = AppDatabase.memory();
    now = DateTime(2026, 10, 14, 21, 40);
    repo = DriftEntryRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  Future<Entry> add(DateTime at, int mood, [String? text]) async {
    now = at;
    return repo.addEntry(mood: mood, text: text);
  }

  test('CA4 : un journal vide rend une liste vide', () async {
    expect(await repo.allEntriesWithTags(), isEmpty);
  });

  test('CA4 : de la plus ancienne à la plus récente, quel que soit l\'ordre '
      'd\'enregistrement', () async {
    await add(DateTime(2026, 10, 14, 21, 40), 4, 'Troisième.');
    await add(DateTime(2026, 10, 12, 19, 30), 5, 'Première.');
    await add(DateTime(2026, 10, 13, 22, 5), 2, 'Deuxième.');

    final all = await repo.allEntriesWithTags();

    expect(
      [for (final e in all) e.text],
      ['Première.', 'Deuxième.', 'Troisième.'],
    );
  });

  test('CA4 : deux entrées au même instant sont départagées par leur '
      'identifiant, la plus ancienne d\'abord', () async {
    final at = DateTime(2026, 10, 14, 8, 15);
    final first = await add(at, 3, 'A');
    final second = await add(at, 3, 'B');
    final third = await add(at, 3, 'C');

    final all = await repo.allEntriesWithTags();

    expect([for (final e in all) e.id], [first.id, second.id, third.id]);
  });

  test('CA6 : toutes les entrées sont rendues, avec ou sans texte et quel que '
      'soit leur statut', () async {
    final withoutText = await add(DateTime(2026, 10, 14, 8), 3);
    final pending = await add(DateTime(2026, 10, 14, 9), 4, 'En attente.');
    final distress = await repo.addEntry(
      mood: 1,
      text: 'Détresse.',
      status: AnalysisStatus.skipped,
    );
    final tagged = await add(DateTime(2026, 10, 14, 11), 4, 'Étiquetée.');
    await repo.saveAnalysis(tagged.id, Tagged([Tag('calme', TagKind.emotion)]));
    final untagged = await add(DateTime(2026, 10, 14, 12), 4, 'Sans.');
    await repo.saveAnalysis(untagged.id, const Untagged());

    final all = await repo.allEntriesWithTags();

    expect(all, hasLength(5));
    final byId = {for (final e in all) e.id: e};
    expect(byId[withoutText.id]!.text, isNull);
    expect(byId[withoutText.id]!.analysisStatus, AnalysisStatus.skipped);
    expect(byId[pending.id]!.analysisStatus, AnalysisStatus.pending);
    expect(byId[distress.id]!.analysisStatus, AnalysisStatus.skipped);
    expect(byId[distress.id]!.text, 'Détresse.');
    expect(byId[tagged.id]!.analysisStatus, AnalysisStatus.tagged);
    expect(byId[untagged.id]!.analysisStatus, AnalysisStatus.untagged);
  });

  test('CA7 : chaque entrée porte ses étiquettes (type et libellé), une '
      'entrée sans étiquette a une liste vide', () async {
    final a = await add(DateTime(2026, 10, 13, 22, 5), 2, 'Nuit courte.');
    final b = await add(DateTime(2026, 10, 14, 8, 15), 3, 'Rien à dire.');
    final c = await add(DateTime(2026, 10, 14, 21, 40), 4, 'Balade.');
    await repo.saveAnalysis(
      a.id,
      Tagged([Tag('fatigue', TagKind.emotion), Tag('sommeil', TagKind.theme)]),
    );
    await repo.saveAnalysis(c.id, Tagged([Tag('calme', TagKind.emotion)]));

    final all = await repo.allEntriesWithTags();

    expect(all.map((e) => e.id), [a.id, b.id, c.id]);
    expect(all[0].tags, [
      Tag('fatigue', TagKind.emotion),
      Tag('sommeil', TagKind.theme),
    ]);
    expect(all[1].tags, isEmpty);
    expect(all[2].tags, [Tag('calme', TagKind.emotion)]);
  });

  test('CA5 : le décalage enregistré à la saisie est rendu avec l\'instant '
      'en UTC', () async {
    final local = DateTime(2026, 10, 14, 21, 40);
    await add(local, 3, 'Soirée.');

    final entry = (await repo.allEntriesWithTags()).single;

    expect(entry.utcOffset, local.timeZoneOffset);
    expect(entry.createdAt, local.toUtc());
    expect(entry.createdAt.isUtc, isTrue);
  });

  test('CA4 : le texte est rendu tel qu\'enregistré', () async {
    const text = 'Été à l\'île de Ré.\n  « très bien »  \n';
    await add(DateTime(2026, 10, 14, 8), 4, text);

    expect((await repo.allEntriesWithTags()).single.text, text);
  });
}
