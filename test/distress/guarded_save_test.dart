// Enregistrement avec garde-fou (spec 002, CA1 à CA9, CA21, CA27 à CA29), sur des
// faux : aucune base, aucun écran.
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/distress/distress_detector.dart';
import 'package:tidemark/distress/guarded_save.dart';
import 'package:tidemark/entries/entry.dart';

import '../support/fake_entry_repository.dart';
import '../support/fake_settings_repository.dart';

/// Instant de référence : la saisie testée.
final t0 = DateTime.utc(2026, 10, 14, 20);

class Env {
  Env([LowMoodSensitivity start = LowMoodSensitivity.normal])
    : settings = FakeSettingsRepository(start) {
    repo = FakeEntryRepository(clock: () => now);
  }

  late final FakeEntryRepository repo;
  final FakeSettingsRepository settings;
  DateTime now = t0;

  /// Entrée déjà présente dans le journal, à l'humeur et à l'instant donnés.
  Entry seed(int mood, DateTime at, {String? text}) =>
      repo.seed(mood: mood, createdAt: at, text: text);

  /// Enregistre par le garde-fou, à l'instant [at] (par défaut [t0]) : le dépôt et
  /// l'horloge fournie à la fonction donnent le même instant.
  Future<SaveOutcome> save(int mood, {String? text, DateTime? at}) {
    now = at ?? t0;
    return saveEntryWithGuard(
      repository: repo,
      settings: settings,
      mood: mood,
      text: text,
      clock: () => now,
    );
  }
}

/// Seed de [count] entrées à 1, régulièrement espacées, la plus ancienne étant
/// [span] avant [t0] (la dernière tombe juste avant l'enregistrement).
void seedLows(Env env, int count, Duration span) {
  for (var i = 0; i < count; i++) {
    final back = count == 1
        ? span
        : Duration(
            microseconds: span.inMicroseconds * (count - 1 - i) ~/ (count - 1),
          );
    env.seed(1, t0.subtract(back));
  }
}

