// Écran du bilan de la semaine et carte d'accès de la liste (spec 006, CA1 à CA6,
// CA8 à CA22, CA26 à CA34). Les textes font foi dans la spec et dans la maquette
// docs/maquettes/006-bilan-de-la-semaine/. Dépôt, téléchargeur et rédacteur
// factices : aucun modèle, aucune base, aucun réseau. Horloge : dimanche 18 octobre
// 2026 (semaine du 12 au 18), sauf mention contraire.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/review/review_writer.dart';
import 'package:tidemark/review/weekly_review.dart';
import 'package:tidemark/review/weekly_review_calculator.dart';
import 'package:tidemark/ui/screens/weekly_review_screen.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';

import '../support/distress_harness.dart'
    show allTextsOfScreen, expectNoTruncatedText, paintedColors, readingOrder;
import '../support/fake_review_writer.dart';
import '../support/model_texts.dart' show isAnnounced;
import '../support/review_harness.dart';
import '../support/ui_harness.dart';

const light = TidemarkColors.light;
const dark = TidemarkColors.dark;

/// Tiret demi-cadratin des dates du bilan.
const dash = '–';

final currentRange = '12 $dash 18 octobre';
final previousRange = '5 $dash 11 octobre';

/// `reviewWidgets` avec un environnement : il est démonté en fin de test, ce qui
/// abandonne une éventuelle mise en mots en cours (aucun délai ne reste en attente).
void envTest(
  String description,
  Future<void> Function(WidgetTester tester, ReviewEnv env) body, {
  ReviewEnv Function()? build,
  bool tall = true,
}) {
  reviewWidgets(description, (tester) async {
    final env = (build ?? ReviewEnv.new)();
    try {
      await body(tester, env);
    } finally {
      try {
        await env.dispose(tester);
      } catch (_) {
        // Le nettoyage ne doit pas masquer l'échec du test.
      }
    }
  }, tall: tall);
}

