// Mise en mots du bilan (spec 006, « Mise en mots », CA18 à CA22, CA26 à CA28,
// CA34) : sensibilité, mémoire, état du modèle, rédacteur factice avec son délai,
// validation. Aucun écran, aucun modèle ; les bilans sont construits à la main.
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/model/model_state.dart';
import 'package:tidemark/review/review_narrator.dart';
import 'package:tidemark/review/review_writer.dart';
import 'package:tidemark/review/weekly_review.dart';

import '../support/analysis_harness.dart' show wait;
import '../support/fake_model_downloader.dart';
import '../support/fake_review_writer.dart';
import '../support/review_harness.dart';

const shortTimeout = Duration(milliseconds: 80);

ReviewNarrator narratorOf(
  ReviewWriter writer, {
  ModelState model = readyModel,
  Duration timeout = const Duration(seconds: 5),
  FakeModelDownloader? downloader,
}) => ReviewNarrator(
  writer: writer,
  downloader: downloader ?? FakeModelDownloader(model),
  timeout: timeout,
);

void expectText(Narration narration, String text) {
  expect(narration, isA<NarrationText>());
  expect((narration as NarrationText).text, text);
}

void main() {
  group('CA18 : à l\'affichage, avant la réponse', () {
    test('CA18 : semaine non sensible, modèle prêt, rien en mémoire : '
        '« mise en mots en cours », sans appeler le rédacteur', () {
      final writer = FakeReviewWriter();
      final narrator = narratorOf(writer);

      expect(narrator.immediate(computedWeek()), isA<NarrationWriting>());
      expect(writer.writeCalls, 0);
    });
  });

  group('CA19 : texte validé', () {
    test('CA19 : une sortie qui passe la validation donne le texte', () async {
      final writer = FakeReviewWriter(output: jsonText(validReviewText));
      final narrator = narratorOf(writer);

      final narration = await narrator.narrate(computedWeek());

      expectText(narration, validReviewText);
      expect(writer.writeCalls, 1);
    });

    test('CA19 : le texte rendu est sans espace superflu', () async {
      final writer = FakeReviewWriter(
        output: '{"text": "  Une semaine calme.  "}',
      );
      final narrator = narratorOf(writer);

      expectText(await narrator.narrate(computedWeek()), 'Une semaine calme.');
    });

    test('CA21 : le rédacteur reçoit exactement les faits du bilan', () async {
      final writer = FakeReviewWriter();
      final narrator = narratorOf(writer);
      final review = computedWeek();

      await narrator.narrate(review);

      expect(writer.received, [review.facts]);
    });

    test('CA21 : les faits sérialisés pour le modèle ne contiennent aucun '
        'caractère numérique, quelle que soit la combinaison', () {
      for (final label in ['Très bas', 'Bas', 'Neutre', 'Bien', 'Très bien']) {
        for (final regularity in WeekRegularity.values) {
          for (final trend in ReviewTrend.values) {
            final facts = ReviewFacts(
              averageMoodLabel: label,
              regularity: regularity,
              topTagLabels: const ['fatigue', 'travail', 'calme'],
              trend: trend,
            );
            expect(
              hasNumeric(facts.toPrompt()),
              isFalse,
              reason: facts.toPrompt(),
            );
            expect(hasNumeric(facts.toString()), isFalse);
          }
        }
      }
    });

    test('CA21 : les faits sérialisés portent le libellé de l\'humeur et les '
        'étiquettes', () {
      final prompt = defaultFacts.toPrompt();
      expect(prompt, contains('Bien'));
      expect(prompt, contains('fatigue'));
      expect(prompt, contains('travail'));
      expect(prompt, contains('calme'));
    });

    test('CA21 : chaque régularité et chaque tendance change ce que reçoit '
        'le modèle', () {
      const base = ReviewFacts(
        averageMoodLabel: 'Bien',
        regularity: WeekRegularity.mostDays,
        topTagLabels: [],
        trend: ReviewTrend.none,
      );
      ReviewFacts withRegularity(WeekRegularity r) => ReviewFacts(
        averageMoodLabel: base.averageMoodLabel,
        regularity: r,
        topTagLabels: base.topTagLabels,
        trend: base.trend,
      );
      ReviewFacts withTrend(ReviewTrend t) => ReviewFacts(
        averageMoodLabel: base.averageMoodLabel,
        regularity: base.regularity,
        topTagLabels: base.topTagLabels,
        trend: t,
      );
      final regularityPrompts = {
        for (final r in WeekRegularity.values) withRegularity(r).toPrompt(),
      };
      final trendPrompts = {
        for (final t in ReviewTrend.values) withTrend(t).toPrompt(),
      };
      expect(regularityPrompts.length, WeekRegularity.values.length);
      expect(trendPrompts.length, ReviewTrend.values.length);
    });
  });

  group('CA20 : semaine sensible', () {
    test('CA20 : le rédacteur n\'est pas appelé, pas de texte', () async {
      final writer = FakeReviewWriter();
      final narrator = narratorOf(writer);
      final review = computedWeek(sensitive: true);

      expect(narrator.immediate(review), isA<NarrationWithheld>());
      expect(await narrator.narrate(review), isA<NarrationWithheld>());
      expect(writer.writeCalls, 0);
    });
  });

  group('CA22, CA26 : sortie rejetée, erreur ou absence de réponse', () {
    final rejected = <String, String>{
      'CA22 : un chiffre (« 3 jours »)': '{"text": "Trois ou 3 jours notés."}',
      'CA22 : un chiffre d\'une autre écriture': '{"text": "٣ jours notés."}',
      'CA22 : une fraction': '{"text": "½ de la semaine notée."}',
      'CA22 : « % »': '{"text": "Presque 100 % du temps."}',
      'CA23 : un mot de nombre': '{"text": "Trois jours notés."}',
      'CA24 : une expression interdite': '{"text": "Tu devrais consulter."}',
      'CA24 : une expression de détresse': '{"text": "J’ai envie de mourir."}',
      'CA26 : une sortie non conforme au schéma': 'Une semaine calme.',
      'CA26 : un champ absent': '{"texte": "Une semaine calme."}',
      'CA26 : un texte vide': '{"text": ""}',
      'CA26 : un texte de plus de 300 caractères': '{"text": "${'a' * 301}"}',
    };
    rejected.forEach((name, output) {
      test('$name : pas de texte, et rien n\'est gardé en mémoire', () async {
        final writer = FakeReviewWriter(output: output);
        final narrator = narratorOf(writer);
        final review = computedWeek();

        expect(await narrator.narrate(review), isA<NarrationWithheld>());
        // La sortie rejetée n'est pas gardée : revenir sur la semaine relance la
        // mise en mots.
        expect(narrator.immediate(review), isA<NarrationWriting>());
        await narrator.narrate(review);
        expect(writer.writeCalls, 2);
      });
    });

    test('CA26 : le rédacteur rend WriterFailed : pas de texte', () async {
      final writer = FakeReviewWriter(draft: const WriterFailed());
      final narrator = narratorOf(writer);

      expect(await narrator.narrate(computedWeek()), isA<NarrationWithheld>());
    });

    test('CA26 : le rédacteur lève une erreur (contrat violé) : pas de texte, '
        'pas de plantage', () async {
      final writer = FakeReviewWriter()..throwError = StateError('moteur');
      final narrator = narratorOf(writer);

      expect(await narrator.narrate(computedWeek()), isA<NarrationWithheld>());
    });

    test('CA26 : aucune réponse avant le délai : pas de texte, et la mise en '
        'mots est abandonnée', () async {
      final writer = FakeReviewWriter(hang: true);
      final narrator = narratorOf(writer, timeout: shortTimeout);

      final narration = await narrator.narrate(computedWeek());

      expect(narration, isA<NarrationWithheld>());
      expect(writer.cancelCalls, 1);
    });

    test('CA26 : réponse tardive après le délai : rien n\'est gardé en '
        'mémoire', () async {
      final writer = ControlledReviewWriter();
      final narrator = narratorOf(writer, timeout: shortTimeout);
      final review = computedWeek();

      expect(await narrator.narrate(review), isA<NarrationWithheld>());
      expect(writer.cancelCalls, 1);
      writer.completeWithText(validReviewText);
      await wait(const Duration(milliseconds: 50));

      expect(narrator.immediate(review), isA<NarrationWriting>());
    });

    test('CA26 : réponse avant le délai : le texte est rendu', () async {
      final writer = FakeReviewWriter(delay: const Duration(milliseconds: 20));
      final narrator = narratorOf(writer, timeout: const Duration(seconds: 2));

      expectText(await narrator.narrate(computedWeek()), validReviewText);
      expect(writer.cancelCalls, 0);
    });
  });

  group('CA27 : modèle absent', () {
    test('CA27 : modèle absent : le rédacteur n\'est pas appelé, « modèle '
        'absent »', () async {
      final writer = FakeReviewWriter();
      final narrator = narratorOf(writer, model: const ModelAbsent());
      final review = computedWeek();

      expect(narrator.immediate(review), isA<NarrationModelMissing>());
      expect(await narrator.narrate(review), isA<NarrationModelMissing>());
      expect(writer.writeCalls, 0);
    });

    test('CA27 : modèle en cours de téléchargement : même résultat', () async {
      final writer = FakeReviewWriter();
      final narrator = narratorOf(writer, model: downloadingModel);
      final review = computedWeek();

      expect(narrator.immediate(review), isA<NarrationModelMissing>());
      expect(await narrator.narrate(review), isA<NarrationModelMissing>());
      expect(writer.writeCalls, 0);
    });

    test(
      'CA27 : le modèle devient prêt : la mise en mots est possible',
      () async {
        final downloader = FakeModelDownloader(const ModelAbsent());
        final writer = FakeReviewWriter();
        final narrator = narratorOf(writer, downloader: downloader);
        final review = computedWeek();

        expect(narrator.immediate(review), isA<NarrationModelMissing>());
        downloader.emit(readyModel);

        expect(narrator.immediate(review), isA<NarrationWriting>());
        expectText(await narrator.narrate(review), validReviewText);
      },
    );

    test('CA27 : le rédacteur appelé rend ModelMissing (modèle supprimé '
        'entre-temps) : « modèle absent »', () async {
      final writer = FakeReviewWriter(draft: const ModelMissing());
      final narrator = narratorOf(writer);

      expect(
        await narrator.narrate(computedWeek()),
        isA<NarrationModelMissing>(),
      );
      expect(writer.writeCalls, 1);
    });

    test('CA27 : ModelMissing n\'est pas gardé en mémoire', () async {
      final writer = FakeReviewWriter(draft: const ModelMissing());
      final narrator = narratorOf(writer);
      final review = computedWeek();

      await narrator.narrate(review);

      expect(narrator.immediate(review), isA<NarrationWriting>());
    });

    test('CA27 : WriterFailed donne le message du rejet, pas celui du modèle '
        'absent', () async {
      final writer = FakeReviewWriter(draft: const WriterFailed());
      final narrator = narratorOf(writer);

      final narration = await narrator.narrate(computedWeek());

      expect(narration, isA<NarrationWithheld>());
      expect(narration, isNot(isA<NarrationModelMissing>()));
    });
  });

  group('CA28 : texte gardé en mémoire (RM54)', () {
    test('CA28 : mêmes semaine et faits : le texte gardé est rendu tout de '
        'suite, sans nouvel appel', () async {
      final writer = FakeReviewWriter();
      final narrator = narratorOf(writer);
      final review = computedWeek();

      await narrator.narrate(review);
      expectText(narrator.immediate(review), validReviewText);
      expectText(await narrator.narrate(review), validReviewText);

      expect(writer.writeCalls, 1);
    });

    test('CA28 : un bilan recalculé aux mêmes faits (autre objet) reprend le '
        'texte gardé', () async {
      final writer = FakeReviewWriter();
      final narrator = narratorOf(writer);

      await narrator.narrate(computedWeek());
      expectText(narrator.immediate(computedWeek()), validReviewText);
      expect(writer.writeCalls, 1);
    });

    test('CA28 : des faits qui changent relancent la mise en mots', () async {
      final writer = FakeReviewWriter();
      final narrator = narratorOf(writer);

      await narrator.narrate(computedWeek());
      const changed = ReviewFacts(
        averageMoodLabel: 'Neutre',
        regularity: WeekRegularity.mostDays,
        topTagLabels: ['fatigue', 'travail', 'calme'],
        trend: ReviewTrend.up,
      );
      final review = computedWeek(facts: changed);

      expect(narrator.immediate(review), isA<NarrationWriting>());
      await narrator.narrate(review);
      expect(writer.writeCalls, 2);
    });

    test('CA28 : une autre étiquette, une autre régularité ou une autre '
        'tendance sont d\'autres faits', () async {
      final writer = FakeReviewWriter();
      final narrator = narratorOf(writer);
      await narrator.narrate(computedWeek());

      for (final changed in [
        const ReviewFacts(
          averageMoodLabel: 'Bien',
          regularity: WeekRegularity.mostDays,
          topTagLabels: ['fatigue', 'travail'],
          trend: ReviewTrend.up,
        ),
        const ReviewFacts(
          averageMoodLabel: 'Bien',
          regularity: WeekRegularity.everyDay,
          topTagLabels: ['fatigue', 'travail', 'calme'],
          trend: ReviewTrend.up,
        ),
        const ReviewFacts(
          averageMoodLabel: 'Bien',
          regularity: WeekRegularity.mostDays,
          topTagLabels: ['fatigue', 'travail', 'calme'],
          trend: ReviewTrend.down,
        ),
      ]) {
        expect(
          narrator.immediate(computedWeek(facts: changed)),
          isA<NarrationWriting>(),
          reason: changed.toPrompt(),
        );
      }
    });

    test('CA28 : mêmes faits sur une autre semaine : texte à part', () async {
      final writer = FakeReviewWriter();
      final narrator = narratorOf(writer);

      await narrator.narrate(computedWeek());
      final other = computedWeek(week: weekOct12.previous);

      expect(narrator.immediate(other), isA<NarrationWriting>());
      await narrator.narrate(other);
      expect(writer.writeCalls, 2);
      // Le texte de la première semaine est toujours là.
      expectText(narrator.immediate(computedWeek()), validReviewText);
      expect(writer.writeCalls, 2);
    });
  });

  group('CA34 : la sensibilité passe avant la mémoire', () {
    test('CA34 : texte gardé, mêmes faits, mais la semaine est devenue '
        'sensible : plus de texte, rédacteur non appelé', () async {
      final writer = FakeReviewWriter();
      final narrator = narratorOf(writer);
      await narrator.narrate(computedWeek());
      expect(writer.writeCalls, 1);

      final sensitive = computedWeek(sensitive: true);

      expect(narrator.immediate(sensitive), isA<NarrationWithheld>());
      expect(await narrator.narrate(sensitive), isA<NarrationWithheld>());
      expect(writer.writeCalls, 1);
    });

    test('CA34 : après la suppression de l\'entrée (la semaine n\'est plus '
        'sensible), le texte effacé n\'est pas réutilisé : la mise en mots '
        'est relancée', () async {
      final writer = FakeReviewWriter();
      final narrator = narratorOf(writer);
      await narrator.narrate(computedWeek());

      narrator.immediate(computedWeek(sensitive: true));
      final back = computedWeek();

      expect(narrator.immediate(back), isA<NarrationWriting>());
      expectText(await narrator.narrate(back), validReviewText);
      expect(writer.writeCalls, 2);
    });

    test('CA34 : même effacement quand la semaine sensible est présentée à '
        '`narrate` directement', () async {
      final writer = FakeReviewWriter();
      final narrator = narratorOf(writer);
      await narrator.narrate(computedWeek());

      await narrator.narrate(computedWeek(sensitive: true));
      expect(narrator.immediate(computedWeek()), isA<NarrationWriting>());
    });
  });

  group('abandon (la personne quitte l\'écran pendant la mise en mots)', () {
    test('la mise en mots en cours est abandonnée : cancel du rédacteur '
        'appelé', () async {
      final writer = FakeReviewWriter(hang: true);
      final narrator = narratorOf(writer);

      final pending = narrator.narrate(computedWeek());
      await wait(const Duration(milliseconds: 20));
      await narrator.cancel();
      await pending;

      expect(writer.cancelCalls, greaterThanOrEqualTo(1));
    });

    test('le résultat d\'une mise en mots abandonnée n\'est pas gardé en '
        'mémoire', () async {
      final writer = ControlledReviewWriter();
      final narrator = narratorOf(writer);
      final review = computedWeek();

      final pending = narrator.narrate(review);
      await wait(const Duration(milliseconds: 20));
      await narrator.cancel();
      // Le moteur finit sa génération malgré l'abandon.
      writer.completeWithText(validReviewText);
      await pending.timeout(const Duration(seconds: 2));
      await wait(const Duration(milliseconds: 50));

      expect(writer.cancelCalls, greaterThanOrEqualTo(1));
      expect(narrator.immediate(review), isA<NarrationWriting>());
    });

    test('abandonner sans mise en mots en cours ne plante pas', () async {
      final narrator = narratorOf(FakeReviewWriter());

      await narrator.cancel();
    });

    test('le narrateur reste utilisable après un abandon', () async {
      final writer = FakeReviewWriter();
      final narrator = narratorOf(writer);
      await narrator.cancel();

      expectText(await narrator.narrate(computedWeek()), validReviewText);
    });
  });
}