void main() {
  group('détection dans le texte (CA1 à CA5)', () {
    test('CA1 : un texte en détresse est enregistré « non analysée » et ouvre '
        'l\'écran d\'aide', () async {
      final env = Env();

      final outcome = await env.save(3, text: 'J\'ai envie de mourir');

      expect(outcome.showHelp, isTrue);
      expect(outcome.entry.analysisStatus, AnalysisStatus.skipped);
      expect(env.repo.entries, hasLength(1));
      expect(env.repo.entries.single.analysisStatus, AnalysisStatus.skipped);
      expect(env.repo.addCalls.single.status, AnalysisStatus.skipped);
    });

    test('CA1 : le texte est enregistré tel que saisi', () async {
      final env = Env();
      const text = 'J’ai ENVIE de… mourir.\nVraiment.';

      final outcome = await env.save(5, text: text);

      expect(outcome.entry.text, text);
      expect(env.repo.entries.single.text, text);
      expect(env.repo.entries.single.mood, 5);
    });

    test('CA1 : l\'entrée enregistrée est celle qui est rendue', () async {
      final env = Env();

      final outcome = await env.save(2, text: 'je veux disparaître');

      expect(outcome.entry.id, env.repo.entries.single.id);
      expect(outcome.entry.mood, 2);
    });

    for (final mood in [1, 2, 3, 4, 5]) {
      test(
        'CA1 : humeur $mood, un texte en détresse ouvre l\'écran d\'aide',
        () async {
          final env = Env();

          final outcome = await env.save(mood, text: 'plutôt mourir');

          expect(outcome.showHelp, isTrue);
          expect(outcome.entry.analysisStatus, AnalysisStatus.skipped);
        },
      );
    }

    test('CA2 : majuscules, accents, apostrophe typographique, ponctuation et '
        'retours à la ligne sont ramenés à la liste', () async {
      for (final text in [
        'J’ai ENVIE de… mourir.',
        'je suis fatiguée\nde vivre',
        'ENVIE\nDE\nMOURIR',
      ]) {
        final env = Env();

        final outcome = await env.save(3, text: text);

        expect(outcome.showHelp, isTrue, reason: text);
        expect(
          outcome.entry.analysisStatus,
          AnalysisStatus.skipped,
          reason: text,
        );
      }
    });

    test('CA3 : une expression à l\'intérieur d\'un mot plus long ne déclenche '
        'rien', () async {
      final env = Env();

      final outcome = await env.save(3, text: 'suicidexyz, hélas de vivre');

      expect(outcome.showHelp, isFalse);
      expect(outcome.entry.analysisStatus, AnalysisStatus.pending);
    });

    test('CA4 : un texte sans expression est « en attente » et ne montre pas '
        'l\'écran d\'aide', () async {
      final env = Env();

      final outcome = await env.save(
        3,
        text: 'Journée calme au bord de l’eau.',
      );

      expect(outcome.showHelp, isFalse);
      expect(outcome.entry.analysisStatus, AnalysisStatus.pending);
      expect(env.repo.entries.single.analysisStatus, AnalysisStatus.pending);
      expect(env.repo.addCalls.single.status, AnalysisStatus.pending);
    });

    test('CA4 : les termes exclus (« ce boulot me tue ») ne déclenchent '
        'rien', () async {
      final env = Env();

      final outcome = await env.save(
        2,
        text: 'Ce boulot me tue, je suis mort de rire.',
      );

      expect(outcome.showHelp, isFalse);
      expect(outcome.entry.analysisStatus, AnalysisStatus.pending);
    });

    test('CA4 : une humeur sans texte, sans série, est « non analysée » sans '
        'écran d\'aide (RM24)', () async {
      final env = Env();

      final outcome = await env.save(3);

      expect(outcome.showHelp, isFalse);
      expect(outcome.entry.analysisStatus, AnalysisStatus.skipped);
    });

    test('CA5 : une forme niée déclenche l\'écran d\'aide', () async {
      for (final text in ['je ne veux pas mourir', 'je veux plus vivre']) {
        final env = Env();

        final outcome = await env.save(3, text: text);

        expect(outcome.showHelp, isTrue, reason: text);
        expect(
          outcome.entry.analysisStatus,
          AnalysisStatus.skipped,
          reason: text,
        );
      }
    });

    test(
      'Cas limite : un texte d\'émoji seul ne déclenche pas par le texte, la '
      'série reste évaluée',
      () async {
        final env = Env();
        seedLows(env, 2, const Duration(days: 1));

        final withSeries = await env.save(1, text: '😔');
        final noSeries = await Env().save(3, text: '😔');

        expect(withSeries.showHelp, isTrue);
        expect(noSeries.showHelp, isFalse);
        expect(noSeries.entry.analysisStatus, AnalysisStatus.pending);
      },
    );

    test('Cas limite : une expression coupée par un retour à la ligne est '
        'détectée', () async {
      final outcome = await Env().save(3, text: 'envie de\nmourir');

      expect(outcome.showHelp, isTrue);
    });

    test('RM8 : sans détresse, le texte n\'est jamais marqué « non '
        'analysée »', () async {
      final env = Env();
      await env.save(4, text: 'Belle journée.');
      await env.save(
        5,
        text: 'Encore mieux.',
        at: t0.add(const Duration(hours: 1)),
      );

      expect(
        env.repo.entries.map((e) => e.analysisStatus),
        everyElement(AnalysisStatus.pending),
      );
    });
  });

  group('série d\'humeurs basses (CA6, CA7)', () {
    test('CA6 : « Normale », deux entrées à 1 puis une troisième sans texte : '
        'écran d\'aide, « non analysée »', () async {
      final env = Env();
      seedLows(env, 2, const Duration(days: 2));

      final outcome = await env.save(1);

      expect(outcome.showHelp, isTrue);
      expect(outcome.entry.analysisStatus, AnalysisStatus.skipped);
    });

    test('CA6 : avec un texte sans détresse, la troisième entrée à 1 est aussi '
        '« non analysée » et jamais en attente (RM8)', () async {
      final env = Env();
      seedLows(env, 2, const Duration(days: 2));

      final outcome = await env.save(1, text: 'Journée très lourde.');

      expect(outcome.showHelp, isTrue);
      expect(outcome.entry.analysisStatus, AnalysisStatus.skipped);
      expect(env.repo.addCalls.single.status, AnalysisStatus.skipped);
      expect(env.repo.entries.first.analysisStatus, AnalysisStatus.skipped);
      expect(env.repo.entries.first.text, 'Journée très lourde.');
    });

    test('CA6 : exactement 7 × 24 heures après la plus ancienne, la série '
        'est atteinte', () async {
      final env = Env();
      env.seed(1, t0.subtract(const Duration(days: 7)));
      env.seed(1, t0.subtract(const Duration(days: 3)));

      final outcome = await env.save(1);

      expect(outcome.showHelp, isTrue);
    });

    test(
      'CA6 : une seconde de plus que 7 × 24 heures, elle ne l\'est pas',
      () async {
        final env = Env();
        env.seed(1, t0.subtract(const Duration(days: 7, seconds: 1)));
        env.seed(1, t0.subtract(const Duration(days: 3)));

        final outcome = await env.save(1, text: 'Journée lourde.');

        expect(outcome.showHelp, isFalse);
        expect(outcome.entry.analysisStatus, AnalysisStatus.pending);
      },
    );

    test('CA6 : l\'entrée enregistrée compte dans la série, elle n\'est pas '
        'seulement comparée aux précédentes', () async {
      final env = Env();
      env.seed(1, t0.subtract(const Duration(days: 2)));
      env.seed(1, t0.subtract(const Duration(days: 1)));

      final notLow = await env.save(2);

      expect(notLow.showHelp, isFalse);
    });

    for (final sensitivity in LowMoodSensitivity.values) {
      final n = sensitivity.entryCount;
      final d = Duration(days: sensitivity.days);

      group(sensitivity.name, () {
        test(
          'CA7 : ${n - 1} entrées à 1 puis la nouvelle à 1 sur ${sensitivity.days} jours '
          'déclenchent',
          () async {
            final env = Env(sensitivity);
            seedLows(env, n - 1, d);

            final outcome = await env.save(1);

            expect(outcome.showHelp, isTrue);
            expect(outcome.entry.analysisStatus, AnalysisStatus.skipped);
          },
        );

        test(
          'CA7 : $n entrées à 1 en tout, moins une, ne déclenchent pas',
          () async {
            final env = Env(sensitivity);
            seedLows(env, n - 2, d);

            final outcome = await env.save(1, text: 'Triste.');

            expect(outcome.showHelp, isFalse);
            expect(outcome.entry.analysisStatus, AnalysisStatus.pending);
          },
        );

        test(
          'CA7 : un écart d\'une seconde de plus que ${sensitivity.days} jours ne '
          'déclenche pas',
          () async {
            final env = Env(sensitivity);
            seedLows(env, n - 1, d + const Duration(seconds: 1));

            final outcome = await env.save(1, text: 'Triste.');

            expect(outcome.showHelp, isFalse);
            expect(outcome.entry.analysisStatus, AnalysisStatus.pending);
          },
        );

        for (var position = 0; position < n - 1; position++) {
          test(
            'CA7 : une entrée d\'une autre humeur en position ${position + 2} '
            'sur $n casse la série',
            () async {
              final env = Env(sensitivity);
              // Les n - 1 entrées précédentes, de la plus ancienne à la plus récente.
              for (var i = 0; i < n - 1; i++) {
                final mood = i == (n - 2 - position) ? 3 : 1;
                final back = d * (n - 1 - i) ~/ (n - 1);
                env.seed(mood, t0.subtract(back));
              }

              final outcome = await env.save(1, text: 'Triste.');

              expect(outcome.showHelp, isFalse);
              expect(outcome.entry.analysisStatus, AnalysisStatus.pending);
            },
          );
        }

        test('CA7 : une nouvelle entrée d\'une autre humeur ne déclenche pas, même '
            'après ${n - 1} entrées à 1', () async {
          final env = Env(sensitivity);
          seedLows(env, n - 1, d);

          final outcome = await env.save(2, text: 'Un peu mieux.');

          expect(outcome.showHelp, isFalse);
          expect(outcome.entry.analysisStatus, AnalysisStatus.pending);
        });

        test('CA7 : les entrées plus anciennes que les $n dernières sont '
            'ignorées', () async {
          final env = Env(sensitivity);
          env.seed(5, t0.subtract(const Duration(days: 60)));
          env.seed(3, t0.subtract(const Duration(days: 40)));
          seedLows(env, n - 1, d);

          final outcome = await env.save(1);

          expect(outcome.showHelp, isTrue);
        });
      });
    }
  });

  // Ajouté après la revue de code : la lecture de la série ne doit jamais empêcher
  // d'enregistrer, ni masquer la détresse du texte (spec 002, cas limites).
  group('série illisible', () {
    test(
      'un texte en détresse est enregistré « non analysée » et ouvre l\'aide',
      () async {
        final env = Env();
        env.repo.latestEntriesError = StateError('lecture impossible');

        final outcome = await env.save(1, text: 'Je veux mourir.');

        expect(outcome.showHelp, isTrue);
        expect(outcome.entry.analysisStatus, AnalysisStatus.skipped);
        expect(env.repo.entries, hasLength(1));
      },
    );

    test(
      'sans détresse dans le texte, l\'entrée est enregistrée « en attente », '
      'sans écran d\'aide',
      () async {
        final env = Env();
        env.repo.latestEntriesError = StateError('lecture impossible');

        final outcome = await env.save(1, text: 'Journée grise.');

        expect(outcome.showHelp, isFalse);
        expect(outcome.entry.analysisStatus, AnalysisStatus.pending);
        expect(env.repo.entries, hasLength(1));
      },
    );
  });

  group('détresse du texte et série à la fois (CA8)', () {
    test('CA8 : un seul enregistrement, un seul écran d\'aide demandé, une '
        'seule entrée ajoutée', () async {
      final env = Env();
      seedLows(env, 2, const Duration(days: 2));

      final outcome = await env.save(1, text: 'envie de mourir');

      expect(outcome.showHelp, isTrue);
      expect(outcome.entry.analysisStatus, AnalysisStatus.skipped);
      expect(env.repo.addCalls, hasLength(1));
      expect(env.repo.entries, hasLength(3));
    });
  });

  group('séries successives et suppression (CA27, CA28, CA29)', () {
    test('CA27 : une quatrième entrée à 1 dans les 7 × 24 heures montre de '
        'nouveau l\'écran d\'aide', () async {
      final env = Env();
      env.seed(1, t0.subtract(const Duration(days: 3)));
      env.seed(1, t0.subtract(const Duration(days: 2)));

      final third = await env.save(1, at: t0.subtract(const Duration(days: 1)));
      final fourth = await env.save(1, text: 'Toujours pareil.');

      expect(third.showHelp, isTrue);
      expect(fourth.showHelp, isTrue);
      expect(fourth.entry.analysisStatus, AnalysisStatus.skipped);
    });

    test('CA27 : une entrée en détresse qui a ouvert l\'écran d\'aide compte '
        'encore dans la série suivante', () async {
      final env = Env();
      env.seed(1, t0.subtract(const Duration(days: 3)));
      await env.save(
        1,
        text: 'envie de mourir',
        at: t0.subtract(const Duration(days: 2)),
      );

      final outcome = await env.save(1, text: 'Triste.');

      expect(outcome.showHelp, isTrue);
    });

    test('CA28 : deux entrées à 1 dont une supprimée, une nouvelle entrée à 1 '
        'ne montre pas l\'écran d\'aide', () async {
      final env = Env();
      env.seed(1, t0.subtract(const Duration(days: 3)));
      final removed = env.seed(1, t0.subtract(const Duration(days: 2)));
      await env.repo.deleteEntry(removed.id);

      final outcome = await env.save(1, text: 'Triste.');

      expect(outcome.showHelp, isFalse);
      expect(outcome.entry.analysisStatus, AnalysisStatus.pending);
    });

    test('CA28 : sans suppression, les mêmes entrées déclenchent (témoin du '
        'test précédent)', () async {
      final env = Env();
      env.seed(1, t0.subtract(const Duration(days: 3)));
      env.seed(1, t0.subtract(const Duration(days: 2)));

      final outcome = await env.save(1, text: 'Triste.');

      expect(outcome.showHelp, isTrue);
    });

    test('CA29 : une entrée à 1 enregistrée en « Normale » compte après le '
        'passage à « Haute »', () async {
      final env = Env();
      final first = await env.save(1, text: 'Triste.', at: t0);
      expect(first.showHelp, isFalse);

      await env.settings.setLowMoodSensitivity(LowMoodSensitivity.high);
      final second = await env.save(
        1,
        text: 'Encore.',
        at: t0.add(const Duration(days: 3)),
      );

      expect(second.showHelp, isTrue);
      expect(second.entry.analysisStatus, AnalysisStatus.skipped);
    });

    test('CA29 : « Haute » ne couvre que 3 × 24 heures, une seconde de plus ne '
        'déclenche pas', () async {
      final env = Env();
      await env.save(1, text: 'Triste.', at: t0);
      await env.settings.setLowMoodSensitivity(LowMoodSensitivity.high);

      final second = await env.save(
        1,
        text: 'Encore.',
        at: t0.add(const Duration(days: 3, seconds: 1)),
      );

      expect(second.showHelp, isFalse);
    });

    test(
      'Cas limite : le nouveau degré s\'applique à la série entière, entrées '
      'anciennes comprises',
      () async {
        // Cinq entrées à 1 sur 13 jours, dont les trois plus récentes sur 8 jours :
        // « Basse » déclenche, « Normale » non.
        final env = Env(LowMoodSensitivity.low);
        for (final days in [13, 11, 8, 4]) {
          env.seed(1, t0.subtract(Duration(days: days)));
        }

        final outcome = await env.save(1, text: 'Triste.');

        expect(outcome.showHelp, isTrue);
      },
    );

    test('Cas limite : deux entrées de la même seconde, la série les compte '
        'toutes les deux', () async {
      final env = Env(LowMoodSensitivity.high);
      env.seed(1, t0);

      final outcome = await env.save(1, text: 'Triste.', at: t0);

      expect(outcome.showHelp, isTrue);
    });
  });

  group('enregistrement en échec (CA9)', () {
    test('CA9 : l\'erreur remonte, rien n\'est enregistré, pas d\'écran '
        'd\'aide', () async {
      final env = Env();
      env.repo.beforeAdd = () async => throw StateError('stockage plein');

      await expectLater(
        env.save(3, text: 'envie de mourir'),
        throwsA(isA<StateError>()),
      );

      expect(env.repo.entries, isEmpty);
    });

    test('CA9 : même avec une série prête, l\'échec ne donne aucun résultat '
        'd\'écran d\'aide', () async {
      final env = Env();
      seedLows(env, 2, const Duration(days: 2));
      env.repo.beforeAdd = () async => throw StateError('stockage plein');

      SaveOutcome? outcome;
      Object? error;
      try {
        outcome = await env.save(1);
      } catch (e) {
        error = e;
      }

      expect(outcome, isNull);
      expect(error, isA<StateError>());
      expect(env.repo.entries, hasLength(2));
      expect(
        env.repo.entries.map((e) => e.analysisStatus),
        everyElement(AnalysisStatus.skipped),
        reason: 'aucune entrée existante n\'a été modifiée',
      );
    });

    test(
      'CA9 : les entrées déjà présentes ne sont pas modifiées par un échec',
      () async {
        final env = Env();
        env.seed(3, t0.subtract(const Duration(days: 1)), text: 'Un texte.');
        env.repo.beforeAdd = () async => throw StateError('stockage plein');

        await expectLater(
          env.save(3, text: 'envie de mourir'),
          throwsA(anything),
        );

        expect(env.repo.entries.single.analysisStatus, AnalysisStatus.pending);
      },
    );
  });

  group('lecture du degré en échec (CA21)', () {
    test('CA21 : si la lecture échoue, « Normale » s\'applique : trois entrées à 1 '
        'déclenchent', () async {
      final env = Env();
      env.settings.readError = StateError('lecture impossible');
      seedLows(env, 2, const Duration(days: 5));

      final outcome = await env.save(1, text: 'Triste.');

      expect(outcome.showHelp, isTrue);
      expect(outcome.entry.analysisStatus, AnalysisStatus.skipped);
    });

    test('CA21 : si la lecture échoue, « Haute » ne s\'applique pas : deux '
        'entrées à 1 ne déclenchent pas', () async {
      final env = Env();
      env.settings.readError = StateError('lecture impossible');
      seedLows(env, 1, const Duration(days: 1));

      final outcome = await env.save(1, text: 'Triste.');

      expect(outcome.showHelp, isFalse);
      expect(outcome.entry.analysisStatus, AnalysisStatus.pending);
    });

    test('CA21 : si la lecture échoue, « Basse » ne s\'applique pas : quatre '
        'entrées à 1 déclenchent', () async {
      final env = Env();
      env.settings.readError = StateError('lecture impossible');
      seedLows(env, 3, const Duration(days: 5));

      final outcome = await env.save(1, text: 'Triste.');

      expect(outcome.showHelp, isTrue);
    });

    test('CA21 : l\'enregistrement n\'échoue pas à cause de la lecture du '
        'degré', () async {
      final env = Env();
      env.settings.readError = StateError('lecture impossible');

      final outcome = await env.save(4, text: 'Belle journée.');

      expect(outcome.showHelp, isFalse);
      expect(env.repo.entries, hasLength(1));
    });

    test(
      'CA21 : la détection par le texte ne dépend pas des réglages',
      () async {
        final env = Env();
        env.settings.readError = StateError('lecture impossible');

        final outcome = await env.save(4, text: 'envie de mourir');

        expect(outcome.showHelp, isTrue);
        expect(outcome.entry.analysisStatus, AnalysisStatus.skipped);
      },
    );

    test(
      'CA21 : le degré choisi s\'applique quand la lecture réussit',
      () async {
        final env = Env(LowMoodSensitivity.high);
        seedLows(env, 1, const Duration(days: 1));

        final outcome = await env.save(1, text: 'Triste.');

        expect(outcome.showHelp, isTrue);
      },
    );
  });
}
