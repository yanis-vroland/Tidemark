// Accès exclusif au modèle local (spec 006, « Modèle occupé par l'étiquetage »,
// ADR-005 proposé) : l'étiquetage et le bilan se partagent un `ModelGate` ; jamais
// deux générations à la fois, jamais deux modèles chargés. Faux analyseur et faux
// rédacteur, aucun moteur.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/analysis/mood_analyzer.dart';
import 'package:tidemark/model/gated_mood_analyzer.dart';
import 'package:tidemark/model/model_gate.dart';
import 'package:tidemark/review/gated_review_writer.dart';
import 'package:tidemark/review/review_writer.dart';

import '../support/analysis_harness.dart' show wait;
import '../support/fake_mood_analyzer.dart';
import '../support/fake_review_writer.dart';
import '../support/review_harness.dart';

/// Laisse tourner les microtâches et un peu de temps réel.
Future<void> settleTasks() => wait(const Duration(milliseconds: 30));

void main() {
  group('ModelGate : verrou exclusif', () {
    test(
      'libre au départ ; l\'acquisition le prend, la libération le rend',
      () async {
        final gate = ModelGate();
        expect(gate.isHeld, isFalse);

        final release = await gate.acquire();

        expect(release, isNotNull);
        expect(gate.isHeld, isTrue);
        release!();
        expect(gate.isHeld, isFalse);
      },
    );

    test('un second demandeur attend la libération', () async {
      final gate = ModelGate();
      final first = (await gate.acquire())!;
      var granted = false;
      final second = gate.acquire().then((release) {
        granted = true;
        return release;
      });

      await settleTasks();
      expect(granted, isFalse);
      expect(gate.isHeld, isTrue);

      first();
      final release = await second.timeout(const Duration(seconds: 2));
      expect(granted, isTrue);
      expect(gate.isHeld, isTrue, reason: 'le second le détient désormais');
      release!();
      expect(gate.isHeld, isFalse);
    });

    test('les demandes sont servies dans l\'ordre d\'arrivée', () async {
      final gate = ModelGate();
      final first = (await gate.acquire())!;
      final order = <int>[];
      final releases = <int, void Function()>{};
      final waiting = [
        for (var i = 2; i <= 4; i++)
          gate.acquire().then((release) {
            order.add(i);
            releases[i] = release!;
          }),
      ];

      await settleTasks();
      expect(order, isEmpty);

      first();
      await settleTasks();
      expect(order, [2]);

      releases[2]!();
      await settleTasks();
      expect(order, [2, 3]);

      releases[3]!();
      await settleTasks();
      expect(order, [2, 3, 4]);

      await Future.wait(waiting).timeout(const Duration(seconds: 2));
      releases[4]!();
      expect(gate.isHeld, isFalse);
    });

    test('plusieurs détenteurs successifs ne se chevauchent jamais', () async {
      final gate = ModelGate();
      var holders = 0;
      var maxHolders = 0;
      Future<void> job() async {
        final release = await gate.acquire();
        holders++;
        if (holders > maxHolders) maxHolders = holders;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        holders--;
        release!();
      }

      await Future.wait([for (var i = 0; i < 6; i++) job()]);

      expect(maxHolders, 1);
      expect(gate.isHeld, isFalse);
    });
  });

  group('ModelGate : abandon avant l\'accès', () {
    test(
      'si `abandon` se termine avant l\'accès, `acquire` rend null',
      () async {
        final gate = ModelGate();
        final held = (await gate.acquire())!;
        final abandon = Completer<void>();
        final waiting = gate.acquire(abandon: abandon.future);

        await settleTasks();
        abandon.complete();

        expect(await waiting.timeout(const Duration(seconds: 2)), isNull);
        held();
        expect(
          gate.isHeld,
          isFalse,
          reason: 'l\'abandonné ne prend pas l\'accès',
        );
      },
    );

    test('un demandeur abandonné ne bloque pas ceux qui le suivent', () async {
      final gate = ModelGate();
      final held = (await gate.acquire())!;
      final abandon = Completer<void>();
      final abandoned = gate.acquire(abandon: abandon.future);
      var thirdGranted = false;
      final third = gate.acquire().then((release) {
        thirdGranted = true;
        return release;
      });

      abandon.complete();
      expect(await abandoned, isNull);
      await settleTasks();
      expect(thirdGranted, isFalse, reason: 'l\'accès est encore détenu');

      held();
      final release = await third.timeout(const Duration(seconds: 2));
      expect(release, isNotNull);
      release!();
      expect(gate.isHeld, isFalse);
    });

    test('`abandon` qui se termine après l\'accès est sans effet', () async {
      final gate = ModelGate();
      final abandon = Completer<void>();
      final release = await gate.acquire(abandon: abandon.future);
      expect(release, isNotNull);

      abandon.complete();
      await settleTasks();

      expect(gate.isHeld, isTrue);
      release!();
      expect(gate.isHeld, isFalse);
    });

    test(
      'accès libre et `abandon` jamais terminé : accordé tout de suite',
      () async {
        final gate = ModelGate();
        final never = Completer<void>();

        final release = await gate
            .acquire(abandon: never.future)
            .timeout(const Duration(seconds: 2));

        expect(release, isNotNull);
        release!();
      },
    );
  });

  group('GatedMoodAnalyzer : détient l\'accès de prepare() à release()', () {
    test('prepare() réussi : l\'accès est détenu jusqu\'à release()', () async {
      final gate = ModelGate();
      final inner = FakeMoodAnalyzer();
      final analyzer = GatedMoodAnalyzer(inner, gate);

      expect(await analyzer.prepare(), isTrue);
      expect(inner.prepareCalls, 1);
      expect(gate.isHeld, isTrue);

      await analyzer.analyze('Un texte');
      expect(
        gate.isHeld,
        isTrue,
        reason: 'toujours détenu entre deux analyses',
      );

      await analyzer.release();
      expect(inner.releaseCalls, 1);
      expect(gate.isHeld, isFalse);
    });

    test('prepare() en échec (modèle impossible à charger) : rend false et '
        'rend l\'accès', () async {
      final gate = ModelGate();
      final inner = FakeMoodAnalyzer(prepareResult: false);
      final analyzer = GatedMoodAnalyzer(inner, gate);

      expect(await analyzer.prepare(), isFalse);

      expect(gate.isHeld, isFalse);
    });

    test('analyze et cancel sont délégués à l\'analyseur', () async {
      final gate = ModelGate();
      final inner = FakeMoodAnalyzer(
        results: {
          'Un texte': Tagged([emotionTag('joie')]),
        },
      );
      final analyzer = GatedMoodAnalyzer(inner, gate);
      await analyzer.prepare();

      final result = await analyzer.analyze('Un texte');
      await analyzer.cancel();

      expect(inner.received, ['Un texte']);
      expect((result as Tagged).tags, [emotionTag('joie')]);
      expect(inner.cancelCalls, 1);
      await analyzer.release();
    });

    test('prepare() attend l\'accès : tant qu\'un rédacteur génère, le '
        'modèle n\'est pas chargé', () async {
      final gate = ModelGate();
      final writerInner = FakeReviewWriter(
        delay: const Duration(milliseconds: 120),
      );
      final writer = GatedReviewWriter(writerInner, gate);
      final inner = FakeMoodAnalyzer();
      final analyzer = GatedMoodAnalyzer(inner, gate);

      final writing = writer.write(defaultFacts);
      await settleTasks();
      final preparing = analyzer.prepare();
      await settleTasks();

      expect(inner.prepareCalls, 0, reason: 'pas de second modèle en mémoire');
      expect(writerInner.completed, 0);

      await writing;
      expect(await preparing.timeout(const Duration(seconds: 2)), isTrue);
      expect(inner.prepareCalls, 1);
      await analyzer.release();
      expect(gate.isHeld, isFalse);
    });
  });

  group('GatedReviewWriter : attend l\'accès avant chaque mise en mots', () {
    test(
      'accès libre : la mise en mots a lieu, l\'accès est rendu après',
      () async {
        final gate = ModelGate();
        final inner = FakeReviewWriter();
        final writer = GatedReviewWriter(inner, gate);

        final draft = await writer.write(defaultFacts);

        expect(draft, isA<RawReview>());
        expect(inner.received, [defaultFacts]);
        expect(gate.isHeld, isFalse);
      },
    );

    test('accès détenu (modèle chargé par l\'analyseur) : le rédacteur '
        'attend la libération, puis écrit', () async {
      final gate = ModelGate();
      final inner = FakeReviewWriter();
      final writer = GatedReviewWriter(inner, gate);
      final held = (await gate.acquire())!;

      final writing = writer.write(defaultFacts);
      await settleTasks();
      expect(inner.writeCalls, 0);

      held();
      final draft = await writing.timeout(const Duration(seconds: 2));

      expect(inner.writeCalls, 1);
      expect(draft, isA<RawReview>());
      expect(gate.isHeld, isFalse);
    });

    test('ce que rend le rédacteur interne est rendu tel quel', () async {
      final gate = ModelGate();
      for (final expected in [const ModelMissing(), const WriterFailed()]) {
        final writer = GatedReviewWriter(
          FakeReviewWriter(draft: expected),
          gate,
        );
        expect(await writer.write(defaultFacts), same(expected));
        expect(gate.isHeld, isFalse);
      }
    });

    test(
      'deux mises en mots simultanées s\'exécutent l\'une après l\'autre',
      () async {
        final gate = ModelGate();
        final inner = FakeReviewWriter(delay: const Duration(milliseconds: 30));
        final writer = GatedReviewWriter(inner, gate);

        await Future.wait([
          writer.write(defaultFacts),
          writer.write(defaultFacts),
          writer.write(defaultFacts),
        ]);

        expect(inner.writeCalls, 3);
        expect(inner.maxConcurrent, 1);
        expect(gate.isHeld, isFalse);
      },
    );

    test('cancel() pendant l\'attente : write rend WriterFailed sans appeler '
        'le rédacteur interne, et ne prend jamais l\'accès', () async {
      final gate = ModelGate();
      final inner = FakeReviewWriter();
      final writer = GatedReviewWriter(inner, gate);
      final held = (await gate.acquire())!;

      final writing = writer.write(defaultFacts);
      await settleTasks();
      await writer.cancel();

      expect(
        await writing.timeout(const Duration(seconds: 2)),
        isA<WriterFailed>(),
      );
      held();
      await settleTasks();
      expect(inner.writeCalls, 0);
      expect(gate.isHeld, isFalse);
    });

    test('après un cancel() pendant l\'attente, une nouvelle mise en mots '
        'fonctionne', () async {
      final gate = ModelGate();
      final inner = FakeReviewWriter();
      final writer = GatedReviewWriter(inner, gate);
      final held = (await gate.acquire())!;
      final first = writer.write(defaultFacts);
      await settleTasks();
      await writer.cancel();
      await first;
      held();

      final draft = await writer.write(defaultFacts);

      expect(draft, isA<RawReview>());
      expect(inner.writeCalls, 1);
    });

    test('cancel() pendant la génération est délégué au rédacteur interne, '
        'et l\'accès est rendu quand il a rendu la main', () async {
      final gate = ModelGate();
      final inner = FakeReviewWriter(hang: true);
      final writer = GatedReviewWriter(inner, gate);

      final writing = writer.write(defaultFacts);
      await settleTasks();
      expect(inner.writeCalls, 1);
      expect(gate.isHeld, isTrue);

      await writer.cancel();
      await writing.timeout(const Duration(seconds: 2));

      expect(inner.cancelCalls, 1);
      expect(gate.isHeld, isFalse);
    });

    // Revue de sécurité : cancel() arrive juste après que l'accès a été transmis
    // à la demande, mais avant qu'elle reprenne. Elle ne doit ni charger le
    // modèle ni générer.
    test('cancel() entre la transmission de l\'accès et la reprise de write : '
        'aucune mise en mots, accès rendu', () async {
      final gate = ModelGate();
      final inner = FakeReviewWriter();
      final writer = GatedReviewWriter(inner, gate);
      final holder = (await gate.acquire())!;

      final writing = writer.write(defaultFacts);
      await wait(const Duration(milliseconds: 20));
      // Libération puis abandon dans le même tour de boucle.
      holder();
      await writer.cancel();
      final draft = await writing.timeout(const Duration(seconds: 2));

      expect(draft, isA<WriterFailed>());
      expect(inner.writeCalls, 0);
      expect(gate.isHeld, isFalse);
    });
  });

  group('analyseur et rédacteur partagent un même ModelGate', () {
    test('jamais une analyse et une mise en mots en même temps, toutes '
        'sources confondues', () async {
      final gate = ModelGate();
      final probe = ConcurrencyProbe();
      final analyzer = GatedMoodAnalyzer(
        ProbeAnalyzer(
          probe,
          delays: {'Un texte': const Duration(milliseconds: 25)},
        ),
        gate,
      );
      final writer = GatedReviewWriter(
        ProbeWriter(probe, delay: const Duration(milliseconds: 25)),
        gate,
      );

      Future<void> tagging() async {
        for (var i = 0; i < 3; i++) {
          expect(await analyzer.prepare(), isTrue);
          await analyzer.analyze('Un texte');
          await analyzer.analyze('Un texte');
          await analyzer.release();
        }
      }

      await Future.wait([
        tagging(),
        for (var i = 0; i < 4; i++) writer.write(defaultFacts),
      ]).timeout(const Duration(seconds: 10));

      expect(probe.maxGenerating, 1);
      expect(probe.maxLoaded, 1, reason: 'jamais deux modèles chargés');
      expect(probe.generating, 0);
      expect(probe.loaded, 0);
      expect(gate.isHeld, isFalse);
    });

    test('le rédacteur attend la release() de l\'analyseur, pas seulement '
        'la fin de son analyse', () async {
      final gate = ModelGate();
      final innerWriter = FakeReviewWriter();
      final innerAnalyzer = FakeMoodAnalyzer();
      final analyzer = GatedMoodAnalyzer(innerAnalyzer, gate);
      final writer = GatedReviewWriter(innerWriter, gate);

      await analyzer.prepare();
      await analyzer.analyze('Un texte');
      final writing = writer.write(defaultFacts);
      await settleTasks();

      expect(
        innerWriter.writeCalls,
        0,
        reason: 'le modèle de l\'analyseur est encore chargé',
      );

      await analyzer.release();
      await writing.timeout(const Duration(seconds: 2));

      expect(innerWriter.writeCalls, 1);
      expect(gate.isHeld, isFalse);
    });

    test('un prepare() en échec ne bloque pas le rédacteur', () async {
      final gate = ModelGate();
      final analyzer = GatedMoodAnalyzer(
        FakeMoodAnalyzer(prepareResult: false),
        gate,
      );
      final innerWriter = FakeReviewWriter();
      final writer = GatedReviewWriter(innerWriter, gate);

      expect(await analyzer.prepare(), isFalse);
      final draft = await writer
          .write(defaultFacts)
          .timeout(const Duration(seconds: 2));

      expect(draft, isA<RawReview>());
      expect(innerWriter.writeCalls, 1);
    });
  });
}
