// Fonctions pures de la plage et du compteur (spec 009, CA9, CA14, CA24 et cas
// limites) : humeur du jour, nombre d'entrées de la semaine, libellé du compteur.
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/entries/week_summary.dart';
import 'package:tidemark/review/local_week.dart';

/// Entrée saisie à l'heure murale [local] avec le décalage [offsetHours] : l'instant
/// UTC en découle, comme le fait le dépôt.
Entry entryAt(
  DateTime local,
  int mood, {
  int id = 1,
  double offsetHours = 0,
  AnalysisStatus status = AnalysisStatus.skipped,
}) {
  final offset = Duration(minutes: (offsetHours * 60).round());
  return Entry(
    id: id,
    mood: mood,
    text: null,
    createdAt: DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
    ).subtract(offset),
    utcOffset: offset,
    analysisStatus: status,
  );
}

/// Semaine du lundi 12 au dimanche 18 octobre 2026.
final week = LocalWeek.containing(DateTime(2026, 10, 14));

DateTime day(int d, [int hour = 12, int minute = 0]) =>
    DateTime(2026, 10, 11 + d, hour, minute);

void main() {
  group('dayMoodsOfWeek (CA14, CA24)', () {
    test('CA14 : sept valeurs, du lundi au dimanche ; null sans entrée', () {
      final moods = dayMoodsOfWeek([
        entryAt(day(1), 4, id: 1),
        entryAt(day(3), 2, id: 2),
        entryAt(day(7), 5, id: 3),
      ], week);

      expect(moods, [4, null, 2, null, null, null, 5]);
    });

    test('CA14 : un journal vide donne sept null', () {
      expect(dayMoodsOfWeek(const [], week), List<int?>.filled(7, null));
    });

    test('CA14 : plusieurs entrées le même jour, la plus récente gagne, '
        'quel que soit l\'ordre de la liste', () {
      final early = entryAt(day(2, 8), 1, id: 1);
      final late = entryAt(day(2, 22), 5, id: 2);
      final middle = entryAt(day(2, 15), 3, id: 3);

      for (final entries in [
        [early, middle, late],
        [late, middle, early],
        [middle, late, early],
      ]) {
        expect(dayMoodsOfWeek(entries, week)[1], 5);
      }
    });

    test('CA14 : la plus récente est celle de la date de saisie, pas celle du '
        'plus grand identifiant', () {
      final recent = entryAt(day(2, 22), 2, id: 1);
      final older = entryAt(day(2, 8), 4, id: 9);

      expect(dayMoodsOfWeek([older, recent], week)[1], 2);
    });

    test('CA14 : même instant de saisie, le plus grand identifiant gagne', () {
      final a = entryAt(day(4, 10), 1, id: 3);
      final b = entryAt(day(4, 10), 4, id: 8);
      final c = entryAt(day(4, 10), 2, id: 5);

      expect(dayMoodsOfWeek([b, a, c], week)[3], 4);
      expect(dayMoodsOfWeek([a, c, b], week)[3], 4);
    });

    test('CA14 : les entrées des autres semaines sont ignorées', () {
      final moods = dayMoodsOfWeek([
        entryAt(DateTime(2026, 10, 11, 23, 59), 1, id: 1),
        entryAt(DateTime(2026, 10, 19, 0, 0), 2, id: 2),
        entryAt(DateTime(2026, 10, 12, 0, 0), 3, id: 3),
        entryAt(DateTime(2026, 10, 18, 23, 59), 4, id: 4),
      ], week);

      expect(moods, [3, null, null, null, null, null, 4]);
    });

    test('CA14 : une entrée en détresse ou non analysée compte comme les '
        'autres', () {
      final moods = dayMoodsOfWeek([
        entryAt(day(1), 1, id: 1, status: AnalysisStatus.skipped),
        entryAt(day(2), 3, id: 2, status: AnalysisStatus.pending),
        entryAt(day(3), 4, id: 3, status: AnalysisStatus.untagged),
        entryAt(day(4), 5, id: 4, status: AnalysisStatus.tagged),
      ], week);

      expect(moods.take(4), [1, 3, 4, 5]);
    });

    test('Fuseau changé : le jour est le jour local de la saisie, avec le '
        'décalage enregistré (comme le bilan)', () {
      // Samedi 17 octobre 23:30 à UTC+2 = samedi 21:30 UTC : jour local samedi.
      // Dimanche 18 octobre 00:30 à UTC+2 = samedi 22:30 UTC : jour local dimanche.
      final saturday = entryAt(
        DateTime(2026, 10, 17, 23, 30),
        2,
        id: 1,
        offsetHours: 2,
      );
      final sunday = entryAt(
        DateTime(2026, 10, 18, 0, 30),
        4,
        id: 2,
        offsetHours: 2,
      );

      expect(dayMoodsOfWeek([saturday, sunday], week), [
        null,
        null,
        null,
        null,
        null,
        2,
        4,
      ]);
    });

    test('Fuseau changé : lundi 00:30 à UTC+2 (dimanche en UTC) reste dans la '
        'semaine suivante', () {
      final nextMonday = entryAt(
        DateTime(2026, 10, 19, 0, 30),
        5,
        id: 1,
        offsetHours: 2,
      );

      expect(dayMoodsOfWeek([nextMonday], week), List<int?>.filled(7, null));
      expect(dayMoodsOfWeek([nextMonday], week.next)[0], 5);
    });

    test('Fuseau changé : dimanche 22:00 à UTC-5 (lundi en UTC) reste '
        'dimanche', () {
      final sunday = entryAt(
        DateTime(2026, 10, 18, 22, 0),
        3,
        id: 1,
        offsetHours: -5,
      );

      expect(dayMoodsOfWeek([sunday], week)[6], 3);
      expect(dayMoodsOfWeek([sunday], week.next)[0], isNull);
    });
  });

  group('entriesInWeek (CA9)', () {
    test('CA9 : 0 sans entrée', () {
      expect(entriesInWeek(const [], week), 0);
    });

    test('CA9 : compte toutes les entrées de la semaine, plusieurs le même '
        'jour comprises', () {
      final entries = [
        entryAt(day(1, 8), 3, id: 1),
        entryAt(day(1, 9), 3, id: 2),
        entryAt(day(1, 20), 3, id: 3),
        entryAt(day(5), 1, id: 4),
      ];

      expect(entriesInWeek(entries, week), 4);
    });

    test(
      'CA9 : quel que soit le statut, détresse et non analysée comprises',
      () {
        final entries = [
          for (final (i, status) in AnalysisStatus.values.indexed)
            entryAt(day(i + 1), 3, id: i + 1, status: status),
        ];

        expect(entriesInWeek(entries, week), AnalysisStatus.values.length);
      },
    );

    test('CA9 : les bornes de la semaine, lundi 00:00 et dimanche 23:59, en '
        'font partie ; la veille et le lendemain non', () {
      final entries = [
        entryAt(DateTime(2026, 10, 11, 23, 59), 3, id: 1),
        entryAt(DateTime(2026, 10, 12, 0, 0), 3, id: 2),
        entryAt(DateTime(2026, 10, 18, 23, 59), 3, id: 3),
        entryAt(DateTime(2026, 10, 19, 0, 0), 3, id: 4),
      ];

      expect(entriesInWeek(entries, week), 2);
    });

    test('Fuseau changé : chaque entrée est rangée dans la semaine de son '
        'jour local de saisie', () {
      final entries = [
        // Lundi 19 octobre 00:30 à UTC+2 : instant UTC dimanche 22:30, mais
        // semaine suivante.
        entryAt(DateTime(2026, 10, 19, 0, 30), 3, id: 1, offsetHours: 2),
        // Dimanche 18 octobre 22:00 à UTC-5 : instant UTC lundi, mais cette semaine.
        entryAt(DateTime(2026, 10, 18, 22, 0), 3, id: 2, offsetHours: -5),
      ];

      expect(entriesInWeek(entries, week), 1);
      expect(entriesInWeek(entries, week.next), 1);
    });
  });

  group('shellCountLabel (CA9)', () {
    test('CA9 : aucun, un, plusieurs', () {
      expect(shellCountLabel(0), 'Aucun coquillage cette semaine');
      expect(shellCountLabel(1), '1 coquillage cette semaine');
      expect(shellCountLabel(2), '2 coquillages cette semaine');
      expect(shellCountLabel(7), '7 coquillages cette semaine');
      expect(shellCountLabel(12), '12 coquillages cette semaine');
    });
  });
}