void useDarkTheme(WidgetTester tester) {
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

List<String> screenTexts(WidgetTester tester) =>
    allTextsOfScreen(tester, WeeklyReviewScreen);

/// Rectangle à l'écran d'un élément rendu.
Rect rectOfElement(Element element) {
  final box = element.renderObject! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

String plain(Text text) => text.data ?? text.textSpan?.toPlainText() ?? '';

/// Textes affichés à droite de [label], sur la même ligne (le nombre d'une ligne
/// de la répartition).
List<String> sameRowTexts(WidgetTester tester, String label) {
  final labelRect = tester.getRect(find.text(label));
  return [
    for (final element
        in find
            .descendant(
              of: find.byType(WeeklyReviewScreen),
              matching: find.byType(Text),
            )
            .evaluate())
      if ((rectOfElement(element).center.dy - labelRect.center.dy).abs() < 14 &&
          rectOfElement(element).left >= labelRect.right - 1)
        plain(element.widget as Text),
  ];
}

bool paints(Widget widget, Color color) => switch (widget) {
  DecoratedBox(:final decoration) =>
    decoration is BoxDecoration && decoration.color == color,
  ColoredBox(color: final c) => c == color,
  Material(color: final c) => c == color,
  _ => false,
};

/// Largeurs des barres (8 de haut) peintes de la couleur [color].
List<double> barWidths(WidgetTester tester, Color color) => [
  for (final element
      in find.byWidgetPredicate((w) => paints(w, color)).evaluate())
    if (rectOfElement(element).height.round() == 8)
      rectOfElement(element).width,
];

double barWidth(WidgetTester tester, Color color) {
  final widths = barWidths(tester, color);
  return widths.isEmpty ? 0 : widths.single;
}

/// Les sept cases de « Jours notés », de gauche à droite : lettre, et « notée »
/// si son fond est `tide-soft`.
List<({String letter, bool noted})> dayCells(WidgetTester tester) {
  final top = tester.getTopLeft(find.text(daysTitle)).dy;
  final bottom = tester.getTopLeft(find.text(tagsTitle)).dy;
  final cells = <({double x, String letter, bool noted})>[];
  for (final element
      in find
          .descendant(
            of: find.byType(WeeklyReviewScreen),
            matching: find.byType(Text),
          )
          .evaluate()) {
    final letter = plain(element.widget as Text);
    if (!const {'L', 'M', 'J', 'V', 'S', 'D'}.contains(letter)) continue;
    final rect = rectOfElement(element);
    if (rect.top <= top || rect.top >= bottom) continue;
    final noted = find
        .ancestor(
          of: find.byElementPredicate((e) => identical(e, element)),
          matching: find.byWidgetPredicate((w) => paints(w, light.tideSoft)),
        )
        .evaluate()
        .isNotEmpty;
    cells.add((x: rect.left, letter: letter, noted: noted));
  }
  cells.sort((a, b) => a.x.compareTo(b.x));
  return [for (final c in cells) (letter: c.letter, noted: c.noted)];
}

Tristate arrowState(WidgetTester tester, String label) => tester
    .getSemantics(find.bySemanticsLabel(label).first)
    .flagsCollection
    .isEnabled;

Color? textColor(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text)).text.style?.color;

/// Messages envoyés au lecteur d'écran par `SemanticsService.announce`.
List<String> captureAnnouncements(WidgetTester tester) {
  final messages = <String>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
    SystemChannels.accessibility,
    (dynamic message) async {
      if (message is Map && message['type'] == 'announce') {
        final data = message['data'];
        if (data is Map) messages.add('${data['message']}');
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return messages;
}

/// Bilan calculé par `WeeklyReviewCalculator`, sans rédacteur, sur les entrées du
/// dépôt factice (CA16).
ComputedWeek calculated(ReviewEnv env) {
  final review = const WeeklyReviewCalculator().compute(
    week: weekOct12,
    entries: env.repo.entries,
    tagsByEntry: {for (final e in env.repo.entries) e.id: e.tags},
  );
  expect(review, isA<ComputedWeek>());
  return review as ComputedWeek;
}

void main() {
  group('liste : carte d\'accès au bilan (CA1 à CA3)', () {
    envTest('CA1 : la carte « Bilan de la semaine » apparaît sous le titre, '
        'avant le premier jour, avec les dates de la semaine en cours', (
      tester,
      env,
    ) async {
      await env.nominalWeek();
      await showList(tester, env);

      expect(find.text(reviewCardTitle), findsOneWidget);
      expect(find.text('Du lundi 12 au dimanche 18 octobre'), findsOneWidget);
      final title = tester.getTopLeft(find.text('Ton journal')).dy;
      final card = tester.getTopLeft(find.text(reviewCardTitle)).dy;
      final firstDay = tester.getTopLeft(find.text("Aujourd'hui")).dy;
      expect(card, greaterThan(title));
      expect(card, lessThan(firstDay));
    });

    envTest('CA1 : la carte s\'annonce comme un bouton « Bilan de la '
        'semaine, du lundi 12 au dimanche 18 octobre »', (tester, env) async {
      await env.nominalWeek();
      await showList(tester, env);

      final label = find.bySemanticsLabel(
        RegExp(r'^Bilan de la semaine, du lundi 12 au dimanche 18 octobre$'),
      );
      expect(label, findsOneWidget);
      expect(tester.getSemantics(label).flagsCollection.isButton, isTrue);
    });

    envTest('CA1 : quand le mois change, les deux mois sont écrits', (
      tester,
      env,
    ) async {
      await env.addAt(DateTime(2026, 10, 1, 9), 3);
      await showList(tester, env);

      expect(
        find.text('Du lundi 28 septembre au dimanche 4 octobre'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(
            r'^Bilan de la semaine, du lundi 28 septembre au dimanche 4 octobre$',
          ),
        ),
        findsOneWidget,
      );
    }, build: () => ReviewEnv(now: DateTime(2026, 10, 1, 10)));

    envTest('CA1 : quand l\'année change, l\'année suit chaque borne', (
      tester,
      env,
    ) async {
      await env.addAt(DateTime(2026, 1, 1, 9), 3);
      await showList(tester, env);

      expect(
        find.text('Du lundi 29 décembre 2025 au dimanche 4 janvier 2026'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(
            r'^Bilan de la semaine, du lundi 29 décembre 2025 au dimanche 4 janvier 2026$',
          ),
        ),
        findsOneWidget,
      );
    }, build: () => ReviewEnv(now: DateTime(2026, 1, 2, 10)));

    envTest('CA38 : le dimanche 1er novembre, la carte écrit « 1er » et '
        's\'annonce « Bilan de la semaine, du lundi 26 octobre au dimanche '
        '1er novembre »', (tester, env) async {
      await env.addAt(DateTime(2026, 10, 28, 9), 3);
      await showList(tester, env);

      expect(
        find.text('Du lundi 26 octobre au dimanche 1er novembre'),
        findsOneWidget,
      );
      final label = find.bySemanticsLabel(
        RegExp(
          r'^Bilan de la semaine, du lundi 26 octobre au dimanche 1er novembre$',
        ),
      );
      expect(label, findsOneWidget);
      expect(tester.getSemantics(label).flagsCollection.isButton, isTrue);
    }, build: () => ReviewEnv(now: DateTime(2026, 10, 28, 10)));

    envTest('CA38 : l\'écran du bilan de cette semaine écrit « 26 octobre – '
        '1er novembre »', (tester, env) async {
      await env.addAt(DateTime(2026, 10, 28, 9), 3);
      await showReview(tester, env);

      expect(find.text('26 octobre $dash 1er novembre'), findsOneWidget);
    }, build: () => ReviewEnv(now: DateTime(2026, 10, 28, 10)));

    envTest('CA2 : liste vide : pas de carte ; dès la première entrée, '
        'elle apparaît', (tester, env) async {
      await showList(tester, env);

      expect(find.text('Ton journal'), findsOneWidget);
      expect(find.text(reviewCardTitle), findsNothing);

      await env.add(1, 3);
      await settle(tester);

      expect(find.text(reviewCardTitle), findsOneWidget);
    });

    envTest('CA2 : liste en cours de lecture : pas de carte ; une fois la '
        'lecture faite, elle apparaît', (tester, env) async {
      await env.nominalWeek();
      env.repo.neverEmit = true;
      await showList(tester, env);

      expect(find.text(reviewCardTitle), findsNothing);

      await tester.pumpWidget(const SizedBox());
      env.repo.neverEmit = false;
      await showList(tester, env);

      expect(find.text(reviewCardTitle), findsOneWidget);
    });

    envTest('CA2 : liste en erreur : pas de carte ; une fois la lecture '
        'rétablie, elle apparaît', (tester, env) async {
      await env.nominalWeek();
      env.repo.watchError = StateError('lecture impossible');
      await showList(tester, env);

      expect(find.text(reviewCardTitle), findsNothing);

      await tester.pumpWidget(const SizedBox());
      env.repo.watchError = null;
      await showList(tester, env);

      expect(find.text(reviewCardTitle), findsOneWidget);
    });

    envTest('CA3 : toucher la carte ouvre l\'écran du bilan sur la semaine '
        'en cours', (tester, env) async {
      await env.nominalWeek();
      await showList(tester, env);

      await openReview(tester);

      expect(find.byType(WeeklyReviewScreen), findsOneWidget);
      expect(find.text('Ta semaine'), findsOneWidget);
      expect(find.text(currentRange), findsOneWidget);
      expect(find.text('Semaine en cours'), findsOneWidget);
    });

    envTest('CA3 : la carte ouvre le bilan même avec moins de 3 entrées dans '
        'la semaine', (tester, env) async {
      await env.add(1, 3);
      await showList(tester, env);

      await openReview(tester);

      expect(find.byType(WeeklyReviewScreen), findsOneWidget);
      expect(find.text(insufficientTitle), findsOneWidget);
      expect(find.text(insufficientBody(1)), findsOneWidget);
      expect(env.writeCalls, 0);
    });

    envTest('CA3 : une seule entrée, d\'une semaine plus ancienne : la carte '
        'est là, la semaine en cours n\'a aucune entrée', (tester, env) async {
      await env.add(2, 3, weeksBack: 3);
      await showList(tester, env);

      await openReview(tester);

      expect(find.text(insufficientBody(0)), findsOneWidget);
    });

    envTest('CA4 : le retour « Journal » ramène à la liste', (
      tester,
      env,
    ) async {
      await env.nominalWeek();
      await showList(tester, env);
      await openReview(tester);

      await goBack(tester);

      expect(find.byType(WeeklyReviewScreen), findsNothing);
      expect(find.text('Ton journal'), findsOneWidget);
    });
  });

  group('semaine affichée (CA4, CA5)', () {
    envTest('CA4 : retour « Journal », titre « Ta semaine », dates et '
        '« Semaine en cours »', (tester, env) async {
      await env.nominalWeek();
      await showReview(tester, env);

      expect(find.text('Journal'), findsOneWidget);
      expect(find.text('Ta semaine'), findsOneWidget);
      expect(find.text(currentRange), findsOneWidget);
      expect(find.text('Semaine en cours'), findsOneWidget);
      expect(find.text('Semaine dernière'), findsNothing);
    });

    envTest('CA4 : la semaine précédente porte « Semaine dernière » ; la '
        'suivante des autres n\'a aucune mention', (tester, env) async {
      await env.nominalWeek();
      await env.moods([3, 3, 3], weeksBack: 1);
      await env.moods([3, 3, 3], weeksBack: 2);
      await showReview(tester, env);

      await tapPreviousWeek(tester);
      expect(find.text(previousRange), findsOneWidget);
      expect(find.text('Semaine dernière'), findsOneWidget);
      expect(find.text('Semaine en cours'), findsNothing);

      await tapPreviousWeek(tester);
      expect(find.text('28 septembre $dash 4 octobre'), findsOneWidget);
      expect(find.text('Semaine dernière'), findsNothing);
      expect(find.text('Semaine en cours'), findsNothing);
    });

    envTest(
      'CA4 : semaine à cheval sur deux années : l\'année à chaque borne ; '
      'semaine d\'une autre année : jour, mois et année aux deux bornes',
      (tester, env) async {
        await env.addAt(DateTime(2026, 1, 1, 9), 3);
        await env.addAt(DateTime(2026, 1, 2, 9), 3);
        await env.addAt(DateTime(2026, 1, 3, 9), 3);
        await env.addAt(DateTime(2025, 12, 20, 9), 3);
        await showReview(tester, env);

        expect(
          find.text('29 décembre 2025 $dash 4 janvier 2026'),
          findsOneWidget,
        );
        expect(find.text('Semaine en cours'), findsOneWidget);

        await tapPreviousWeek(tester);

        expect(
          find.text('22 décembre 2025 $dash 28 décembre 2025'),
          findsOneWidget,
        );
        expect(find.text('Semaine dernière'), findsOneWidget);
      },
      build: () => ReviewEnv(now: DateTime(2026, 1, 2, 10)),
    );

    // Revue IA : l'année de référence est celle du jour, pas celle du dimanche
    // de la semaine en cours.
    envTest('CA4 : le lundi 28 décembre 2026, la semaine précédente (21 – 27 '
        'décembre 2026) s\'affiche sans année', (tester, env) async {
      await env.addAt(DateTime(2026, 12, 21, 9), 3);
      await env.addAt(DateTime(2026, 12, 28, 9), 3);
      await showReview(tester, env);

      expect(
        find.text('28 décembre 2026 $dash 3 janvier 2027'),
        findsOneWidget,
      );

      await tapPreviousWeek(tester);

      expect(find.text('21 $dash 27 décembre'), findsOneWidget);
    }, build: () => ReviewEnv(now: DateTime(2026, 12, 28, 10)));

    envTest('CA5 : « Semaine précédente » et « Semaine suivante » changent '
        'la semaine ; « Semaine suivante » est désactivé sur la semaine en '
        'cours, « Semaine précédente » sur la semaine de l\'entrée la plus '
        'ancienne', (tester, env) async {
      await env.nominalWeek();
      await env.moods([3, 3, 3, 3, 3], weeksBack: 1);
      await showReview(tester, env);

      expect(find.text(currentRange), findsOneWidget);
      expect(arrowState(tester, 'Semaine suivante'), Tristate.isFalse);
      expect(arrowState(tester, 'Semaine précédente'), Tristate.isTrue);

      await tapPreviousWeek(tester);

      expect(find.text(previousRange), findsOneWidget);
      expect(find.text(currentRange), findsNothing);
      expect(arrowState(tester, 'Semaine précédente'), Tristate.isFalse);
      expect(arrowState(tester, 'Semaine suivante'), Tristate.isTrue);

      await tapNextWeek(tester);

      expect(find.text(currentRange), findsOneWidget);
      expect(arrowState(tester, 'Semaine suivante'), Tristate.isFalse);
    });

    envTest('CA5 : toucher une flèche désactivée ne change rien', (
      tester,
      env,
    ) async {
      await env.nominalWeek();
      await showReview(tester, env);

      // Une seule semaine consultable : la semaine en cours, entrée la plus
      // ancienne comprise.
      expect(arrowState(tester, 'Semaine précédente'), Tristate.isFalse);
      expect(arrowState(tester, 'Semaine suivante'), Tristate.isFalse);
      await tester.tap(
        find.bySemanticsLabel('Semaine précédente').first,
        warnIfMissed: false,
      );
      await tester.tap(
        find.bySemanticsLabel('Semaine suivante').first,
        warnIfMissed: false,
      );
      await settle(tester);

      expect(find.text(currentRange), findsOneWidget);
    });

    envTest('CA5 : on remonte semaine par semaine jusqu\'à celle de l\'entrée '
        'la plus ancienne, y compris les semaines sans entrée', (
      tester,
      env,
    ) async {
      await env.nominalWeek();
      await env.add(3, 4, weeksBack: 2); // mercredi 30 septembre
      await showReview(tester, env);

      await tapPreviousWeek(tester);
      expect(find.text(previousRange), findsOneWidget);
      expect(find.text(insufficientBody(0)), findsOneWidget);
      expect(arrowState(tester, 'Semaine précédente'), Tristate.isTrue);

      await tapPreviousWeek(tester);
      expect(find.text('28 septembre $dash 4 octobre'), findsOneWidget);
      expect(find.text(insufficientBody(1)), findsOneWidget);
      expect(arrowState(tester, 'Semaine précédente'), Tristate.isFalse);
      expect(arrowState(tester, 'Semaine suivante'), Tristate.isTrue);
    });
  });

  group('CA6 : moins de 3 entrées', () {
    for (final count in [0, 1, 2]) {
      envTest('CA6 : $count entrée(s) : « Pas encore de bilan pour cette '
          'semaine » et le message du seuil, sans chiffre ni texte, rédacteur '
          'non appelé', (tester, env) async {
        // Une entrée d'une semaine plus ancienne garde la liste non vide.
        await env.add(1, 3, weeksBack: 3);
        for (var i = 0; i < count; i++) {
          await env.add(i + 1, 3);
        }
        await showReview(tester, env);

        expect(find.text(insufficientTitle), findsOneWidget);
        expect(find.text(insufficientBody(count)), findsOneWidget);
        for (final absent in [
          'Entrées',
          'Humeur moyenne',
          distributionTitle,
          daysTitle,
          tagsTitle,
          evolutionTitle,
          writingText,
          withheldText,
          noModelText,
        ]) {
          expect(find.text(absent), findsNothing, reason: absent);
        }
        expect(env.writeCalls, 0);
      });
    }
  });

  group('chiffres (CA8 à CA17)', () {
    envTest('CA8 : 7 entrées dont une non analysée sans texte, une non '
        'analysée avec texte (détresse) et une en attente : « Entrées » vaut '
        '7, sur 7 jours', (tester, env) async {
      await env.add(1, 3, status: AnalysisStatus.skipped);
      await env.add(2, 3, text: distressText, status: AnalysisStatus.skipped);
      await env.add(3, 4, text: neutralText, status: AnalysisStatus.pending);
      await env.add(4, 3, text: neutralText, status: AnalysisStatus.untagged);
      await env.add(5, 3, tags: [emotionTag('joie')]);
      await env.add(6, 5);
      await env.add(7, 4);
      await showReview(tester, env);

      expect(find.text('Entrées'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('sur 7 jours'), findsOneWidget);
      final label = tester.getTopLeft(find.text('Entrées')).dy;
      final value = tester.getTopLeft(find.text('7')).dy;
      final unit = tester.getTopLeft(find.text('sur 7 jours')).dy;
      expect(label, lessThan(value));
      expect(value, lessThan(unit));
    });

    // Quatre exemples de la spec, un test chacun : une base par exemple.
    final averages = <({List<int> moods, String shown})>[
      (moods: [4, 3, 2, 4, 5, 3, 4], shown: '3,6'),
      (moods: [3, 4, 3, 4], shown: '3,5'),
      (moods: [2, 3, 3], shown: '2,7'),
      (moods: [3, 3, 4, 4, 4, 4, 4, 4], shown: '3,8'),
    ];
    for (final example in averages) {
      envTest('CA9 : humeurs ${example.moods.join(', ')} : « Humeur moyenne » '
          'vaut « ${example.shown} », suivi de « sur 5 »', (tester, env) async {
        await env.moods(example.moods);
        await showReview(tester, env);

        expect(find.text('Humeur moyenne'), findsOneWidget);
        expect(find.text(example.shown), findsOneWidget);
        expect(find.text('sur 5'), findsOneWidget);
        final label = tester.getTopLeft(find.text('Humeur moyenne')).dy;
        final value = tester.getTopLeft(find.text(example.shown)).dy;
        final unit = tester.getTopLeft(find.text('sur 5')).dy;
        expect(label, lessThan(value));
        expect(value, lessThan(unit));
      });
    }

    envTest('CA10 : une ligne par humeur, de « Très bas » à « Très bien », '
        'avec leur nombre (0, 1, 2, 3, 1), zéros compris', (tester, env) async {
      await env.nominalWeek();
      await showReview(tester, env);

      expect(find.text(distributionTitle), findsOneWidget);
      const labels = ['Très bas', 'Bas', 'Neutre', 'Bien', 'Très bien'];
      const counts = ['0', '1', '2', '3', '1'];
      double? previousTop;
      for (var i = 0; i < 5; i++) {
        expect(find.text(labels[i]), findsOneWidget, reason: labels[i]);
        expect(
          sameRowTexts(tester, labels[i]),
          contains(counts[i]),
          reason: 'nombre de « ${labels[i]} »',
        );
        final top = tester.getTopLeft(find.text(labels[i])).dy;
        if (previousTop != null) expect(top, greaterThan(previousTop));
        previousTop = top;
      }
    });

    envTest('CA10 : une barre proportionnelle au plus grand nombre : 3 → '
        'barre pleine, 2 → 2/3, 1 → 1/3, 0 → aucune largeur', (
      tester,
      env,
    ) async {
      await env.nominalWeek();
      await showReview(tester, env);

      final full = barWidth(tester, light.mood4);
      expect(full, greaterThan(30));
      expect(barWidth(tester, light.mood3), closeTo(full * 2 / 3, 1.5));
      expect(barWidth(tester, light.mood2), closeTo(full / 3, 1.5));
      expect(barWidth(tester, light.mood5), closeTo(full / 3, 1.5));
      expect(barWidth(tester, light.mood1), 0);
    });

    envTest('CA11 : entrées lundi, mardi, jeudi, samedi et dimanche, dont '
        'plusieurs le même jour : « 5 jours sur 7 », « sur 5 jours », sept '
        'cases de L à D dont cinq notées', (tester, env) async {
      await env.nominalWeek();
      await showReview(tester, env);

      expect(find.text(daysTitle), findsOneWidget);
      expect(find.text('5 jours sur 7'), findsOneWidget);
      expect(find.text('sur 5 jours'), findsOneWidget);
      final cells = dayCells(tester);
      expect(cells.map((c) => c.letter).toList(), [
        'L',
        'M',
        'M',
        'J',
        'V',
        'S',
        'D',
      ]);
      expect(cells.map((c) => c.noted).toList(), [
        true,
        true,
        false,
        true,
        false,
        true,
        true,
      ]);
    });

    envTest('CA11 : 3 entrées le même jour : « 1 jour sur 7 » et « sur 1 '
        'jour » (singulier)', (tester, env) async {
      await env.add(3, 3);
      await env.add(3, 4);
      await env.add(3, 5);
      await showReview(tester, env);

      expect(find.text('1 jour sur 7'), findsOneWidget);
      expect(find.text('sur 1 jour'), findsOneWidget);
      expect(find.text('1 jours sur 7'), findsNothing);
      expect(find.text('sur 1 jours'), findsNothing);
      expect(dayCells(tester).where((c) => c.noted).length, 1);
    });

    envTest('CA12 : fatigue (3), travail (3), calme (2), joie (1) : « fatigue '
        '· 3 », « travail · 3 », « calme · 2 » dans cet ordre, et « Analysé '
        'sur ton téléphone »', (tester, env) async {
      await env.nominalWeek();
      await showReview(tester, env);

      expect(find.text(tagsTitle), findsOneWidget);
      const chips = ['fatigue · 3', 'travail · 3', 'calme · 2'];
      for (final chip in chips) {
        expect(find.text(chip), findsOneWidget, reason: chip);
      }
      expect(find.textContaining('joie'), findsNothing);
      final ordered = [...chips]
        ..sort((a, b) {
          final ra = tester.getTopLeft(find.text(a));
          final rb = tester.getTopLeft(find.text(b));
          final byRow = ra.dy.round().compareTo(rb.dy.round());
          return byRow != 0 ? byRow : ra.dx.compareTo(rb.dx);
        });
      expect(ordered, chips);
      expect(find.text(tagsMention), findsOneWidget);
    });

    envTest('CA12 : seules les entrées « étiquetées » comptent : une entrée '
        'sans étiquette ou en attente n\'ajoute rien', (tester, env) async {
      await env.add(1, 3, tags: [emotionTag('joie')]);
      await env.add(2, 3, text: neutralText, status: AnalysisStatus.pending);
      await env.add(3, 3, text: neutralText, status: AnalysisStatus.untagged);
      await showReview(tester, env);

      expect(find.text('joie · 1'), findsOneWidget);
      expect(find.textContaining('· '), findsOneWidget);
    });

    envTest('CA13 : aucune entrée étiquetée : « Aucune étiquette cette '
        'semaine. »', (tester, env) async {
      await env.nominalWeek(tags: false);
      await showReview(tester, env);

      expect(find.text(tagsTitle), findsOneWidget);
      expect(find.text(noTagsText), findsOneWidget);
      expect(find.textContaining('· '), findsNothing);
    });

    envTest('CA14 : précédente de 5 entrées (moyenne 3,0), courante de 7 '
        '(moyenne 3,6) : « Humeur moyenne : 3,6, contre 3,0. En hausse de '
        '0,6. » et « Entrées : 7, contre 5. »', (tester, env) async {
      await env.nominalWeek();
      await env.moods([3, 3, 3, 3, 3], weeksBack: 1);
      await showReview(tester, env);

      expect(find.text(evolutionTitle), findsOneWidget);
      expect(
        find.text('Humeur moyenne : 3,6, contre 3,0. En hausse de 0,6.'),
        findsOneWidget,
      );
      expect(find.text('Entrées : 7, contre 5.'), findsOneWidget);
    });

    envTest('CA14 : moyennes arrondies égales : « Stable. »', (
      tester,
      env,
    ) async {
      await env.nominalWeek();
      await env.moods([4, 3, 2, 4, 5, 3, 4], weeksBack: 1);
      await showReview(tester, env);

      expect(
        find.text('Humeur moyenne : 3,6, contre 3,6. Stable.'),
        findsOneWidget,
      );
      expect(find.text('Entrées : 7, contre 7.'), findsOneWidget);
    });

    envTest('CA14 : moyenne plus basse que la précédente : « En baisse de '
        '0,6. »', (tester, env) async {
      await env.nominalWeek();
      await env.moods([4, 4, 4, 4, 5], weeksBack: 1);
      await showReview(tester, env);

      expect(
        find.text('Humeur moyenne : 3,6, contre 4,2. En baisse de 0,6.'),
        findsOneWidget,
      );
      expect(find.text('Entrées : 7, contre 5.'), findsOneWidget);
    });

    envTest('CA14 : une semaine précédente sensible sert quand même à '
        'l\'évolution', (tester, env) async {
      await env.nominalWeek();
      await env.moods([1, 3, 3, 3], weeksBack: 1);
      await showReview(tester, env);

      expect(find.text(evolutionTitle), findsOneWidget);
      expect(
        find.text('Humeur moyenne : 3,6, contre 2,5. En hausse de 1,1.'),
        findsOneWidget,
      );
    });

    envTest('CA15 : semaine précédente de moins de 3 entrées : pas de carte '
        'd\'évolution', (tester, env) async {
      await env.nominalWeek();
      await env.moods([3, 3], weeksBack: 1);
      await showReview(tester, env);

      expect(find.text('Entrées'), findsOneWidget);
      expect(find.text(evolutionTitle), findsNothing);
      expect(find.textContaining('contre'), findsNothing);
    });

    envTest('CA15 : aucune semaine précédente : pas de carte d\'évolution', (
      tester,
      env,
    ) async {
      await env.nominalWeek();
      await showReview(tester, env);

      expect(find.text('Entrées'), findsOneWidget);
      expect(find.text(evolutionTitle), findsNothing);
    });

    envTest('CA16 : avec un rédacteur qui rend un texte valide, chaque chiffre '
        'affiché est celui du calculateur, identique à un bilan sans rédacteur '
        '(RM10)', (tester, env) async {
      await env.nominalWeek();
      await env.moods([3, 3, 3, 3, 3], weeksBack: 1);
      await showReview(tester, env);
      expect(find.text(validReviewText), findsOneWidget);
      final withWriter = screenTexts(tester).where(hasNumeric).toList()..sort();
      final review = calculated(env);
      expect(find.text(formatTenths(review.averageMoodTenths)), findsOneWidget);
      expect(find.text('${review.entryCount}'), findsOneWidget);
      expect(find.text('sur ${review.notedDays.length} jours'), findsOneWidget);
      expect(
        find.text('Entrées : ${review.entryCount}, contre 5.'),
        findsOneWidget,
      );

      // Même journal, modèle absent : aucun texte, mêmes chiffres.
      await tester.pumpWidget(const SizedBox());
      final bare = ReviewEnv(model: absentModel);
      await bare.nominalWeek();
      await bare.moods([3, 3, 3, 3, 3], weeksBack: 1);
      await showReview(tester, bare);
      expect(find.text(validReviewText), findsNothing);
      final withoutWriter = screenTexts(tester).where(hasNumeric).toList()
        ..sort();

      expect(withWriter, withoutWriter);
      expect(bare.writeCalls, 0);
    });

    envTest('CA17 : une entrée ajoutée ou supprimée : les chiffres sont '
        'recalculés au retour sur l\'écran', (tester, env) async {
      await env.nominalWeek(tags: false);
      await showList(tester, env);
      await openReview(tester);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('3,6'), findsOneWidget);
      await goBack(tester);

      final added = await env.add(3, 3);
      await openReview(tester);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('3,5'), findsOneWidget);
      expect(find.text('sur 6 jours'), findsOneWidget);
      await goBack(tester);

      await tester.runAsync(() => env.repo.deleteEntry(added.id));
      await settle(tester);
      await openReview(tester);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('3,6'), findsOneWidget);
      expect(find.text('sur 5 jours'), findsOneWidget);
    });
  });

  group('mise en mots (CA18 à CA22, CA26 à CA28)', () {
    envTest(
      'CA18 : les chiffres s\'affichent sans attendre le modèle ; la carte du '
      'texte montre « Mise en mots sur ton téléphone… » et « Les chiffres '
      'ci-dessous sont déjà complets. » jusqu\'à la réponse',
      (tester, env) async {
        await env.nominalWeek();
        await showReview(tester, env);

        expect(env.writeCalls, 1);
        expect(find.text(writingText), findsOneWidget);
        expect(find.text(figuresCompleteText), findsOneWidget);
        expect(find.text('Entrées'), findsOneWidget);
        expect(find.text('3,6'), findsOneWidget);
        expect(find.text(distributionTitle), findsOneWidget);
        expect(find.text(validReviewText), findsNothing);
        expect(find.text(writtenMention), findsNothing);
      },
      build: () => ReviewEnv(writer: ControlledReviewWriter()),
    );

    envTest(
      'CA19 : la sortie arrive et passe la validation : la carte montre le '
      'texte, suivi de « Mis en mots sur ton téléphone, à partir des chiffres '
      'ci-dessous »',
      (tester, env) async {
        await env.nominalWeek();
        await showReview(tester, env);
        expect(find.text(writingText), findsOneWidget);

        env.controlledWriter.completeWithText(validReviewText);
        await settle(tester);

        expect(find.text(validReviewText), findsOneWidget);
        expect(find.text(writtenMention), findsOneWidget);
        expect(find.text(writingText), findsNothing);
        expect(find.text(figuresCompleteText), findsNothing);
        final text = tester.getTopLeft(find.text(validReviewText)).dy;
        final mention = tester.getTopLeft(find.text(writtenMention)).dy;
        expect(mention, greaterThan(text));
      },
      build: () => ReviewEnv(writer: ControlledReviewWriter()),
    );

    envTest('CA19 : de haut en bas : le texte, les chiffres clés, '
        'l\'évolution, la répartition, les jours notés, les étiquettes', (
      tester,
      env,
    ) async {
      await env.nominalWeek();
      await env.moods([3, 3, 3, 3, 3], weeksBack: 1);
      await showReview(tester, env);

      final order = [
        validReviewText,
        'Entrées',
        evolutionTitle,
        distributionTitle,
        daysTitle,
        tagsTitle,
      ];
      final tops = [
        for (final text in order) tester.getTopLeft(find.text(text)).dy,
      ];
      for (var i = 1; i < tops.length; i++) {
        expect(tops[i], greaterThan(tops[i - 1]), reason: order[i]);
      }
    });

    final sensitiveCases = <String, Future<void> Function(ReviewEnv)>{
      'une entrée à « Très bas » (humeur 1)': (env) => env.add(3, 1),
      'une entrée non analysée avec texte': (env) =>
          env.add(3, 3, text: neutralText, status: AnalysisStatus.skipped),
      'un texte détecté par detectInText (en attente)': (env) =>
          env.add(3, 3, text: distressText, status: AnalysisStatus.pending),
      'un texte détecté par detectInText (étiqueté)': (env) =>
          env.add(3, 3, text: distressText, tags: [emotionTag('tristesse')]),
      'un texte détecté par detectInText (sans étiquette)': (env) =>
          env.add(3, 3, text: distressText, status: AnalysisStatus.untagged),
    };
    sensitiveCases.forEach((name, addTrigger) {
      envTest('CA20 : $name, seul : le rédacteur n\'est pas appelé, « Pas de '
          'texte pour cette semaine… », ni détresse, ni aide, ni 3114 à '
          'l\'écran', (tester, env) async {
        await env.add(1, 3);
        await env.add(2, 4);
        await addTrigger(env);
        await showReview(tester, env);

        expect(env.writeCalls, 0);
        expect(find.text(withheldText), findsOneWidget);
        expect(find.text(writingText), findsNothing);
        expect(find.text('Entrées'), findsOneWidget);
        final forbidden = RegExp(
          r'3114|aide|détresse|detresse|écran d',
          caseSensitive: false,
        );
        expect(screenTexts(tester).where(forbidden.hasMatch), isEmpty);
        expect(find.bySemanticsLabel(forbidden), findsNothing);
      });
    });

    envTest('CA20 : une semaine non sensible, avec des textes ordinaires : le '
        'rédacteur est appelé', (tester, env) async {
      await env.add(1, 3);
      await env.add(2, 2, text: neutralText, status: AnalysisStatus.pending);
      await env.add(3, 4, text: neutralText, tags: [emotionTag('calme')]);
      await showReview(tester, env);

      expect(env.writeCalls, 1);
      expect(find.text(withheldText), findsNothing);
    });

    envTest('CA21 : le rédacteur reçoit seulement les faits : libellé de '
        'l\'humeur, régularité, trois étiquettes, tendance', (
      tester,
      env,
    ) async {
      await env.nominalWeek();
      await env.moods([3, 3, 3, 3, 3], weeksBack: 1);
      await showReview(tester, env);

      expect(env.fakeWriter.received, [
        const ReviewFacts(
          averageMoodLabel: 'Bien',
          regularity: WeekRegularity.mostDays,
          topTagLabels: ['fatigue', 'travail', 'calme'],
          trend: ReviewTrend.up,
        ),
      ]);
    });

    envTest('CA21 : aucun texte d\'entrée ni chiffre dans ce que reçoit le '
        'rédacteur', (tester, env) async {
      const secrets = [
        'Zébulon a mangé mon sandwich',
        'Rendez-vous chez le dentiste',
        'Dispute avec Léa à propos du loyer',
      ];
      await env.add(1, 3, text: secrets[0], status: AnalysisStatus.untagged);
      await env.add(2, 4, text: secrets[1], tags: [emotionTag('fatigue')]);
      await env.add(3, 3, text: secrets[2], status: AnalysisStatus.pending);
      await showReview(tester, env);

      expect(env.fakeWriter.writeCalls, 1);
      final facts = env.fakeWriter.received.single;
      for (final serialized in [facts.toPrompt(), facts.toString()]) {
        for (final secret in secrets) {
          expect(serialized, isNot(contains(secret)));
        }
        for (final word in [
          'Zébulon',
          'sandwich',
          'dentiste',
          'Léa',
          'loyer',
        ]) {
          expect(serialized, isNot(contains(word)), reason: word);
        }
        expect(hasNumeric(serialized), isFalse, reason: serialized);
      }
      expect(facts.topTagLabels, ['fatigue']);
    });

    envTest('CA35 : 11 entrées de somme 38 : « Humeur moyenne » vaut « 3,5 » '
        'et le rédacteur reçoit « Neutre »', (tester, env) async {
      await env.moods([3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4]);
      await showReview(tester, env);

      expect(find.text('3,5'), findsOneWidget);
      expect(env.fakeWriter.received.single.averageMoodLabel, 'Neutre');
    });

    envTest('CA35 : la tendance transmise suit l\'évolution affichée : '
        '« Stable. » à l\'écran, tendance stable pour le rédacteur', (
      tester,
      env,
    ) async {
      await env.moods([3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4]);
      await env.moods([3, 4, 3, 4], weeksBack: 1);
      await showReview(tester, env);

      expect(
        find.text('Humeur moyenne : 3,5, contre 3,5. Stable.'),
        findsOneWidget,
      );
      expect(env.fakeWriter.received.single.trend, ReviewTrend.stable);
    });

    // CA22, CA23, CA24, CA26 : une sortie rejetée donne le bilan sans texte, avec
    // le message de CA22, sans plantage, et la sortie brute n'est jamais montrée.
    final rejected = <String, ({String output, String snippet})>{
      'CA22 : un chiffre (« 3 jours »)': (
        output: jsonText('Des journées calmes, 3 jours notés.'),
        // « 3 jours » seul figure aussi dans les chiffres de l'app (« sur 3
        // jours ») : on cherche la phrase de la sortie brute.
        snippet: '3 jours notés',
      ),
      'CA22 : un chiffre d\'une autre écriture': (
        output: jsonText('Des journées calmes, ٣ jours notés.'),
        snippet: '٣',
      ),
      'CA22 : une fraction (« ½ »)': (
        output: jsonText('Une semaine notée à ½ environ.'),
        snippet: '½',
      ),
      'CA22 : « % »': (
        output: jsonText('Une semaine calme à presque 100 %.'),
        snippet: '100 %',
      ),
      'CA23 : un mot de nombre (« Trois jours »)': (
        output: jsonText('Trois jours calmes cette semaine.'),
        snippet: 'Trois jours calmes',
      ),
      'CA24 : une expression interdite (« Tu devrais consulter. »)': (
        output: jsonText('Tu devrais consulter.'),
        snippet: 'Tu devrais',
      ),
      'CA26 : une sortie non conforme au schéma JSON': (
        output: 'Une semaine tranquille, sans JSON.',
        snippet: 'sans JSON',
      ),
      'CA26 : un texte vide': (output: '{"text": "   "}', snippet: '   '),
      'CA26 : un texte de plus de 300 caractères': (
        output: jsonText('Une semaine calme. ${'très ' * 70}lumineuse.'),
        snippet: 'très très très',
      ),
    };
    rejected.forEach((name, rejection) {
      envTest(
        '$name : bilan sans texte, avec « Pas de texte pour cette semaine… » ; '
        'chiffres affichés, sortie brute jamais montrée',
        (tester, env) async {
          await env.moods([3, 4, 3]);
          await showReview(tester, env);

          expect(env.writeCalls, 1);
          expect(find.text(withheldText), findsOneWidget);
          expect(find.text(writingText), findsNothing);
          expect(find.text(writtenMention), findsNothing);
          expect(find.text('Entrées'), findsOneWidget);
          if (rejection.snippet.trim().isNotEmpty) {
            expect(
              screenTexts(tester).where((t) => t.contains(rejection.snippet)),
              isEmpty,
            );
          }
          expect(tester.takeException(), isNull);
        },
        build: () =>
            ReviewEnv(writer: FakeReviewWriter(output: rejection.output)),
      );
    });

    envTest(
      'CA26 : le rédacteur rend WriterFailed : même message',
      (tester, env) async {
        await env.moods([3, 4, 3]);
        await showReview(tester, env);

        expect(find.text(withheldText), findsOneWidget);
        expect(find.text(noModelText), findsNothing);
      },
      build: () =>
          ReviewEnv(writer: FakeReviewWriter(draft: const WriterFailed())),
    );

    envTest(
      'CA26 : le rédacteur lève une erreur (contrat violé) : même message, '
      'sans plantage',
      (tester, env) async {
        await env.moods([3, 4, 3]);
        env.fakeWriter.throwError = StateError('moteur planté');
        await showReview(tester, env);

        expect(find.text(withheldText), findsOneWidget);
        expect(find.text('Entrées'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    envTest(
      'CA26 : aucune réponse avant le délai : même message, et la mise en '
      'mots est abandonnée',
      (tester, env) async {
        await env.moods([3, 4, 3]);
        await showReview(tester, env);

        expect(find.text(withheldText), findsOneWidget);
        expect(find.text(writingText), findsNothing);
        expect(env.controlledWriter.cancelCalls, greaterThanOrEqualTo(1));
      },
      build: () => ReviewEnv(
        writer: ControlledReviewWriter(),
        timeout: const Duration(milliseconds: 100),
      ),
    );

    envTest(
      'CA27 : modèle absent : le rédacteur n\'est pas appelé, « Pas de texte : '
      'le modèle local n\'est pas sur ce téléphone. Les chiffres sont calculés '
      'sans lui. », aucune proposition de téléchargement',
      (tester, env) async {
        await env.nominalWeek();
        await showReview(tester, env);

        expect(env.writeCalls, 0);
        expect(find.text(noModelText), findsOneWidget);
        expect(find.text('Entrées'), findsOneWidget);
        expect(find.textContaining('élécharg'), findsNothing);
        expect(find.byType(FilledButton), findsNothing);
        expect(find.byType(ElevatedButton), findsNothing);
        // Seul bouton texte : le retour « Journal » (CA4).
        expect(find.byType(TextButton), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Journal'), findsOneWidget);
        expect(find.byType(OutlinedButton), findsNothing);
      },
      build: () => ReviewEnv(model: absentModel),
    );

    envTest(
      'CA27 : modèle en cours de téléchargement : même message, rédacteur non '
      'appelé',
      (tester, env) async {
        await env.nominalWeek();
        await showReview(tester, env);

        expect(env.writeCalls, 0);
        expect(find.text(noModelText), findsOneWidget);
        expect(find.textContaining('élécharg'), findsNothing);
      },
      build: () => ReviewEnv(model: downloadingModel),
    );

    envTest(
      'CA27 : le rédacteur appelé rend quand même ModelMissing (modèle '
      'supprimé entre-temps) : même message',
      (tester, env) async {
        await env.nominalWeek();
        await showReview(tester, env);

        expect(env.writeCalls, 1);
        expect(find.text(noModelText), findsOneWidget);
        expect(find.text(withheldText), findsNothing);
      },
      build: () =>
          ReviewEnv(writer: FakeReviewWriter(draft: const ModelMissing())),
    );

    envTest('CA28 : un texte validé, on change de semaine puis on revient, '
        'sans entrée ajoutée ni supprimée : le même texte, sans nouvel appel '
        'au rédacteur', (tester, env) async {
      await env.nominalWeek();
      await env.moods([3, 3, 3, 3, 3], weeksBack: 1);
      await showReview(tester, env);
      expect(find.text(validReviewText), findsOneWidget);
      expect(env.writeCalls, 1);

      await tapPreviousWeek(tester);
      final callsAway = env.writeCalls;
      await tapNextWeek(tester);

      expect(find.text(currentRange), findsOneWidget);
      expect(find.text(validReviewText), findsOneWidget);
      expect(env.writeCalls, callsAway, reason: 'aucun nouvel appel au retour');
    });

    envTest('CA28 : sortir de l\'écran puis y revenir, sans changement : le '
        'texte gardé en mémoire, sans nouvel appel', (tester, env) async {
      await env.nominalWeek();
      await showList(tester, env);
      await openReview(tester);
      expect(find.text(validReviewText), findsOneWidget);
      await goBack(tester);

      await openReview(tester);

      expect(find.text(validReviewText), findsOneWidget);
      expect(env.writeCalls, 1);
    });

    envTest('CA28 : une entrée ajoutée qui change les faits relance la mise '
        'en mots', (tester, env) async {
      await env.moods([3, 3, 3]);
      await showList(tester, env);
      await openReview(tester);
      expect(env.writeCalls, 1);
      await goBack(tester);

      await env.add(4, 5);
      await env.add(5, 5);
      await openReview(tester);

      expect(env.writeCalls, 2);
    });

    envTest('CA34 : texte en mémoire, une entrée à 1 ajoutée un jour déjà '
        'noté sans changer les faits : plus de texte, « Pas de texte pour '
        'cette semaine… », rédacteur non appelé ; après suppression de '
        'l\'entrée, la mise en mots est relancée', (tester, env) async {
      await env.add(1, 3);
      await env.add(2, 4);
      await env.add(3, 3);
      await showList(tester, env);
      await openReview(tester);
      expect(find.text(validReviewText), findsOneWidget);
      expect(env.writeCalls, 1);
      await goBack(tester);

      final low = await env.add(2, 1);
      await openReview(tester);

      expect(find.text(validReviewText), findsNothing);
      expect(find.text(withheldText), findsOneWidget);
      expect(env.writeCalls, 1, reason: 'rédacteur non appelé');
      await goBack(tester);

      await tester.runAsync(() => env.repo.deleteEntry(low.id));
      await settle(tester);
      await openReview(tester);

      expect(env.writeCalls, 2, reason: 'le texte effacé n\'est pas réutilisé');
      expect(find.text(withheldText), findsNothing);
    });

    envTest('CA34 : même vérification avec une entrée en détresse d\'humeur '
        '3', (tester, env) async {
      await env.add(1, 3);
      await env.add(2, 4);
      await env.add(3, 3);
      await showList(tester, env);
      await openReview(tester);
      expect(find.text(validReviewText), findsOneWidget);
      await goBack(tester);

      final distress = await env.add(
        2,
        3,
        text: distressText,
        status: AnalysisStatus.skipped,
      );
      await openReview(tester);

      expect(find.text(validReviewText), findsNothing);
      expect(find.text(withheldText), findsOneWidget);
      expect(env.writeCalls, 1, reason: 'rédacteur non appelé');
      await goBack(tester);

      await tester.runAsync(() => env.repo.deleteEntry(distress.id));
      await settle(tester);
      await openReview(tester);

      expect(env.writeCalls, 2);
    });

    envTest('quitter l\'écran pendant la mise en mots : la génération est '
        'abandonnée, rien n\'est gardé : au retour, le rédacteur est rappelé '
        'et le texte arrivé en retard n\'est pas affiché', (tester, env) async {
      await env.nominalWeek();
      await showList(tester, env);
      await openReview(tester);
      expect(find.text(writingText), findsOneWidget);
      expect(env.writeCalls, 1);

      await goBack(tester);

      expect(env.controlledWriter.cancelCalls, greaterThanOrEqualTo(1));
      env.controlledWriter.completeWithText(validReviewText);
      await settle(tester);

      await openReview(tester);

      expect(env.writeCalls, 2, reason: 'rien n\'a été gardé');
      expect(find.text(writingText), findsOneWidget);
      expect(find.text(validReviewText), findsNothing);
    }, build: () => ReviewEnv(writer: ControlledReviewWriter()));

    // Revue IA : aller-retour entre deux semaines pendant une mise en mots. Le
    // résultat de la première requête, arrivé en retard, ne s'applique pas à la
    // nouvelle requête de la même semaine.
    envTest('changement de semaine pendant la mise en mots : abandonnée ; au '
        'retour, le résultat en retard de la première requête est ignoré, et '
        'la sortie de l\'écran abandonne la requête en cours', (
      tester,
      env,
    ) async {
      await env.nominalWeek();
      await env.nominalWeek(weeksBack: 1);
      await showReview(tester, env);
      expect(env.writeCalls, 1);

      await tapPreviousWeek(tester);
      expect(env.controlledWriter.cancelCalls, greaterThanOrEqualTo(1));
      await tapNextWeek(tester);
      expect(env.writeCalls, 3);
      final cancelsBefore = env.controlledWriter.cancelCalls;

      env.controlledWriter.completeAt(0, const WriterFailed());
      await settle(tester);

      expect(find.text(writingText), findsOneWidget);
      expect(find.text(withheldText), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await settle(tester);
      expect(env.controlledWriter.cancelCalls, greaterThan(cancelsBefore));
    }, build: () => ReviewEnv(writer: ControlledReviewWriter()));
  });

  group('états (CA29, CA30)', () {
    envTest('CA29 : lecture en cours : retour, titre, semaine et « Calcul du '
        'bilan sur ton téléphone… », sans chiffre', (tester, env) async {
      await env.nominalWeek();
      env.repo.neverEmit = true;
      await showReview(tester, env);

      expect(find.text('Journal'), findsOneWidget);
      expect(find.text('Ta semaine'), findsOneWidget);
      expect(find.text(currentRange), findsOneWidget);
      expect(find.text(loadingText), findsOneWidget);
      for (final absent in [
        'Entrées',
        'Humeur moyenne',
        distributionTitle,
        daysTitle,
        tagsTitle,
        insufficientTitle,
      ]) {
        expect(find.text(absent), findsNothing, reason: absent);
      }
      final withDigits = screenTexts(tester).where(hasNumeric).toList();
      expect(withDigits, [currentRange]);
      expect(env.writeCalls, 0);
    });

    envTest('CA30 : erreur de lecture : le bandeau « Ton bilan n\'a pas pu '
        'être calculé », son explication et « Réessayer », qui relance la '
        'lecture', (tester, env) async {
      await env.nominalWeek();
      env.repo.watchError = StateError('lecture impossible');
      await showReview(tester, env);

      expect(find.text('Journal'), findsOneWidget);
      expect(find.text('Ta semaine'), findsOneWidget);
      expect(find.text(errorTitle), findsOneWidget);
      expect(find.text(errorBody), findsOneWidget);
      expect(find.text(retryLabel), findsOneWidget);
      expect(find.text('Entrées'), findsNothing);

      env.repo.watchError = null;
      await tester.tap(find.text(retryLabel));
      await settle(tester);

      expect(find.text(errorTitle), findsNothing);
      expect(find.text(retryLabel), findsNothing);
      expect(find.text('Entrées'), findsOneWidget);
      expect(find.text('3,6'), findsOneWidget);
    });

    envTest('CA30 : « Réessayer » avec une lecture toujours en erreur : le '
        'bandeau reste', (tester, env) async {
      env.repo.watchError = StateError('lecture impossible');
      await showReview(tester, env);

      await tester.tap(find.text(retryLabel));
      await settle(tester);

      expect(find.text(errorTitle), findsOneWidget);
      expect(find.text(retryLabel), findsOneWidget);
    });
  });

  group('accessibilité (CA31)', () {
    envTest('CA31 : le titre est annoncé en premier', (tester, env) async {
      await env.nominalWeek();
      await showReview(tester, env);

      expect(readingOrder(tester).first, 'Ta semaine');
    });

    envTest('CA31 : les flèches s\'annoncent « Semaine précédente » et '
        '« Semaine suivante », avec leur état désactivé', (tester, env) async {
      await env.nominalWeek();
      await env.moods([3, 3, 3], weeksBack: 1);
      await showReview(tester, env);

      final previous = tester.getSemantics(
        find.bySemanticsLabel('Semaine précédente').first,
      );
      final next = tester.getSemantics(
        find.bySemanticsLabel('Semaine suivante').first,
      );
      expect(previous.flagsCollection.isButton, isTrue);
      expect(next.flagsCollection.isButton, isTrue);
      expect(previous.flagsCollection.isEnabled, Tristate.isTrue);
      expect(next.flagsCollection.isEnabled, Tristate.isFalse);
    });

    envTest('CA31 : un changement de semaine annonce les nouvelles dates', (
      tester,
      env,
    ) async {
      final announcements = captureAnnouncements(tester);
      await env.nominalWeek();
      await env.moods([3, 3, 3], weeksBack: 1);
      await showReview(tester, env);

      await tapPreviousWeek(tester);

      final announced =
          announcements.any((m) => m.contains(previousRange)) ||
          isAnnounced(tester, find.text(previousRange));
      expect(announced, isTrue, reason: 'annonces : $announcements');
    });

    envTest('CA31 : « Humeur moyenne : 3,6 sur 5 » est lu d\'un bloc', (
      tester,
      env,
    ) async {
      await env.nominalWeek();
      await showReview(tester, env);

      expect(
        find.bySemanticsLabel(RegExp(r'^Humeur moyenne : 3,6 sur 5$')),
        findsOneWidget,
      );
    });

    envTest('CA31 : la répartition est annoncée en une phrase, les barres '
        'sont ignorées', (tester, env) async {
      await env.nominalWeek();
      await showReview(tester, env);

      expect(
        find.bySemanticsLabel(
          RegExp(
            r'Répartition des humeurs : Très bas, 0 entrée ; Bas, 1 entrée ; '
            r'Neutre, 2 entrées ; Bien, 3 entrées ; Très bien, 1 entrée\.',
          ),
        ),
        findsOneWidget,
      );
      for (final label in ['Très bas', 'Bas', 'Neutre', 'Bien', 'Très bien']) {
        expect(find.bySemanticsLabel(label), findsNothing, reason: label);
      }
    });

    envTest('CA31 : les jours notés aussi, en une phrase ; les cases L à D '
        'sont ignorées', (tester, env) async {
      await env.nominalWeek();
      await showReview(tester, env);

      expect(
        find.bySemanticsLabel(
          RegExp(r'Jours notés : lundi, mardi, jeudi, samedi, dimanche\.'),
        ),
        findsOneWidget,
      );
      for (final letter in ['L', 'M', 'J', 'V', 'S', 'D']) {
        expect(find.bySemanticsLabel(letter), findsNothing, reason: letter);
      }
    });

    envTest('CA31 : chaque étiquette s\'annonce « fatigue, 3 entrées »', (
      tester,
      env,
    ) async {
      await env.nominalWeek();
      await showReview(tester, env);

      for (final label in [
        'fatigue, 3 entrées',
        'travail, 3 entrées',
        'calme, 2 entrées',
      ]) {
        expect(
          find.bySemanticsLabel(RegExp('^${RegExp.escape(label)}\$')),
          findsOneWidget,
          reason: label,
        );
      }
    });

    envTest('CA31 : une étiquette portée par une seule entrée s\'annonce au '
        'singulier', (tester, env) async {
      await env.add(1, 3, tags: [emotionTag('joie')]);
      await env.add(2, 3);
      await env.add(3, 3);
      await showReview(tester, env);

      expect(
        find.bySemanticsLabel(RegExp(r'^joie, 1 entrée$')),
        findsOneWidget,
      );
    });
  });

  group('taille de texte à 200 % (CA32)', () {
    envTest('CA32 : l\'écran du bilan ne tronque ni ne déborde, défile '
        'jusqu\'aux étiquettes, et les flèches restent atteignables', (
      tester,
      env,
    ) async {
      await env.nominalWeek();
      await env.moods([3, 3, 3, 3, 3], weeksBack: 1);
      await showReview(tester, env, textScale: 2.0);

      expect(tester.takeException(), isNull);
      expectNoTruncatedText(
        tester,
        find.byType(WeeklyReviewScreen),
        'bilan 200 %',
      );
      for (final arrow in ['Semaine précédente', 'Semaine suivante']) {
        final rect = tester.getRect(find.bySemanticsLabel(arrow).first);
        expect(rect.left, greaterThanOrEqualTo(0), reason: arrow);
        expect(rect.right, lessThanOrEqualTo(393), reason: arrow);
        expect(rect.top, greaterThanOrEqualTo(0), reason: arrow);
        expect(rect.bottom, lessThanOrEqualTo(852), reason: arrow);
      }

      await tester.dragUntilVisible(
        find.text(tagsMention),
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      await settle(tester);
      expect(find.text(tagsMention), findsOneWidget);
      expect(tester.takeException(), isNull);
      expectNoTruncatedText(
        tester,
        find.byType(WeeklyReviewScreen),
        'bilan 200 %, bas de page',
      );
    }, tall: false);

    envTest('CA32 : à 200 %, toucher « Semaine précédente » change la '
        'semaine', (tester, env) async {
      await env.nominalWeek();
      await env.moods([3, 3, 3, 3, 3], weeksBack: 1);
      await showReview(tester, env, textScale: 2.0);

      await tester.tap(find.bySemanticsLabel('Semaine précédente').first);
      await settle(tester);

      expect(find.text(previousRange), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, tall: false);

    envTest('CA32 : à 200 %, les libellés de la répartition passent à la '
        'ligne : tous entiers, dans l\'écran', (tester, env) async {
      await env.nominalWeek();
      await showReview(tester, env, textScale: 2.0);

      await tester.dragUntilVisible(
        find.text('Très bien'),
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      await settle(tester);

      for (final label in ['Très bas', 'Bas', 'Neutre', 'Bien', 'Très bien']) {
        final rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(0), reason: label);
        expect(rect.right, lessThanOrEqualTo(393), reason: label);
      }
      expect(tester.takeException(), isNull);
      expectNoTruncatedText(
        tester,
        find.byType(WeeklyReviewScreen),
        'répartition 200 %',
      );
    }, tall: false);

    envTest('CA32 : à 200 %, les états sans chiffres (moins de 3 entrées, '
        'chargement, erreur) ne débordent pas', (tester, env) async {
      await env.add(1, 3);
      await showReview(tester, env, textScale: 2.0);
      expect(find.text(insufficientTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
      expectNoTruncatedText(
        tester,
        find.byType(WeeklyReviewScreen),
        'seuil 200 %',
      );

      await tester.pumpWidget(const SizedBox());
      final failing = ReviewEnv()..repo.watchError = StateError('lecture');
      await showReview(tester, failing, textScale: 2.0);
      expect(find.text(errorTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
      expectNoTruncatedText(
        tester,
        find.byType(WeeklyReviewScreen),
        'erreur 200 %',
      );
    }, tall: false);

    envTest('CA32 : la carte de la liste à 200 % ne tronque ni ne déborde', (
      tester,
      env,
    ) async {
      await env.nominalWeek();
      await showList(tester, env, textScale: 2.0);

      expect(find.text(reviewCardTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.text(reviewCardTitle));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(393));
      for (final text in [
        reviewCardTitle,
        'Du lundi 12 au dimanche 18 octobre',
      ]) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
        expect(paragraph.didExceedMaxLines, isFalse, reason: text);
        expect(
          tester.getRect(find.text(text)).right,
          lessThanOrEqualTo(393),
          reason: text,
        );
      }
    }, tall: false);
  });

  group('thème sombre (CA33)', () {
    envTest('CA33 : l\'écran du bilan utilise les couleurs du thème sombre, '
        'aucune couleur du thème clair', (tester, env) async {
      useDarkTheme(tester);
      await env.nominalWeek();
      await env.moods([3, 3, 3, 3, 3], weeksBack: 1);
      await showReview(tester, env);

      final colors = paintedColors(tester, find.byType(WeeklyReviewScreen));
      expect(colors, contains(dark.surfaceRaised));
      expect(colors, contains(dark.ink));
      expect(colors, contains(dark.tide));
      // Les couleurs « sur » (texte posé sur un fond plein) sont blanches en clair :
      // elles peuvent venir des valeurs par défaut du framework, pas du thème.
      final lightOnly = light.toTokenMap().values.toSet().difference({
        ...dark.toTokenMap().values,
        light.onTide,
        light.onMood,
      });
      expect(colors.intersection(lightOnly), isEmpty);
    });

    envTest('CA33 : les barres de la répartition prennent les couleurs '
        'mood-1 à mood-5 du thème sombre, avec libellé et nombre à côté', (
      tester,
      env,
    ) async {
      useDarkTheme(tester);
      await env.nominalWeek();
      await showReview(tester, env);

      final full = barWidth(tester, dark.mood4);
      expect(full, greaterThan(30));
      expect(barWidth(tester, dark.mood3), closeTo(full * 2 / 3, 1.5));
      expect(barWidth(tester, dark.mood2), closeTo(full / 3, 1.5));
      expect(barWidth(tester, dark.mood5), closeTo(full / 3, 1.5));
      expect(barWidths(tester, light.mood4), isEmpty);
      expect(sameRowTexts(tester, 'Bien'), contains('3'));
    });

    envTest('CA33 : `danger` ne sert pas en dehors du bandeau d\'erreur : '
        'absent du bilan nominal, du seuil et de la semaine sans texte', (
      tester,
      env,
    ) async {
      useDarkTheme(tester);
      await env.nominalWeek();
      await env.moods([1, 3, 3], weeksBack: 1);
      await showReview(tester, env);
      expect(
        paintedColors(tester, find.byType(WeeklyReviewScreen)),
        isNot(contains(dark.danger)),
      );

      await tapPreviousWeek(tester);
      expect(find.text(withheldText), findsOneWidget);
      expect(
        paintedColors(tester, find.byType(WeeklyReviewScreen)),
        isNot(contains(dark.danger)),
      );
    });

    envTest('CA33 : `danger` colore seulement le titre du bandeau d\'erreur '
        '(thème sombre)', (tester, env) async {
      useDarkTheme(tester);
      env.repo.watchError = StateError('lecture impossible');
      await showReview(tester, env);

      expect(textColor(tester, errorTitle), dark.danger);
      expect(textColor(tester, errorBody), isNot(dark.danger));
      expect(textColor(tester, 'Ta semaine'), isNot(dark.danger));
    });

    envTest('CA33 : `danger` colore le titre du bandeau d\'erreur (thème '
        'clair)', (tester, env) async {
      env.repo.watchError = StateError('lecture impossible');
      await showReview(tester, env);

      expect(textColor(tester, errorTitle), light.danger);
      expect(textColor(tester, errorBody), isNot(light.danger));
    });

    envTest('CA33 : thème clair : les barres prennent les couleurs mood-1 à '
        'mood-5 du thème clair', (tester, env) async {
      await env.nominalWeek();
      await showReview(tester, env);

      expect(barWidth(tester, light.mood4), greaterThan(30));
      expect(barWidths(tester, dark.mood4), isEmpty);
    });

    envTest('CA33 : la carte de la liste utilise les couleurs du thème '
        'sombre', (tester, env) async {
      useDarkTheme(tester);
      await env.nominalWeek();
      await showList(tester, env);

      Finder behindCard(Color color) => find.ancestor(
        of: find.text(reviewCardTitle),
        matching: find.byWidgetPredicate((w) => paints(w, color)),
      );
      expect(behindCard(dark.surfaceRaised), findsWidgets);
      expect(behindCard(light.surfaceRaised), findsNothing);
    });
  });
}
