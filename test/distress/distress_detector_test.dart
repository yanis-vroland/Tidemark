// Détecteur de détresse (spec 002) : code pur, sans Flutter ni base.
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/distress/distress_detector.dart';
import 'package:tidemark/entries/entry.dart';

import '../support/distress_harness.dart' show entryAt;

const detector = DistressDetector();

/// Instant de la saisie la plus récente des séries de test.
final newest = DateTime.utc(2026, 10, 14, 12);

/// [moods] de la plus récente à la plus ancienne, régulièrement espacées : la plus
/// ancienne est [span] avant la plus récente.
List<Entry> series(List<int> moods, Duration span) => [
  for (var i = 0; i < moods.length; i++)
    entryAt(
      moods[i],
      newest.subtract(
        moods.length == 1
            ? Duration.zero
            : Duration(
                microseconds: span.inMicroseconds * i ~/ (moods.length - 1),
              ),
      ),
      id: moods.length - i,
    ),
];

void main() {
  group('texte : normalisation (CA2)', () {
    test('CA2 : la phrase de la spec est détectée', () {
      expect(detector.detectInText('J’ai ENVIE de… mourir.'), isTrue);
    });

    test('CA2 : les majuscules sont ignorées', () {
      expect(detector.detectInText('ENVIE DE MOURIR'), isTrue);
      expect(detector.detectInText('Envie De Mourir'), isTrue);
    });

    test('CA2 : les accents sont ignorés, dans le texte comme dans la '
        'liste', () {
      expect(detector.detectInText('Je préfère mourir'), isTrue);
      expect(
        detector.detectInText('je voudrais me jeter par la fenêtre'),
        isTrue,
      );
      expect(detector.detectInText('Je suis FATIGUÉE de vivre'), isTrue);
      expect(detector.detectInText('envie de disparaître'), isTrue);
      expect(detector.detectInText('mettre fin à mes jours'), isTrue);
    });

    test('CA2 : l\'apostrophe typographique et l\'apostrophe droite valent une '
        'espace', () {
      expect(detector.detectInText('une lettre d’adieu'), isTrue);
      expect(detector.detectInText("une lettre d'adieu"), isTrue);
      expect(detector.detectInText('envie d’en finir'), isTrue);
      expect(detector.detectInText("m'ouvrir les veines"), isTrue);
    });

    test('CA2 : la ponctuation et les émoji valent une espace', () {
      expect(detector.detectInText('envie de, mourir'), isTrue);
      expect(detector.detectInText('envie de…mourir'), isTrue);
      expect(detector.detectInText('envie-de-mourir'), isTrue);
      expect(detector.detectInText('envie 😔 de 😔 mourir'), isTrue);
      expect(detector.detectInText('(me pendre)'), isTrue);
      expect(detector.detectInText('auto-mutilation'), isTrue);
    });

    test('CA2 : un retour à la ligne vaut une espace (cas limite « envie de\\n'
        'mourir »)', () {
      expect(detector.detectInText('envie de\nmourir'), isTrue);
      expect(detector.detectInText('envie de\r\nmourir'), isTrue);
      expect(detector.detectInText('envie\n\nde\n\n\nmourir'), isTrue);
      expect(detector.detectInText('envie\tde\tmourir'), isTrue);
    });

    test('CA2 : les espaces successives sont réduites à une seule', () {
      expect(detector.detectInText('envie     de     mourir'), isTrue);
    });

    test('CA2 : l\'expression peut être au début, à la fin ou seule', () {
      expect(detector.detectInText('suicide'), isTrue);
      expect(detector.detectInText('suicide, hier soir'), isTrue);
      expect(detector.detectInText('hier soir, suicide'), isTrue);
      expect(detector.detectInText('Hier soir j’ai écrit : me noyer'), isTrue);
    });

    test('normalize : minuscules, accents retirés, œ et æ décomposés', () {
      expect(DistressDetector.normalize('ÉTÉ à Noël, ça'), 'ete a noel ca');
      expect(DistressDetector.normalize('cœur'), 'coeur');
      expect(DistressDetector.normalize('CŒUR'), 'coeur');
      expect(DistressDetector.normalize('œuvre'), 'oeuvre');
      expect(DistressDetector.normalize('æther'), 'aether');
      expect(DistressDetector.normalize('ÆTHER'), 'aether');
    });

    test('normalize : tout ce qui n\'est ni lettre ni chiffre devient une '
        'espace, les espaces successives sont réduites', () {
      expect(
        DistressDetector.normalize('J’ai  envie…\nde (mourir)!'),
        'j ai envie de mourir',
      );
      expect(DistressDetector.normalize('a,b;c-d_e/f'), 'a b c d e f');
      expect(DistressDetector.normalize('rdv à 18h30'), 'rdv a 18h30');
    });

    test('Cas limite : un texte d\'émoji ou de ponctuation se normalise en '
        'chaîne vide et n\'est pas une détresse', () {
      for (final text in ['😔', '😔😔 !!! …', '?!', '\n\n', '', '   ']) {
        expect(DistressDetector.normalize(text), isEmpty, reason: '« $text »');
        expect(detector.detectInText(text), isFalse, reason: '« $text »');
      }
    });
  });

  group('texte : mots entiers (CA3)', () {
    test('CA3 : une expression dans un mot plus long, à gauche, n\'est pas '
        'détectée', () {
      expect(detector.detectInText('asuicide'), isFalse);
      expect(detector.detectInText('parasuicide'), isFalse);
      // « las de vivre » se termine par la fin de « hélas ».
      expect(detector.detectInText('hélas de vivre en ville'), isFalse);
      expect(detector.detectInText('xenvie de mourir'), isFalse);
    });

    test('CA3 : une expression dans un mot plus long, à droite, n\'est pas '
        'détectée', () {
      expect(detector.detectInText('suicidexyz'), isFalse);
      expect(detector.detectInText('plutot mourirent'), isFalse);
      expect(detector.detectInText('envie de mourire'), isFalse);
      expect(detector.detectInText('aucune issues'), isFalse);
    });

    test('CA3 : un chiffre collé à l\'expression fait partie du mot', () {
      expect(detector.detectInText('suicide2'), isFalse);
      expect(detector.detectInText('2suicide'), isFalse);
      expect(detector.detectInText('suicide 2'), isTrue);
    });

    test('CA3 : seule la forme entière compte quand une expression plus longue '
        'est coupée', () {
      expect(detector.detectInText('envie de'), isFalse);
      expect(detector.detectInText('me'), isFalse);
      expect(detector.detectInText('me tue'), isFalse);
    });
  });

  group('texte : ce qui ne déclenche pas (CA4)', () {
    const benign = [
      'Journée calme, balade au bord de l’eau.',
      'Ce boulot me tue.',
      'Je suis mort de rire.',
      'J’ai hâte d’en finir avec ce dossier.',
      'mourir',
      'en finir',
      'mort',
      'Week-end à la mer avec Léa. Pas de téléphone, juste le bruit des vagues.',
      'Encore une nuit trop courte. Je traîne toute la journée.',
    ];
    for (final text in benign) {
      test('CA4 : « $text » n\'est pas une détresse', () {
        expect(detector.detectInText(text), isFalse);
      });
    }
  });

  group('texte : formes niées (CA5)', () {
    test('CA5 : les exemples de la spec sont détectés', () {
      expect(detector.detectInText('je ne veux pas mourir'), isTrue);
      expect(detector.detectInText('je veux plus vivre'), isTrue);
    });

    test('CA5 : la négation n\'écarte aucune expression', () {
      expect(detector.detectInText('je ne voudrais pas mourir'), isTrue);
      expect(detector.detectInText('je n’ai plus envie de vivre'), isTrue);
      expect(detector.detectInText('je ne veux pas vivre'), isTrue);
      expect(detector.detectInText('je n’ai pas envie de vivre'), isTrue);
      expect(detector.detectInText('je ne suis pas suicidaire'), isTrue);
      expect(detector.detectInText('jamais je ne veux me tuer'), isTrue);
    });
  });

  group('degrés de sensibilité (RM25, RM29)', () {
    test('chaque degré porte son nombre d\'entrées et sa durée', () {
      expect(LowMoodSensitivity.high.entryCount, 2);
      expect(LowMoodSensitivity.high.days, 3);
      expect(LowMoodSensitivity.normal.entryCount, 3);
      expect(LowMoodSensitivity.normal.days, 7);
      expect(LowMoodSensitivity.low.entryCount, 5);
      expect(LowMoodSensitivity.low.days, 14);
      expect(LowMoodSensitivity.values, hasLength(3));
    });
  });

  group('série d\'humeurs basses (CA6, CA7)', () {
    for (final sensitivity in LowMoodSensitivity.values) {
      final n = sensitivity.entryCount;
      final d = Duration(days: sensitivity.days);
      final label =
          '${sensitivity.name} ($n entrées, ${sensitivity.days} jours)';

      group(label, () {
        test(
          'CA7 : les $n dernières entrées à 1, étalées sur exactement ${sensitivity.days} '
          'jours, déclenchent',
          () {
            expect(
              detector.detectLowMoodSeries(
                series(List.filled(n, 1), d),
                sensitivity,
              ),
              isTrue,
            );
          },
        );

        test('CA7 : les $n entrées à 1 en moins de ${sensitivity.days} jours '
            'déclenchent', () {
          expect(
            detector.detectLowMoodSeries(
              series(List.filled(n, 1), d - const Duration(hours: 5)),
              sensitivity,
            ),
            isTrue,
          );
        });

        test('CA7 : les $n entrées à 1 à la même seconde déclenchent', () {
          expect(
            detector.detectLowMoodSeries(
              series(List.filled(n, 1), Duration.zero),
              sensitivity,
            ),
            isTrue,
          );
        });

        test(
          'CA7 : un écart d\'une seconde de plus que ${sensitivity.days} jours ne '
          'déclenche pas',
          () {
            expect(
              detector.detectLowMoodSeries(
                series(List.filled(n, 1), d + const Duration(seconds: 1)),
                sensitivity,
              ),
              isFalse,
            );
          },
        );

        test(
          'CA7 : un écart de ${sensitivity.days} jours et un jour ne déclenche '
          'pas',
          () {
            expect(
              detector.detectLowMoodSeries(
                series(List.filled(n, 1), d + const Duration(days: 1)),
                sensitivity,
              ),
              isFalse,
            );
          },
        );

        test('CA7 : ${n - 1} entrées à 1 ne font pas une série', () {
          expect(
            detector.detectLowMoodSeries(
              series(List.filled(n - 1, 1), Duration.zero),
              sensitivity,
            ),
            isFalse,
          );
        });

        test('CA7 : ${n - 1} entrées à 1 précédées d\'une entrée à 1 trop '
            'ancienne ne font pas une série', () {
          final moods = List.filled(n, 1);
          final recent = series(moods, d - const Duration(hours: 1));
          // La plus ancienne est repoussée hors de la durée.
          final stale = entryAt(
            1,
            recent.last.createdAt.subtract(const Duration(days: 2)),
            id: 99,
          );
          expect(
            detector.detectLowMoodSeries([
              ...recent.take(n - 1),
              stale,
            ], sensitivity),
            isFalse,
          );
        });

        for (var position = 0; position < n; position++) {
          test(
            'CA7 : une entrée d\'une autre humeur en position ${position + 1} '
            'sur $n casse la série',
            () {
              final moods = List.filled(n, 1)..[position] = 2;
              expect(
                detector.detectLowMoodSeries(series(moods, d), sensitivity),
                isFalse,
              );
              final high = List.filled(n, 1)..[position] = 5;
              expect(
                detector.detectLowMoodSeries(series(high, d), sensitivity),
                isFalse,
              );
            },
          );
        }

        test('CA7 : seules les $n plus récentes comptent, les plus anciennes '
            'sont ignorées', () {
          final recent = series(List.filled(n, 1), d);
          final older = [
            entryAt(
              5,
              recent.last.createdAt.subtract(const Duration(days: 30)),
              id: 90,
            ),
            entryAt(
              3,
              recent.last.createdAt.subtract(const Duration(days: 40)),
              id: 91,
            ),
          ];
          expect(
            detector.detectLowMoodSeries([...recent, ...older], sensitivity),
            isTrue,
          );
        });

        test('CA7 : sans entrée, il n\'y a pas de série', () {
          expect(detector.detectLowMoodSeries(const [], sensitivity), isFalse);
        });
      });
    }

    test('CA6 : degré « Normale », trois entrées à 1 sur moins de 7 jours '
        'déclenchent', () {
      final latest = series([1, 1, 1], const Duration(days: 6));
      expect(
        detector.detectLowMoodSeries(latest, LowMoodSensitivity.normal),
        isTrue,
      );
    });

    test('CA6 : degré « Normale », deux entrées à 1 ne suffisent pas', () {
      final latest = series([1, 1], const Duration(days: 1));
      expect(
        detector.detectLowMoodSeries(latest, LowMoodSensitivity.normal),
        isFalse,
      );
    });

    test('CA7 : le nombre d\'entrées et la durée dépendent du degré, '
        'trois entrées dont les deux plus récentes sont à 4 jours l\'une de '
        'l\'autre ne déclenchent qu\'en « Normale »', () {
      final latest = [
        entryAt(1, newest, id: 3),
        entryAt(1, newest.subtract(const Duration(days: 4)), id: 2),
        entryAt(1, newest.subtract(const Duration(days: 5)), id: 1),
      ];
      expect(
        detector.detectLowMoodSeries(latest, LowMoodSensitivity.high),
        isFalse,
      );
      expect(
        detector.detectLowMoodSeries(latest, LowMoodSensitivity.normal),
        isTrue,
      );
    });

    test(
      'le calcul se fait sur l\'instant de saisie, pas sur le jour local',
      () {
        // 6 jours 23 h 59 min 59 s entre la plus récente et la plus ancienne.
        final oldest = DateTime.utc(2026, 10, 7, 12, 0, 1);
        final latest = [
          entryAt(1, DateTime.utc(2026, 10, 14, 12), id: 3),
          entryAt(1, DateTime.utc(2026, 10, 10, 23, 59, 59), id: 2),
          entryAt(1, oldest, id: 1),
        ];
        expect(
          detector.detectLowMoodSeries(latest, LowMoodSensitivity.normal),
          isTrue,
        );
      },
    );
  });
}
