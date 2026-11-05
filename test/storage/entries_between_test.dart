// Lecture bornée des entrées (issue #51) : `entriesBetween` rend les seules entrées
// saisies dans une fenêtre UTC, sans lire tout le journal. La célébration (spec 010,
// CA12) s'en sert pour la semaine en cours : fenêtre élargie d'un jour de chaque côté
// (`LocalWeek.utcWindow`), puis rangement par jour local de saisie (spec 006, CA7).
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/review/local_week.dart';
import 'package:tidemark/storage/app_database.dart';

void main() {
  late AppDatabase db;
  late DriftEntryRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = DriftEntryRepository(db);
  });

  tearDown(() async => await db.close());

  /// Enregistre une entrée saisie à l'instant [utc], avec le décalage local
  /// [offset] : simule une saisie faite dans un autre fuseau que la machine de test.
  Future<int> insertAt(
    DateTime utc, {
    int mood = 3,
    Duration offset = Duration.zero,
  }) => db
      .into(db.entries)
      .insert(
        EntriesCompanion.insert(
          mood: mood,
          body: const Value(null),
          createdAt: utc,
          utcOffsetMinutes: offset.inMinutes,
          analysisStatus: AnalysisStatus.skipped,
        ),
      );

  final from = DateTime.utc(2026, 10, 12);
  final to = DateTime.utc(2026, 10, 19);

  test('sans entrée, la lecture bornée est vide', () async {
    expect(await repo.entriesBetween(from, to), isEmpty);
  });

  test('la borne de début est comprise, celle de fin exclue', () async {
    await insertAt(from.subtract(const Duration(seconds: 1)), mood: 1);
    final atFrom = await insertAt(from, mood: 2);
    final beforeTo = await insertAt(
      to.subtract(const Duration(seconds: 1)),
      mood: 4,
    );
    await insertAt(to, mood: 5);

    final read = await repo.entriesBetween(from, to);

    expect(read.map((e) => e.id), [atFrom, beforeTo]);
    expect(read.map((e) => e.mood), [2, 4]);
  });

  test('les entrées sont rendues de la plus ancienne à la plus récente, puis '
      'par identifiant à instant égal', () async {
    final latest = await insertAt(DateTime.utc(2026, 10, 15, 20));
    final sameA = await insertAt(DateTime.utc(2026, 10, 13, 8));
    final sameB = await insertAt(DateTime.utc(2026, 10, 13, 8));
    final early = await insertAt(DateTime.utc(2026, 10, 12, 6));

    final read = await repo.entriesBetween(from, to);

    expect(read.map((e) => e.id), [early, sameA, sameB, latest]);
  });

  test(
    'chaque entrée garde son instant UTC et son décalage enregistré',
    () async {
      final id = await insertAt(
        DateTime.utc(2026, 10, 14, 19, 40),
        mood: 4,
        offset: const Duration(hours: 2),
      );

      final entry = (await repo.entriesBetween(from, to)).single;

      expect(entry.id, id);
      expect(entry.mood, 4);
      expect(entry.createdAt, DateTime.utc(2026, 10, 14, 19, 40));
      expect(entry.createdAt.isUtc, isTrue);
      expect(entry.utcOffset, const Duration(hours: 2));
      expect(entry.localCreatedAt.hour, 21);
    },
  );

  test('une fenêtre vide ou inversée ne rend rien', () async {
    await insertAt(DateTime.utc(2026, 10, 14, 12));

    expect(await repo.entriesBetween(from, from), isEmpty);
    expect(await repo.entriesBetween(to, from), isEmpty);
  });

  group('semaine locale (spec 006, CA7)', () {
    final week = LocalWeek.containing(DateTime(2026, 10, 14));

    Future<List<Entry>> readWeek() async {
      final window = week.utcWindow;
      final read = await repo.entriesBetween(window.fromUtc, window.toUtc);
      return [
        for (final e in read)
          if (week.containsDay(e.localCreatedAt)) e,
      ];
    }

    test('une entrée du dimanche 23:30 saisie à UTC-10 (lundi 09:30 UTC) '
        'compte dans la semaine de ce dimanche', () async {
      final id = await insertAt(
        DateTime.utc(2026, 10, 19, 9, 30),
        offset: const Duration(hours: -10),
      );

      expect((await readWeek()).map((e) => e.id), [id]);
    });

    test('une entrée du lundi 00:30 saisie à UTC+14 (dimanche 10:30 UTC de la '
        'semaine d\'avant) compte dans la semaine de ce lundi', () async {
      final id = await insertAt(
        DateTime.utc(2026, 10, 11, 10, 30),
        offset: const Duration(hours: 14),
      );

      expect((await readWeek()).map((e) => e.id), [id]);
    });

    test('une entrée du lundi suivant 00:30 saisie à UTC+2 (dimanche 22:30 '
        'UTC) ne compte pas dans la semaine', () async {
      await insertAt(
        DateTime.utc(2026, 10, 18, 22, 30),
        offset: const Duration(hours: 2),
      );
      await insertAt(
        DateTime.utc(2026, 10, 11, 21, 30),
        offset: const Duration(hours: -2),
      );

      expect(await readWeek(), isEmpty);
    });

    test('les entrées hors de la fenêtre élargie ne sont pas lues', () async {
      await insertAt(DateTime.utc(2026, 10, 10, 23, 59));
      await insertAt(DateTime.utc(2026, 10, 20, 0, 0));
      final inside = await insertAt(DateTime.utc(2026, 10, 14, 12));

      final window = week.utcWindow;
      final read = await repo.entriesBetween(window.fromUtc, window.toUtc);

      expect(read.map((e) => e.id), [inside]);
    });
  });
}
