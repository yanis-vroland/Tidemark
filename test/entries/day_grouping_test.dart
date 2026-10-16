import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/entries/day_grouping.dart';
import 'package:tidemark/entries/entry.dart';

Entry entryAt(
  int id,
  DateTime createdAtUtc, {
  Duration utcOffset = Duration.zero,
  int mood = 3,
}) => Entry(
  id: id,
  mood: mood,
  text: null,
  createdAt: createdAtUtc,
  utcOffset: utcOffset,
  analysisStatus: AnalysisStatus.skipped,
);

List<int> ids(DayGroup group) => [for (final e in group.entries) e.id];

void main() {
  final today = DateTime(2026, 10, 14, 21, 40);

  group('intertitre d\'un jour', () {
    test('CA3 : le jour même s\'appelle « Aujourd\'hui »', () {
      expect(dayLabel(DateTime(2026, 10, 14), today), "Aujourd'hui");
    });

    test('CA3 : la veille s\'appelle « Hier »', () {
      expect(dayLabel(DateTime(2026, 10, 13), today), 'Hier');
    });

    test('CA3 : sinon, le jour de la semaine et la date', () {
      expect(dayLabel(DateTime(2026, 10, 12), today), 'Lundi 12 octobre');
    });

    test('CA3 : l\'année s\'ajoute si elle diffère de l\'année en cours', () {
      expect(dayLabel(DateTime(2025, 10, 13), today), 'Lundi 13 octobre 2025');
    });

    test('CA3 : « Hier » passe la frontière d\'un mois', () {
      expect(
        dayLabel(DateTime(2026, 10, 31), DateTime(2026, 11, 1, 9)),
        'Hier',
      );
    });

    test('CA3 : « Hier » passe la frontière d\'une année, sans année', () {
      expect(dayLabel(DateTime(2025, 12, 31), DateTime(2026, 1, 1, 9)), 'Hier');
    });

    test('CA3 : le 31 décembre est daté avec l\'année au 2 janvier', () {
      expect(
        dayLabel(DateTime(2025, 12, 31), DateTime(2026, 1, 2, 9)),
        'Mercredi 31 décembre 2025',
      );
    });

    test('CA3 : les douze mois et leurs accents', () {
      const expected = {
        1: 'Lundi 5 janvier',
        2: 'Jeudi 5 février',
        3: 'Jeudi 5 mars',
        4: 'Dimanche 5 avril',
        5: 'Mardi 5 mai',
        6: 'Vendredi 5 juin',
        7: 'Dimanche 5 juillet',
        8: 'Mercredi 5 août',
        9: 'Samedi 5 septembre',
        10: 'Lundi 5 octobre',
        11: 'Jeudi 5 novembre',
        12: 'Samedi 5 décembre',
      };
      final lateInYear = DateTime(2026, 12, 31, 12);
      expected.forEach((month, label) {
        expect(dayLabel(DateTime(2026, month, 5), lateInYear), label);
      });
    });
  });

  group('libellés de date et d\'heure', () {
    test('CA16 : la date complète du détail porte l\'année', () {
      expect(fullDateLabel(DateTime(2026, 10, 14)), 'Mercredi 14 octobre 2026');
      expect(fullDateLabel(DateTime(2025, 10, 13)), 'Lundi 13 octobre 2025');
    });

    test('CA4 : l\'heure s\'écrit sur deux chiffres, « 21:40 »', () {
      expect(timeLabel(DateTime.utc(2026, 10, 14, 21, 40)), '21:40');
    });

    test('CA4 : l\'heure garde ses zéros, « 09:05 » et « 00:00 »', () {
      expect(timeLabel(DateTime.utc(2026, 10, 14, 9, 5)), '09:05');
      expect(timeLabel(DateTime.utc(2026, 10, 14, 0, 0)), '00:00');
      expect(timeLabel(DateTime.utc(2026, 10, 14, 23, 59)), '23:59');
    });
  });

  group('groupByDay', () {
    test('CA2 : aucune entrée, aucun groupe', () {
      expect(groupByDay(const [], today), isEmpty);
    });

    test('CA2 : jours du plus récent au plus ancien, entrées de la plus '
        'récente à la plus ancienne', () {
      final entries = [
        entryAt(1, DateTime.utc(2026, 10, 12, 19, 30)),
        entryAt(2, DateTime.utc(2026, 10, 14, 8, 15)),
        entryAt(3, DateTime.utc(2026, 10, 13, 22, 5)),
        entryAt(4, DateTime.utc(2026, 10, 14, 21, 40)),
        entryAt(5, DateTime.utc(2026, 10, 14, 12, 0)),
      ];

      final groups = groupByDay(entries, today);

      expect(groups.map((g) => g.label), [
        "Aujourd'hui",
        'Hier',
        'Lundi 12 octobre',
      ]);
      expect(ids(groups[0]), [4, 5, 2]);
      expect(ids(groups[1]), [3]);
      expect(ids(groups[2]), [1]);
    });

    test('CA2 : le résultat ne dépend pas de l\'ordre d\'entrée', () {
      final entries = [
        entryAt(1, DateTime.utc(2026, 10, 14, 8)),
        entryAt(2, DateTime.utc(2026, 10, 14, 21)),
        entryAt(3, DateTime.utc(2026, 10, 13, 9)),
      ];

      final forward = groupByDay(entries, today);
      final backward = groupByDay(entries.reversed.toList(), today);

      expect(backward.map((g) => g.label), forward.map((g) => g.label));
      expect(backward.map(ids).toList(), forward.map(ids).toList());
      expect(ids(forward[0]), [2, 1]);
    });

    test('CA6 : plusieurs entrées le même jour restent sous un seul '
        'intertitre, chacune dans son groupe', () {
      final entries = [
        entryAt(1, DateTime.utc(2026, 10, 14, 7)),
        entryAt(2, DateTime.utc(2026, 10, 14, 13)),
        entryAt(3, DateTime.utc(2026, 10, 14, 20)),
      ];

      final groups = groupByDay(entries, today);

      expect(groups, hasLength(1));
      expect(groups.single.label, "Aujourd'hui");
      expect(ids(groups.single), [3, 2, 1]);
    });

    test('CA3 : l\'intertitre d\'une autre année porte l\'année', () {
      final groups = groupByDay([
        entryAt(1, DateTime.utc(2025, 10, 13, 19, 30)),
      ], today);

      expect(groups.single.label, 'Lundi 13 octobre 2025');
    });

    test('CA2 : minuit, 23:59 et 00:00 tombent dans deux jours différents', () {
      final groups = groupByDay([
        entryAt(1, DateTime.utc(2026, 10, 13, 23, 59)),
        entryAt(2, DateTime.utc(2026, 10, 14, 0, 0)),
      ], today);

      expect(groups.map((g) => g.label), ["Aujourd'hui", 'Hier']);
      expect(ids(groups[0]), [2]);
      expect(ids(groups[1]), [1]);
    });

    test('CA2 : fuseau, le jour est celui du décalage enregistré, pas celui '
        'de l\'UTC', () {
      // 22:30 UTC avec +02:00 : 00:30 le 15 octobre, heure locale.
      final lateEvening = entryAt(
        1,
        DateTime.utc(2026, 10, 14, 22, 30),
        utcOffset: const Duration(hours: 2),
      );

      final groups = groupByDay([lateEvening], DateTime(2026, 10, 15, 9));

      expect(groups.single.label, "Aujourd'hui");
    });

    test('CA2 : fuseau, le même instant saisi avec un décalage négatif reste '
        'la veille', () {
      // 22:30 UTC avec -05:00 : 17:30 le 14 octobre, heure locale.
      final afternoon = entryAt(
        1,
        DateTime.utc(2026, 10, 14, 22, 30),
        utcOffset: const Duration(hours: -5),
      );

      final groups = groupByDay([afternoon], DateTime(2026, 10, 15, 9));

      expect(groups.single.label, 'Hier');
    });

    test('CA2 : fuseau, après un changement de fuseau chaque entrée garde '
        'son jour local, même si l\'UTC les confond', () {
      final beforeTravel = entryAt(
        1,
        DateTime.utc(2026, 10, 14, 22, 30),
        utcOffset: const Duration(hours: 2),
      ); // 15 octobre, 00:30 local
      final afterTravel = entryAt(
        2,
        DateTime.utc(2026, 10, 14, 22, 45),
      ); // 14 octobre, 22:45 local

      final groups = groupByDay([
        beforeTravel,
        afterTravel,
      ], DateTime(2026, 10, 15, 9));

      expect(groups.map((g) => g.label), ["Aujourd'hui", 'Hier']);
      expect(ids(groups[0]), [1]);
      expect(ids(groups[1]), [2]);
    });

    test('CA4 : fuseau, l\'heure affichée est l\'heure locale de la '
        'saisie', () {
      final e = entryAt(
        1,
        DateTime.utc(2026, 10, 14, 19, 40),
        utcOffset: const Duration(hours: 2),
      );

      expect(timeLabel(e.localCreatedAt), '21:40');
    });
  });

  group('CA38 : le premier du mois s\'écrit « 1er »', () {
    test('CA38 : jour de la semaine et date : « Dimanche 1er novembre »', () {
      expect(weekdayAndDate(DateTime(2026, 11, 1)), 'Dimanche 1er novembre');
    });

    test('CA38 : intertitre de la liste : « Dimanche 1er novembre »', () {
      expect(
        dayLabel(DateTime(2026, 11, 1), DateTime(2026, 11, 10, 9)),
        'Dimanche 1er novembre',
      );
    });

    test('CA38 : intertitre d\'une autre année : « Mercredi 1er janvier '
        '2025 »', () {
      expect(
        dayLabel(DateTime(2025, 1, 1), DateTime(2026, 10, 14, 21, 40)),
        'Mercredi 1er janvier 2025',
      );
    });

    test('CA38 : date complète du détail : « Mercredi 1er janvier 2025 »', () {
      expect(fullDateLabel(DateTime(2025, 1, 1)), 'Mercredi 1er janvier 2025');
      expect(
        fullDateLabel(DateTime(2026, 11, 1)),
        'Dimanche 1er novembre 2026',
      );
    });

    test('CA38 : le lendemain n\'est pas touché : « Lundi 2 novembre »', () {
      expect(
        dayLabel(DateTime(2026, 11, 2), DateTime(2026, 11, 10, 9)),
        'Lundi 2 novembre',
      );
      expect(weekdayAndDate(DateTime(2026, 11, 2)), 'Lundi 2 novembre');
    });

    test('CA38 : le 11 et le 21 restent en chiffres seuls', () {
      expect(weekdayAndDate(DateTime(2026, 11, 11)), 'Mercredi 11 novembre');
      expect(weekdayAndDate(DateTime(2026, 11, 21)), 'Samedi 21 novembre');
    });
  });
}
