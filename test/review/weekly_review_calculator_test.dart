// Calculateur du bilan (spec 006, « Règles de calcul », CA6 à CA15, CA20, CA35) :
// code Dart pur, sans écran, sans rédacteur ni modèle.
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/review/local_week.dart';
import 'package:tidemark/review/weekly_review.dart';
import 'package:tidemark/review/weekly_review_calculator.dart';

import '../support/review_harness.dart';

void main() {
  group('CA6 : seuil de 3 entrées', () {
    for (final count in [0, 1, 2]) {
      test('CA6 : $count entrée(s) dans la semaine : pas de bilan, seulement '
          'le nombre d\'entrées', () {
        final book = EntryBook();
        for (var i = 0; i < count; i++) {
          book.add(i + 1, 3);
        }
        final review = book.compute();
        expect(review, isA<InsufficientWeek>());
        expect(review.entryCount, count);
        expect(review.week, weekOct12);
      });
    }

    test('CA6 : trois entrées suffisent', () {
      final book = EntryBook()..addMoods([3, 3, 3]);
      expect(book.compute(), isA<ComputedWeek>());
    });

    test('CA6 : les entrées des autres semaines ne comptent pas : 2 dans la '
        'semaine, 5 la suivante', () {
      final book = EntryBook()
        ..addMoods([3, 3])
        ..addMoods([3, 3, 3, 3, 3], weeksBack: -1);
      final review = book.compute();
      expect(review, isA<InsufficientWeek>());
      expect(review.entryCount, 2);
    });

    test('CA6 : une entrée supprimée ne compte plus', () {
      final book = EntryBook()..addMoods([3, 3, 3]);
      expect(book.compute(), isA<ComputedWeek>());
      book.remove(book.entries.first);
      final review = book.compute();
      expect(review, isA<InsufficientWeek>());
      expect(review.entryCount, 2);
    });
  });

  group('limites de la semaine', () {
    test('le lundi 00:00 et le dimanche 23:59 comptent dans la semaine ; le '
        'lundi suivant 00:00 et le dimanche précédent 23:59 non', () {
      final entries = [
        localEntry(1, DateTime(2026, 10, 12, 0, 0)),
        localEntry(2, DateTime(2026, 10, 18, 23, 59)),
        localEntry(3, DateTime(2026, 10, 14, 12)),
        localEntry(4, DateTime(2026, 10, 19, 0, 0)),
        localEntry(5, DateTime(2026, 10, 11, 23, 59)),
      ];
      final review = const WeeklyReviewCalculator().compute(
        week: weekOct12,
        entries: entries,
        tagsByEntry: const {},
      );
      expect(review.entryCount, 3);
    });

    test(
      'changement d\'heure : une entrée de la nuit du changement reste '
      'dans la semaine de son jour local (nuit du 24 au 25 octobre 2026)',
      () {
        final entries = [
          localEntry(
            1,
            DateTime(2026, 10, 25, 1, 30),
            offset: const Duration(hours: 2),
          ),
          localEntry(
            2,
            DateTime(2026, 10, 25, 3, 30),
            offset: const Duration(hours: 1),
          ),
          localEntry(
            3,
            DateTime(2026, 10, 25, 23, 59),
            offset: const Duration(hours: 1),
          ),
          localEntry(
            4,
            DateTime(2026, 10, 26, 0, 10),
            offset: const Duration(hours: 1),
          ),
        ];
        final review = const WeeklyReviewCalculator().compute(
          week: LocalWeek.containing(DateTime(2026, 10, 25)),
          entries: entries,
          tagsByEntry: const {},
        );
        expect(review.entryCount, 3);
      },
    );

    test('CA7 : saisie le dimanche 18 octobre à 23:30 à UTC-8 (lundi 07:30 '
        'en UTC) : l\'entrée compte dans la semaine du 12, pas dans celle du '
        '19', () {
      final late = localEntry(
        1,
        DateTime(2026, 10, 18, 23, 30),
        offset: const Duration(hours: -8),
      );
      final others = [
        localEntry(2, DateTime(2026, 10, 12, 9)),
        localEntry(3, DateTime(2026, 10, 13, 9)),
      ];
      const calculator = WeeklyReviewCalculator();
      final thisWeek = calculator.compute(
        week: weekOct12,
        entries: [late, ...others],
        tagsByEntry: const {},
      );
      expect(thisWeek, isA<ComputedWeek>());
      expect(thisWeek.entryCount, 3);
      final nextWeek = calculator.compute(
        week: weekOct12.next,
        entries: [late, ...others],
        tagsByEntry: const {},
      );
      expect(nextWeek.entryCount, 0);
    });

    test('semaine à cheval sur deux années : les entrées du 29 décembre au '
        '4 janvier comptent ensemble', () {
      final entries = [
        localEntry(1, DateTime(2025, 12, 29, 9)),
        localEntry(2, DateTime(2025, 12, 31, 9)),
        localEntry(3, DateTime(2026, 1, 1, 9)),
        localEntry(4, DateTime(2026, 1, 4, 22)),
        localEntry(5, DateTime(2026, 1, 5, 9)),
      ];
      final review = const WeeklyReviewCalculator().compute(
        week: LocalWeek.containing(DateTime(2026, 1, 1)),
        entries: entries,
        tagsByEntry: const {},
      );
      expect(review.entryCount, 4);
    });
  });

  group('CA8 : toutes les entrées comptent, quel que soit leur statut', () {
    test('CA8 : 7 entrées dont une non analysée sans texte, une non analysée '
        'avec texte (détresse) et une en attente : 7', () {
      final book = EntryBook()
        ..add(1, 3, status: AnalysisStatus.skipped)
        ..add(2, 3, text: distressText, status: AnalysisStatus.skipped)
        ..add(3, 4, text: neutralText, status: AnalysisStatus.pending)
        ..add(4, 3, text: neutralText, status: AnalysisStatus.untagged)
        ..add(5, 3, tags: [emotionTag('joie')])
        ..add(6, 5)
        ..add(7, 4);
      final week = book.computed();
      expect(week.entryCount, 7);
    });
  });

  group('CA9 : humeur moyenne en dixièmes, la moitié vers le haut', () {
    final cases = <({List<int> moods, int tenths})>[
      (moods: [4, 3, 2, 4, 5, 3, 4], tenths: 36),
      (moods: [3, 4, 3, 4], tenths: 35),
      (moods: [2, 3, 3], tenths: 27),
      (moods: [3, 3, 4, 4, 4, 4, 4, 4], tenths: 38),
    ];
    for (final c in cases) {
      test('CA9 : humeurs ${c.moods.join(', ')} : ${c.tenths} dixièmes', () {
        final book = EntryBook()..addMoods(c.moods);
        expect(book.computed().averageMoodTenths, c.tenths);
      });
    }

    test('CA9 : moyenne par entrée, pas par jour : une entrée à 5 puis deux '
        'entrées à 2 le même jour : 3,0, et non 3,5', () {
      final book = EntryBook()
        ..add(1, 5)
        ..add(2, 2)
        ..add(2, 2);
      // (5 + 2 + 2) / 3 = 3,0 ; moyenne par jour : (5 + 2) / 2 = 3,5.
      expect(book.computed().averageMoodTenths, 30);
    });

    test('CA9 : toutes les entrées à 5 : 50 ; toutes à 2 : 20', () {
      expect(
        (EntryBook()..addMoods([5, 5, 5])).computed().averageMoodTenths,
        50,
      );
      expect(
        (EntryBook()..addMoods([2, 2, 2])).computed().averageMoodTenths,
        20,
      );
    });

    test('formatTenths : virgule décimale, un chiffre après la virgule', () {
      expect(formatTenths(36), '3,6');
      expect(formatTenths(30), '3,0');
      expect(formatTenths(35), '3,5');
      expect(formatTenths(10), '1,0');
      expect(formatTenths(50), '5,0');
    });
  });

  group('CA10 : répartition des humeurs', () {
    test(
      'CA10 : humeurs 4, 3, 2, 4, 5, 3, 4 : 0, 1, 2, 3, 1 (zéros compris)',
      () {
        final book = EntryBook()..addMoods([4, 3, 2, 4, 5, 3, 4]);
        expect(book.computed().moodCounts, [0, 1, 2, 3, 1]);
      },
    );

    test('CA10 : cinq entiers même quand une seule humeur est présente', () {
      final book = EntryBook()..addMoods([5, 5, 5]);
      expect(book.computed().moodCounts, [0, 0, 0, 0, 3]);
    });
  });

  group('CA11 : jours notés', () {
    test('CA11 : entrées lundi, mardi, jeudi, samedi (deux fois) et '
        'dimanche (deux fois) : jours 1, 2, 4, 6, 7', () {
      final book = EntryBook()
        ..addMoods([4, 3, 2, 4, 5, 3, 4], days: [1, 1, 2, 4, 6, 6, 7]);
      expect(book.computed().notedDays, [1, 2, 4, 6, 7]);
    });

    test('CA11 : 3 entrées le même jour : un seul jour noté', () {
      final book = EntryBook()..addMoods([3, 4, 5], days: [3, 3, 3]);
      expect(book.computed().notedDays, [3]);
    });

    test('CA11 : les sept jours', () {
      final book = EntryBook()..addMoods([3, 3, 3, 3, 3, 3, 3]);
      expect(book.computed().notedDays, [1, 2, 3, 4, 5, 6, 7]);
    });
  });

  group('CA12 : étiquettes fréquentes', () {
    EntryBook taggedBook() => EntryBook()
      ..add(1, 4, tags: [emotionTag('fatigue'), themeTag('travail')])
      ..add(
        2,
        3,
        tags: [emotionTag('fatigue'), emotionTag('calme'), themeTag('travail')],
      )
      ..add(
        3,
        3,
        tags: [emotionTag('fatigue'), emotionTag('calme'), themeTag('travail')],
      )
      ..add(4, 4, tags: [emotionTag('joie')]);

    test('CA12 : fatigue 3, travail 3, calme 2, joie 1 : dans cet ordre, '
        'les trois premières', () {
      final week = taggedBook().computed();
      expect(week.topTags, [
        TagCount(emotionTag('fatigue'), 3),
        TagCount(themeTag('travail'), 3),
        TagCount(emotionTag('calme'), 2),
      ]);
    });

    test('CA12 : à nombre égal, l\'ordre est alphabétique, émotions et '
        'thèmes mêlés', () {
      final book = EntryBook()
        ..add(1, 3, tags: [emotionTag('joie'), themeTag('amis')])
        ..add(
          2,
          3,
          tags: [emotionTag('joie'), emotionTag('calme'), themeTag('amis')],
        )
        ..add(3, 3, tags: [emotionTag('calme')]);
      expect(book.computed().topTags, [
        TagCount(themeTag('amis'), 2),
        TagCount(emotionTag('calme'), 2),
        TagCount(emotionTag('joie'), 2),
      ]);
    });

    test('CA12 : au plus trois étiquettes, la plus rare écartée', () {
      final week = taggedBook().computed();
      expect(week.topTags.length, 3);
      expect(week.topTags.map((t) => t.tag.label), isNot(contains('joie')));
    });

    test('CA12 : les faits transmis au modèle reprennent les libellés, dans '
        'l\'ordre des chiffres', () {
      final week = taggedBook().computed();
      expect(week.facts.topTagLabels, ['fatigue', 'travail', 'calme']);
    });

    test('CA12 : seules les entrées « étiquetées » comptent : une entrée en '
        'attente, sans étiquette ou non analysée ne compte pas, même si une '
        'table d\'étiquettes lui en prête', () {
      final book = EntryBook()
        ..add(1, 3, tags: [emotionTag('joie')])
        ..add(
          2,
          3,
          text: neutralText,
          status: AnalysisStatus.pending,
          tags: [emotionTag('joie'), emotionTag('calme')],
        )
        ..add(
          3,
          3,
          text: neutralText,
          status: AnalysisStatus.untagged,
          tags: [emotionTag('joie'), emotionTag('calme')],
        )
        ..add(
          4,
          3,
          text: neutralText,
          status: AnalysisStatus.skipped,
          tags: [emotionTag('joie'), emotionTag('calme')],
        );
      final week = book.computed();
      expect(week.topTags, [TagCount(emotionTag('joie'), 1)]);
    });

    test('CA12 : les étiquettes se comptent par entrée, sur la semaine '
        'affichée seulement', () {
      final book = EntryBook()
        ..addMoods([3, 3, 3])
        ..add(1, 3, tags: [emotionTag('joie')], weeksBack: 1)
        ..add(2, 3, tags: [emotionTag('joie')], weeksBack: 1)
        ..add(3, 3, tags: [emotionTag('joie')], weeksBack: 1);
      expect(book.computed().topTags, isEmpty);
    });
  });

  group('CA13 : aucune étiquette', () {
    test('CA13 : aucune entrée étiquetée : liste vide, faits sans libellé', () {
      final book = EntryBook()..addMoods([3, 4, 3]);
      final week = book.computed();
      expect(week.topTags, isEmpty);
      expect(week.facts.topTagLabels, isEmpty);
    });
  });

  group('CA14 : évolution par rapport à la semaine précédente', () {
    test(
      'CA14 : précédente de 5 entrées, moyenne 3,0 ; courante de 7 '
      'entrées, moyenne 3,6 : 30 dixièmes, 5 entrées, tendance en hausse',
      () {
        final book = EntryBook()
          ..addMoods([3, 3, 3, 3, 3], weeksBack: 1)
          ..addMoods([4, 3, 2, 4, 5, 3, 4]);
        final week = book.computed();
        expect(week.averageMoodTenths, 36);
        expect(week.comparison, isNotNull);
        expect(week.comparison!.averageMoodTenths, 30);
        expect(week.comparison!.entryCount, 5);
        expect(week.facts.trend, ReviewTrend.up);
      },
    );

    test('CA14 : moyennes arrondies égales : tendance stable', () {
      final book = EntryBook()
        ..addMoods([4, 3, 2, 4, 5, 3, 4], weeksBack: 1)
        ..addMoods([4, 3, 2, 4, 5, 3, 4]);
      final week = book.computed();
      expect(week.comparison!.averageMoodTenths, 36);
      expect(week.facts.trend, ReviewTrend.stable);
    });

    test(
      'CA14 : la tendance suit les moyennes arrondies, pas les exactes : '
      '3,1 (10 entrées) contre 3,142… (7 entrées, affichée 3,1) : stable',
      () {
        final book = EntryBook()
          ..addMoods([3, 3, 3, 3, 3, 3, 3, 3, 3, 4], weeksBack: 1)
          ..addMoods([4, 3, 3, 3, 3, 3, 3]); // somme 22 sur 7 : 3,142…
        final week = book.computed();
        expect(week.averageMoodTenths, 31);
        expect(week.comparison!.averageMoodTenths, 31);
        expect(week.facts.trend, ReviewTrend.stable);
      },
    );

    test(
      'CA14 : moyenne plus basse que la précédente : tendance en baisse',
      () {
        final book = EntryBook()
          ..addMoods([4, 4, 4, 4, 5], weeksBack: 1)
          ..addMoods([4, 3, 2, 4, 5, 3, 4]);
        final week = book.computed();
        expect(week.comparison!.averageMoodTenths, 42);
        expect(week.averageMoodTenths, 36);
        expect(week.facts.trend, ReviewTrend.down);
      },
    );

    test('CA14 : précédente d\'exactement 3 entrées : comparable', () {
      final book = EntryBook()
        ..addMoods([2, 2, 2], weeksBack: 1)
        ..addMoods([3, 3, 3]);
      final week = book.computed();
      expect(week.comparison, isNotNull);
      expect(week.comparison!.entryCount, 3);
      expect(week.facts.trend, ReviewTrend.up);
    });

    test('CA14 : la semaine précédente est celle du lundi d\'avant, pas '
        'celle d\'il y a deux semaines', () {
      final book = EntryBook()
        ..addMoods([5, 5, 5], weeksBack: 2)
        ..addMoods([3, 3, 3]);
      final week = book.computed();
      expect(week.comparison, isNull);
      expect(week.facts.trend, ReviewTrend.none);
    });

    test(
      'semaine précédente sensible : elle sert quand même à l\'évolution',
      () {
        final book = EntryBook()
          ..addMoods([1, 3, 3, 3], weeksBack: 1)
          ..addMoods([4, 4, 4]);
        final week = book.computed();
        expect(week.isSensitive, isFalse);
        expect(week.comparison, isNotNull);
        expect(week.comparison!.averageMoodTenths, 25);
        expect(week.facts.trend, ReviewTrend.up);
      },
    );
  });

  group('CA15 : pas de comparaison sans semaine précédente de 3 entrées', () {
    test('CA15 : semaine précédente de 2 entrées : pas d\'évolution, tendance '
        'sans objet', () {
      final book = EntryBook()
        ..addMoods([3, 3], weeksBack: 1)
        ..addMoods([4, 3, 2]);
      final week = book.computed();
      expect(week.comparison, isNull);
      expect(week.facts.trend, ReviewTrend.none);
    });

    test('CA15 : aucune entrée la semaine précédente', () {
      final book = EntryBook()..addMoods([4, 3, 2]);
      final week = book.computed();
      expect(week.comparison, isNull);
      expect(week.facts.trend, ReviewTrend.none);
    });
  });

  group('CA35 : libellé de la moyenne, depuis la moyenne exacte', () {
    test('CA35 : 11 entrées de somme 38 (3,4545…) : affichée 3,5, libellé '
        '« Neutre »', () {
      final book = EntryBook()..addMoods([3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4]);
      final week = book.computed();
      expect(week.averageMoodTenths, 35);
      expect(week.facts.averageMoodLabel, 'Neutre');
      expect(week.facts.trend, ReviewTrend.none);
    });

    test('CA35 : la tendance suit le signe de l\'évolution affichée : '
        '3,5 affichée des deux côtés (exacte 3,4545… contre 3,5) : stable', () {
      final book = EntryBook()
        ..addMoods([3, 4, 3, 4], weeksBack: 1)
        ..addMoods([3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4]);
      final week = book.computed();
      expect(week.averageMoodTenths, 35);
      expect(week.comparison!.averageMoodTenths, 35);
      expect(week.facts.trend, ReviewTrend.stable);
      expect(week.facts.averageMoodLabel, 'Neutre');
    });

    test('libellé : moyenne 3,6 → « Bien » ; 3,5 exactement → « Bien » (la '
        'moitié vers le haut) ; 2,5 exactement → « Neutre »', () {
      expect(
        (EntryBook()..addMoods([4, 3, 2, 4, 5, 3, 4]))
            .computed()
            .facts
            .averageMoodLabel,
        'Bien',
      );
      expect(
        (EntryBook()..addMoods([3, 4, 3, 4])).computed().facts.averageMoodLabel,
        'Bien',
      );
      expect(
        (EntryBook()..addMoods([2, 3, 2, 3])).computed().facts.averageMoodLabel,
        'Neutre',
      );
    });

    test('libellé : un libellé de RM3 pour chaque moyenne entière', () {
      const labels = ['Très bas', 'Bas', 'Neutre', 'Bien', 'Très bien'];
      for (var mood = 1; mood <= 5; mood++) {
        final book = EntryBook()..addMoods([mood, mood, mood]);
        expect(book.computed().facts.averageMoodLabel, labels[mood - 1]);
      }
    });
  });

  group('régularité', () {
    // Nombre de jours notés → classe, avec au moins 3 entrées au total.
    final cases = <int, WeekRegularity>{
      1: WeekRegularity.fewDays,
      2: WeekRegularity.fewDays,
      3: WeekRegularity.someDays,
      4: WeekRegularity.someDays,
      5: WeekRegularity.mostDays,
      6: WeekRegularity.mostDays,
      7: WeekRegularity.everyDay,
    };
    cases.forEach((days, expected) {
      test('$days jour(s) noté(s) : ${expected.name}', () {
        final book = EntryBook();
        for (var d = 1; d <= days; d++) {
          book.add(d, 3);
        }
        while (book.entries.length < 3) {
          book.add(1, 3);
        }
        final week = book.computed();
        expect(week.notedDays.length, days);
        expect(week.facts.regularity, expected);
      });
    });
  });

  group('CA20 : semaine sensible, chaque critère seul', () {
    // Deux entrées sans texte (lundi à 3, mardi à 4) ; chaque test ajoute la
    // troisième, celle qui déclenche (ou non) le critère.
    EntryBook base() => EntryBook()
      ..add(1, 3)
      ..add(2, 4);

    test('semaine ordinaire : non sensible', () {
      final book = base()..add(3, 3);
      expect(book.computed().isSensitive, isFalse);
    });

    test('semaine avec des textes ordinaires, en attente, étiquetés ou sans '
        'étiquette : non sensible', () {
      final book = base()
        ..add(3, 3, text: neutralText, status: AnalysisStatus.pending)
        ..add(4, 2, text: neutralText, tags: [emotionTag('calme')])
        ..add(5, 3, text: neutralText, status: AnalysisStatus.untagged);
      expect(book.computed().isSensitive, isFalse);
    });

    test('CA20 critère 1 : une entrée à l\'humeur 1 (« Très bas »), sans '
        'texte : sensible', () {
      final book = base()..add(3, 1);
      expect(book.computed().isSensitive, isTrue);
    });

    test('CA20 critère 1 : l\'humeur 2 ne suffit pas', () {
      final book = base()..add(3, 2);
      expect(book.computed().isSensitive, isFalse);
    });

    test('CA20 critère 2 : une entrée avec texte et le statut « non '
        'analysée » (humeur 3) : sensible', () {
      final book = base()
        ..add(3, 3, text: neutralText, status: AnalysisStatus.skipped);
      expect(book.computed().isSensitive, isTrue);
    });

    test('CA20 critère 2 : « non analysée » sans texte ne suffit pas', () {
      final book = base()..add(3, 3, status: AnalysisStatus.skipped);
      expect(book.computed().isSensitive, isFalse);
    });

    for (final status in [
      AnalysisStatus.pending,
      AnalysisStatus.untagged,
      AnalysisStatus.tagged,
    ]) {
      test('CA20 critère 3 : texte détecté par detectInText, statut '
          '${status.name} (humeur 3) : sensible', () {
        final book = base()
          ..add(
            3,
            3,
            text: distressText,
            status: status,
            tags: status == AnalysisStatus.tagged
                ? [emotionTag('tristesse')]
                : null,
          );
        expect(book.computed().isSensitive, isTrue);
      });
    }

    test('CA20 critère 3 : un texte banal en attente ne rend pas la semaine '
        'sensible', () {
      final book = base()
        ..add(
          3,
          3,
          text: 'Un texte tout à fait banal.',
          status: AnalysisStatus.pending,
        );
      expect(book.computed().isSensitive, isFalse);
    });

    test('CA20 : une entrée sensible d\'une autre semaine ne rend pas la '
        'semaine sensible', () {
      final book = base()
        ..add(3, 3)
        ..add(1, 1, weeksBack: 1)
        ..add(
          2,
          3,
          text: distressText,
          status: AnalysisStatus.skipped,
          weeksBack: 1,
        )
        ..add(5, 1, weeksBack: -1);
      expect(book.computed().isSensitive, isFalse);
    });

    test('CA20 : une semaine sensible reste calculée : les chiffres existent '
        'quand même', () {
      final book = base()..add(3, 1);
      final week = book.computed();
      expect(week.isSensitive, isTrue);
      expect(week.entryCount, 3);
      expect(week.averageMoodTenths, 27);
      expect(week.moodCounts, [1, 0, 1, 1, 0]);
    });
  });

  group('faits transmis au modèle (RM51)', () {
    test('la semaine de la maquette : « Bien », presque chaque jour, trois '
        'étiquettes, en hausse', () {
      final book = EntryBook()
        ..addMoods([3, 3, 3, 3, 3], weeksBack: 1)
        ..add(1, 4, tags: [emotionTag('fatigue'), themeTag('travail')])
        ..add(
          1,
          3,
          tags: [
            emotionTag('fatigue'),
            emotionTag('calme'),
            themeTag('travail'),
          ],
        )
        ..add(
          2,
          2,
          tags: [
            emotionTag('fatigue'),
            emotionTag('calme'),
            themeTag('travail'),
          ],
        )
        ..add(4, 4, tags: [emotionTag('joie')])
        ..add(6, 5)
        ..add(6, 3)
        ..add(7, 4);
      final week = book.computed();
      expect(
        week.facts,
        const ReviewFacts(
          averageMoodLabel: 'Bien',
          regularity: WeekRegularity.mostDays,
          topTagLabels: ['fatigue', 'travail', 'calme'],
          trend: ReviewTrend.up,
        ),
      );
    });
  });

  group('calcul pur', () {
    test('le même journal donne deux fois le même bilan, sans état', () {
      final book = EntryBook()..addMoods([4, 3, 2, 4, 5, 3, 4]);
      final first = book.computed();
      final second = book.computed();
      expect(second.averageMoodTenths, first.averageMoodTenths);
      expect(second.moodCounts, first.moodCounts);
      expect(second.facts, first.facts);
    });

    test('l\'ordre des entrées reçues ne change rien', () {
      final book = EntryBook()..addMoods([4, 3, 2, 4, 5, 3, 4]);
      final forward = book.computed();
      book.entries.setAll(0, book.entries.reversed.toList());
      final backward = book.computed();
      expect(backward.averageMoodTenths, forward.averageMoodTenths);
      expect(backward.notedDays, forward.notedDays);
      expect(backward.moodCounts, forward.moodCounts);
    });
  });

  // Revue de sécurité (défense en profondeur, RM51) : seuls les libellés de la
  // liste fermée (RM19) peuvent atteindre le modèle, même si la base contenait
  // autre chose.
  test('une étiquette hors de la liste fermée ne compte pas et n\'est jamais '
      'transmise au rédacteur', () {
    final book = EntryBook()
      ..add(1, 3, tags: [emotionTag('Mon texte libre')])
      ..add(2, 3, tags: [emotionTag('Mon texte libre')])
      ..add(3, 3, tags: [emotionTag('joie')]);

    final review = book.computed();

    expect(review.topTags.map((t) => t.tag.label), ['joie']);
    expect(review.facts.topTagLabels, ['joie']);
  });
}
