// Semaine locale et libellés de dates du bilan (spec 006, « Règles de calcul »,
// CA1, CA4, CA7, « Cas limites »). Code Dart pur : aucun écran.
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/review/local_week.dart';
import 'package:tidemark/review/weekly_review_calculator.dart';

import '../support/review_harness.dart';

/// Année, mois, jour : la date civile, sans dépendre du marquage UTC ou local.
List<int> ymd(DateTime d) => [d.year, d.month, d.day];

/// Tiret demi-cadratin, entouré d'espaces, des dates du bilan (CA4).
const dash = '–';

LocalWeek weekOf(int year, int month, int day) =>
    LocalWeek.containing(DateTime(year, month, day));

void main() {
  group('semaine du lundi au dimanche', () {
    test('chaque jour du 12 au 18 octobre 2026 tombe dans la semaine qui '
        'commence le lundi 12 et finit le dimanche 18', () {
      for (var day = 12; day <= 18; day++) {
        final week = weekOf(2026, 10, day);
        expect(ymd(week.monday), [2026, 10, 12], reason: 'lundi du $day');
        expect(ymd(week.sunday), [2026, 10, 18], reason: 'dimanche du $day');
      }
    });

    test('l\'heure du jour ne change pas la semaine : dimanche 23:59 reste '
        'dans la semaine, lundi 00:00 ouvre la suivante', () {
      expect(
        LocalWeek.containing(DateTime(2026, 10, 18, 23, 59)),
        weekOf(2026, 10, 12),
      );
      expect(
        LocalWeek.containing(DateTime(2026, 10, 19, 0, 0)),
        weekOf(2026, 10, 19),
      );
      expect(ymd(weekOf(2026, 10, 19).monday), [2026, 10, 19]);
    });

    test('`days` rend les sept jours, du lundi au dimanche', () {
      final days = weekOf(2026, 10, 14).days;
      expect(days.map(ymd).toList(), [
        for (var d = 12; d <= 18; d++) [2026, 10, d],
      ]);
    });

    test('`previous` et `next` donnent les semaines voisines', () {
      final week = weekOf(2026, 10, 14);
      expect(ymd(week.next.monday), [2026, 10, 19]);
      expect(ymd(week.previous.monday), [2026, 10, 5]);
      expect(week.next.previous, week);
      expect(week.previous.next, week);
    });

    test('deux semaines du même lundi sont égales et ont le même hashCode ; '
        'deux semaines voisines sont différentes', () {
      final a = LocalWeek.containing(DateTime(2026, 10, 14));
      final b = LocalWeek.containing(DateTime(2026, 10, 18, 23, 59));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(a.next));
    });

    test('`containsDay` : vrai du lundi au dimanche, faux la veille et le '
        'lendemain, sans tenir compte de l\'heure', () {
      final week = weekOf(2026, 10, 14);
      expect(week.containsDay(DateTime(2026, 10, 12)), isTrue);
      expect(week.containsDay(DateTime(2026, 10, 18, 23, 59)), isTrue);
      expect(week.containsDay(DateTime(2026, 10, 11, 23, 59)), isFalse);
      expect(week.containsDay(DateTime(2026, 10, 19)), isFalse);
    });

    test('les semaines se comparent dans l\'ordre du temps', () {
      final week = weekOf(2026, 10, 14);
      expect(week.previous.compareTo(week), isNegative);
      expect(week.compareTo(week), isZero);
      expect(week.next.compareTo(week), isPositive);
    });

    test('un jour marqué UTC donne la même semaine : seule la date civile '
        'compte', () {
      expect(
        LocalWeek.containing(DateTime.utc(2026, 10, 18)),
        weekOf(2026, 10, 14),
      );
    });
  });

  group('cas limites : changement d\'heure et changement d\'année', () {
    test('passage à l\'heure d\'été (dimanche 29 mars 2026) : la semaine a '
        'sept jours civils, la suivante commence le lundi 30', () {
      final week = weekOf(2026, 3, 29);
      expect(ymd(week.monday), [2026, 3, 23]);
      expect(ymd(week.sunday), [2026, 3, 29]);
      expect(week.days.map(ymd).toList(), [
        for (var d = 23; d <= 29; d++) [2026, 3, d],
      ]);
      expect(ymd(week.next.monday), [2026, 3, 30]);
      expect(ymd(weekOf(2026, 3, 30).previous.monday), [2026, 3, 23]);
    });

    test('passage à l\'heure d\'hiver (dimanche 25 octobre 2026) : la '
        'semaine a sept jours civils, la suivante commence le lundi 26', () {
      final week = weekOf(2026, 10, 25);
      expect(ymd(week.monday), [2026, 10, 19]);
      expect(week.days.map(ymd).toList(), [
        for (var d = 19; d <= 25; d++) [2026, 10, d],
      ]);
      expect(ymd(week.next.monday), [2026, 10, 26]);
      expect(LocalWeek.containing(DateTime(2026, 10, 25, 23, 59)), week);
      expect(LocalWeek.containing(DateTime(2026, 10, 26, 0, 30)), week.next);
    });

    test('changements d\'heure américains (8 mars, 1er novembre 2026) : '
        'mêmes semaines civiles', () {
      expect(ymd(weekOf(2026, 3, 8).monday), [2026, 3, 2]);
      expect(ymd(weekOf(2026, 3, 8).next.monday), [2026, 3, 9]);
      expect(ymd(weekOf(2026, 11, 1).monday), [2026, 10, 26]);
      expect(ymd(weekOf(2026, 11, 1).next.monday), [2026, 11, 2]);
    });

    test('semaine à cheval sur deux années : du lundi 29 décembre 2025 au '
        'dimanche 4 janvier 2026', () {
      final week = weekOf(2026, 1, 1);
      expect(ymd(week.monday), [2025, 12, 29]);
      expect(ymd(week.sunday), [2026, 1, 4]);
      expect(week.days.map(ymd).toList(), [
        [2025, 12, 29],
        [2025, 12, 30],
        [2025, 12, 31],
        [2026, 1, 1],
        [2026, 1, 2],
        [2026, 1, 3],
        [2026, 1, 4],
      ]);
      expect(ymd(week.next.monday), [2026, 1, 5]);
      expect(ymd(week.previous.monday), [2025, 12, 22]);
      expect(weekOf(2025, 12, 31), week);
    });

    test('année bissextile : le mardi 29 février 2028 est dans la semaine du '
        'lundi 28 février, la suivante commence le 6 mars', () {
      final week = weekOf(2028, 2, 29);
      expect(ymd(week.monday), [2028, 2, 28]);
      expect(ymd(week.next.monday), [2028, 3, 6]);
    });
  });

  group('CA1 : dates de la carte de la liste', () {
    test('CA1 : « Du lundi 12 au dimanche 18 octobre »', () {
      expect(
        weekCardLabel(weekOf(2026, 10, 14)),
        'Du lundi 12 au dimanche 18 octobre',
      );
    });

    test('CA1 : quand le mois change, les deux mois sont écrits : « Du lundi '
        '28 septembre au dimanche 4 octobre »', () {
      expect(
        weekCardLabel(weekOf(2026, 10, 1)),
        'Du lundi 28 septembre au dimanche 4 octobre',
      );
    });

    test('CA1 : quand l\'année change, l\'année suit chaque borne : « Du '
        'lundi 29 décembre 2025 au dimanche 4 janvier 2026 »', () {
      expect(
        weekCardLabel(weekOf(2026, 1, 1)),
        'Du lundi 29 décembre 2025 au dimanche 4 janvier 2026',
      );
    });

    test('CA1 : sans changement d\'année, pas d\'année, même pour une '
        'semaine d\'une autre année', () {
      expect(
        weekCardLabel(weekOf(2025, 10, 8)),
        'Du lundi 6 au dimanche 12 octobre',
      );
    });

    test('CA1 : les mois accentués s\'écrivent en toutes lettres', () {
      expect(
        weekCardLabel(weekOf(2026, 2, 11)),
        'Du lundi 9 au dimanche 15 février',
      );
      expect(
        weekCardLabel(weekOf(2026, 8, 5)),
        'Du lundi 3 au dimanche 9 août',
      );
      expect(
        weekCardLabel(weekOf(2026, 12, 2)),
        'Du lundi 30 novembre au dimanche 6 décembre',
      );
    });
  });

  group('CA4 : dates de l\'écran du bilan', () {
    test('CA4 : « 12 – 18 octobre » avec un tiret demi-cadratin entouré '
        'd\'espaces', () {
      final label = weekRangeLabel(weekOf(2026, 10, 14), currentYear: 2026);
      expect(label, '12 $dash 18 octobre');
      expect(
        label.contains('–'),
        isTrue,
        reason: 'U+2013, pas un trait d\'union',
      );
      expect(label.contains('-'), isFalse);
      expect(label.contains('—'), isFalse, reason: 'pas un cadratin');
    });

    test('CA4 : quand le mois change : « 28 septembre – 4 octobre »', () {
      expect(
        weekRangeLabel(weekOf(2026, 10, 1), currentYear: 2026),
        '28 septembre $dash 4 octobre',
      );
    });

    test('CA4 : semaine à cheval sur deux années, vue pendant la seconde : '
        '« 29 décembre 2025 – 4 janvier 2026 »', () {
      expect(
        weekRangeLabel(weekOf(2026, 1, 1), currentYear: 2026),
        '29 décembre 2025 $dash 4 janvier 2026',
      );
    });

    test('CA4 : semaine à cheval sur deux années, vue pendant la première : '
        'les deux bornes portent encore leur année', () {
      expect(
        weekRangeLabel(weekOf(2026, 1, 1), currentYear: 2025),
        '29 décembre 2025 $dash 4 janvier 2026',
      );
    });

    test('CA4 : semaine d\'une autre année que l\'année en cours : jour, mois '
        'et année aux deux bornes, même si le mois ne change pas', () {
      expect(
        weekRangeLabel(weekOf(2025, 10, 8), currentYear: 2026),
        '6 octobre 2025 $dash 12 octobre 2025',
      );
      expect(
        weekRangeLabel(weekOf(2025, 10, 1), currentYear: 2026),
        '29 septembre 2025 $dash 5 octobre 2025',
      );
    });

    test('CA4 : semaine de l\'année en cours : aucune année', () {
      expect(
        weekRangeLabel(weekOf(2025, 10, 8), currentYear: 2025),
        '6 $dash 12 octobre',
      );
    });

    test('CA4 : « Semaine en cours » pour la semaine courante', () {
      final current = weekOf(2026, 10, 14);
      expect(weekCaption(current, current: current), 'Semaine en cours');
    });

    test('CA4 : « Semaine dernière » pour la semaine précédente', () {
      final current = weekOf(2026, 10, 14);
      expect(
        weekCaption(current.previous, current: current),
        'Semaine dernière',
      );
    });

    test('CA4 : aucune mention pour les autres semaines', () {
      final current = weekOf(2026, 10, 14);
      expect(weekCaption(current.previous.previous, current: current), isNull);
      expect(weekCaption(weekOf(2026, 1, 1), current: current), isNull);
    });

    test('CA4 : aucune mention pour une semaine à venir', () {
      final current = weekOf(2026, 10, 14);
      expect(weekCaption(current.next, current: current), isNull);
    });
  });

  group(
    'CA7 : une entrée compte dans la semaine de son jour local de saisie',
    () {
      // Dimanche 18 octobre 2026, 23:30, heure murale du lieu de saisie.
      final sunday2330 = DateTime(2026, 10, 18, 23, 30);

      test('CA7 : saisie le dimanche à 23:30 à UTC+2 (21:30 en UTC) : semaine '
          'du 12 octobre', () {
        final entry = localEntry(
          1,
          sunday2330,
          offset: const Duration(hours: 2),
        );
        expect(weekOfEntry(entry), weekOf(2026, 10, 12));
      });

      test('CA7 : saisie le dimanche à 23:30 à UTC-8 (lundi 07:30 en UTC) : '
          'toujours la semaine du 12 octobre, pas celle du 19', () {
        final entry = localEntry(
          1,
          sunday2330,
          offset: const Duration(hours: -8),
        );
        expect(entry.createdAt.weekday, DateTime.monday, reason: 'UTC : lundi');
        expect(weekOfEntry(entry), weekOf(2026, 10, 12));
      });

      test('CA7 : saisie le lundi à 00:30 à UTC+9 (dimanche 15:30 en UTC) : '
          'semaine du 19 octobre, celle de son jour local', () {
        final entry = localEntry(
          1,
          DateTime(2026, 10, 19, 0, 30),
          offset: const Duration(hours: 9),
        );
        expect(
          entry.createdAt.weekday,
          DateTime.sunday,
          reason: 'UTC : dimanche',
        );
        expect(weekOfEntry(entry), weekOf(2026, 10, 19));
      });
    },
  );

  group('CA38 : le premier du mois s\'écrit « 1er »', () {
    test('CA38 : carte, dimanche 1er novembre : « Du lundi 26 octobre au '
        'dimanche 1er novembre »', () {
      expect(
        weekCardLabel(weekOf(2026, 10, 28)),
        'Du lundi 26 octobre au dimanche 1er novembre',
      );
    });

    test('CA38 : carte, lundi 1er février : « Du lundi 1er au dimanche 7 '
        'février »', () {
      expect(
        weekCardLabel(weekOf(2027, 2, 3)),
        'Du lundi 1er au dimanche 7 février',
      );
    });

    test(
      'CA38 : carte, dimanche 1er janvier, avec l\'année à chaque '
      'borne : « Du lundi 26 décembre 2022 au dimanche 1er janvier 2023 »',
      () {
        expect(
          weekCardLabel(weekOf(2022, 12, 28)),
          'Du lundi 26 décembre 2022 au dimanche 1er janvier 2023',
        );
      },
    );

    test('CA38 : écran du bilan, dimanche 1er novembre : « 26 octobre – '
        '1er novembre »', () {
      expect(
        weekRangeLabel(weekOf(2026, 10, 28), currentYear: 2026),
        '26 octobre $dash 1er novembre',
      );
    });

    test('CA38 : écran du bilan, lundi 1er février : « 1er – 7 février »', () {
      expect(
        weekRangeLabel(weekOf(2027, 2, 3), currentYear: 2027),
        '1er $dash 7 février',
      );
    });

    test('CA38 : écran du bilan, semaine d\'une autre année : le « 1er » '
        'garde son année', () {
      expect(
        weekRangeLabel(weekOf(2027, 2, 3), currentYear: 2026),
        '1er février 2027 $dash 7 février 2027',
      );
    });

    test('CA38 : les autres jours restent en chiffres seuls, y compris le '
        '2 et le 9', () {
      expect(
        weekCardLabel(weekOf(2026, 11, 3)),
        'Du lundi 2 au dimanche 8 novembre',
      );
      expect(
        weekRangeLabel(weekOf(2026, 11, 3), currentYear: 2026),
        '2 $dash 8 novembre',
      );
      expect(
        weekCardLabel(weekOf(2026, 11, 12)),
        'Du lundi 9 au dimanche 15 novembre',
      );
    });
  });
}
