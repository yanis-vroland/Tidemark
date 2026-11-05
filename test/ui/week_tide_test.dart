// Bilan en onglet : en-tête « marée de la semaine » et autocollants (spec 009, CA23 à
// CA25, CA27, CA28), sur `WeeklyReviewScreen(showBack: false)`. Dépôt, téléchargeur et
// rédacteur factices ; horloge : dimanche 18 octobre 2026 (semaine du 12 au 18).
//
// Semaine nominale du harnais (`ReviewEnv.nominalWeek`) : lundi 4 puis 3 (même
// instant : le plus grand identifiant gagne), mardi 2, jeudi 4, samedi 5 puis 3,
// dimanche 4 ; humeurs du jour : 3, 2, -, 4, -, 3, 4.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/review/weekly_review.dart';
import 'package:tidemark/review/weekly_review_calculator.dart';
import 'package:tidemark/ui/screens/weekly_review_screen.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';
import 'package:tidemark/ui/widgets/dashed_circle.dart';
import 'package:tidemark/ui/widgets/mood_bubble.dart';

import '../support/distress_harness.dart' show expectNoTruncatedText;
import '../support/fake_review_writer.dart' show validReviewText;
import '../support/home_harness.dart';
import '../support/playful_harness.dart';
import '../support/review_harness.dart';
import '../support/ui_harness.dart';

const light = TidemarkColors.light;
const dark = TidemarkColors.dark;

const nominalMoods = <int?>[3, 2, null, 4, null, 3, 4];

/// `reviewWidgets` avec un environnement démonté en fin de test.
void tideTest(
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

Widget tabScreen(
  ReviewEnv env, {
  double textScale = 1.0,
  GlobalKey? boundary,
  bool showBack = false,
}) {
  final screen = WeeklyReviewScreen(
    repository: env.repo,
    narrator: env.narrator,
    clock: () => env.now,
    showBack: showBack,
  );
  return ambientApp(
    boundary == null ? screen : RepaintBoundary(key: boundary, child: screen),
    textScale: textScale,
  );
}

Future<void> showTab(
  WidgetTester tester,
  ReviewEnv env, {
  double textScale = 1.0,
  GlobalKey? boundary,
}) async {
  await tester.pumpWidget(
    tabScreen(env, textScale: textScale, boundary: boundary),
  );
  await settle(tester);
}

/// Ordonnée au-dessous de laquelle commence le corps du bilan : le premier
/// autocollant, ou, sans bilan, le message « Pas encore de bilan ».
double bodyTop(WidgetTester tester) {
  final sticker = find.text('Humeur moyenne');
  if (sticker.evaluate().isNotEmpty) return tester.getTopLeft(sticker).dy;
  return tester.getTopLeft(find.text(insufficientTitle)).dy;
}

/// Bulles de l'en-tête (au-dessus du corps du bilan), de gauche à droite.
List<({int mood, Rect rect})> tideBubbles(WidgetTester tester) {
  final limit = bodyTop(tester);
  final found = [
    for (final element in find.byType(MoodBubble).evaluate())
      (
        mood: (element.widget as MoodBubble).mood,
        rect:
            (element.renderObject! as RenderBox).localToGlobal(Offset.zero) &
            (element.renderObject! as RenderBox).size,
      ),
  ].where((b) => b.rect.bottom <= limit).toList();
  found.sort((a, b) => a.rect.left.compareTo(b.rect.left));
  return found;
}

/// Cercles pointillés de l'en-tête.
int tideDashedCircles(WidgetTester tester) {
  final limit = bodyTop(tester);
  return find
      .byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is DashedCirclePainter,
      )
      .evaluate()
      .where((e) {
        final box = e.renderObject! as RenderBox;
        return box.localToGlobal(Offset.zero).dy + box.size.height <= limit;
      })
      .length;
}

const stickerLabels = ['Humeur moyenne', 'Jours notés', 'Entrées'];

/// Autocollant qui porte [label] : le `Transform` le plus proche au-dessus du texte,
/// qui ne doit contenir aucun des deux autres libellés (sinon ce serait l'écran
/// ou la transition de page, pas un autocollant).
Finder stickerOf(WidgetTester tester, String label) {
  Element? found;
  tester.element(find.text(label)).visitAncestorElements((element) {
    if (element.widget is Transform) {
      found = element;
      return false;
    }
    return true;
  });
  expect(found, isNotNull, reason: '« $label » n\'est pas dans un autocollant');
  final sticker = find.byElementPredicate((e) => identical(e, found));
  for (final other in stickerLabels.where((l) => l != label)) {
    expect(
      find.descendant(of: sticker, matching: find.text(other)),
      findsNothing,
      reason: 'l\'autocollant « $label » contient « $other »',
    );
  }
  return sticker;
}

/// Textes (concaténés) de l'autocollant qui porte [label].
String stickerText(WidgetTester tester, String label) => find
    .descendant(of: stickerOf(tester, label), matching: find.byType(RichText))
    .evaluate()
    .map((e) => (e.widget as RichText).text.toPlainText())
    .join(' ');

/// Ordonnée du premier pixel de [color] dans la colonne [x], entre [from] et [to].
int? firstInColumn(Pixels pixels, int x, Color color, int from, int to) {
  for (var y = from; y < to && y < pixels.height; y++) {
    if (isColor(pixels.at(x, y), color)) return y;
  }
  return null;
}

/// Bilan calculé par `WeeklyReviewCalculator`, sans rédacteur, sur les entrées du
/// dépôt factice.
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
  group('onglet sans retour (CA23)', () {
    tideTest('CA23 : showBack: false, pas de retour « Journal » ; titre, dates '
        'et flèches inchangés', (tester, env) async {
      await env.nominalWeek();
      await showTab(tester, env);

      expect(find.text('Journal'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.text('Ta semaine'), findsOneWidget);
      expect(find.text('12 – 18 octobre'), findsOneWidget);
      expect(find.text('Semaine en cours'), findsOneWidget);
      expect(find.bySemanticsLabel('Semaine précédente'), findsOneWidget);
      expect(find.bySemanticsLabel('Semaine suivante'), findsOneWidget);
    });

    tideTest('CA23 : sans retour, les flèches changent toujours de semaine', (
      tester,
      env,
    ) async {
      await env.nominalWeek();
      await env.moods([3, 3, 3], weeksBack: 1);
      await showTab(tester, env);

      await tapPreviousWeek(tester);
      expect(find.text('5 – 11 octobre'), findsOneWidget);
      await tapNextWeek(tester);

      expect(find.text('12 – 18 octobre'), findsOneWidget);
    });

    tideTest('CA23 : par défaut (showBack: true), le retour « Journal » est '
        'toujours là (écran ouvert par-dessus)', (tester, env) async {
      await env.nominalWeek();
      await tester.pumpWidget(tabScreen(env, showBack: true));
      await settle(tester);

      expect(find.widgetWithText(TextButton, 'Journal'), findsOneWidget);
    });

    tideTest('CA23 : les sections de la spec 006 sont toujours là', (
      tester,
      env,
    ) async {
      await env.nominalWeek();
      await showTab(tester, env);

      expect(find.text(distributionTitle), findsOneWidget);
      expect(find.text(tagsTitle), findsOneWidget);
      expect(find.text(writtenMention), findsOneWidget);
    });
  });

  group('marée de la semaine (CA24)', () {
    tideTest('CA24 : un seul libellé : « Humeur par jour : lundi Bien, mardi '
        'pas d\'entrée, … »', (tester, env) async {
      await env.nominalWeek();
      await showTab(tester, env);

      final label = tideLabel(nominalMoods);
      expect(
        label,
        "Humeur par jour : lundi Neutre, mardi Bas, mercredi pas d'entrée, "
        "jeudi Bien, vendredi pas d'entrée, samedi Neutre, dimanche Bien.",
      );
      expect(find.bySemanticsLabel(label), findsOneWidget);
      expect(
        semanticLabels(tester).where((l) => l.startsWith('Humeur par jour')),
        hasLength(1),
      );
    });

    tideTest('CA24 : une bulle de l\'humeur du jour pour chaque jour noté, '
        'dans l\'ordre des jours', (tester, env) async {
      await env.nominalWeek();
      await showTab(tester, env);

      expect([for (final b in tideBubbles(tester)) b.mood], [3, 2, 4, 3, 4]);
    });

    tideTest('CA24 : plus l\'humeur est haute, plus la bulle est haute ; deux '
        'jours de même humeur sont à la même hauteur', (tester, env) async {
      await env.nominalWeek();
      await showTab(tester, env);

      final bubbles = tideBubbles(tester);
      expect(bubbles, hasLength(5));
      double y(int i) => bubbles[i].rect.center.dy;
      // Lundi 3, mardi 2, jeudi 4, samedi 3, dimanche 4.
      expect(y(2), lessThan(y(0)), reason: 'jeudi (4) au-dessus de lundi (3)');
      expect(y(0), lessThan(y(1)), reason: 'lundi (3) au-dessus de mardi (2)');
      expect((y(0) - y(3)).abs(), lessThan(0.5), reason: 'lundi et samedi (3)');
      expect(
        (y(2) - y(4)).abs(),
        lessThan(0.5),
        reason: 'jeudi et dimanche (4)',
      );
    });

    tideTest('CA24 : un cercle pointillé pour chaque jour sans entrée', (
      tester,
      env,
    ) async {
      await env.nominalWeek();
      await showTab(tester, env);

      expect(tideDashedCircles(tester), 2);
    });

    tideTest('CA24 : les initiales des jours, de L à D, sous les bulles', (
      tester,
      env,
    ) async {
      await env.nominalWeek();
      await showTab(tester, env);

      final limit = bodyTop(tester);
      final initials = <({double x, double y, String letter})>[];
      for (final element in find.byType(Text).evaluate()) {
        final data = (element.widget as Text).data;
        if (data == null || data.length != 1 || !dayInitials.contains(data)) {
          continue;
        }
        final box = element.renderObject! as RenderBox;
        final at = box.localToGlobal(Offset.zero);
        if (at.dy + box.size.height <= limit) {
          initials.add((x: at.dx, y: at.dy, letter: data));
        }
      }
      initials.sort((a, b) => a.x.compareTo(b.x));
      expect([for (final i in initials) i.letter], dayInitials);
      final lowestBubble = tideBubbles(tester)
          .map((b) => b.rect.bottom)
          .reduce((a, b) => a > b ? a : b);
      for (final i in initials) {
        expect(i.y, greaterThan(lowestBubble - 1));
      }
    });

    tideTest('CA24 : l\'en-tête est sur sky, la mer sea et la bande sand '
        'sont dessinées', (tester, env) async {
      await env.nominalWeek();
      final key = GlobalKey();
      await showTab(tester, env, boundary: key);

      final pixels = await capture(tester, key);
      final limit = bodyTop(tester).round();
      expect(countColorAbove(pixels, light.sky, limit), greaterThan(2000));
      expect(countColorAbove(pixels, light.sea, limit), greaterThan(2000));
      expect(countColorAbove(pixels, light.sand, limit), greaterThan(300));
    });

    tideTest('CA24 : la surface de la mer passe par les bulles : à côté de '
        'chaque bulle, le haut de la mer est à hauteur de la bulle', (
      tester,
      env,
    ) async {
      await env.nominalWeek();
      final key = GlobalKey();
      await showTab(tester, env, boundary: key);
      final pixels = await capture(tester, key);

      expect(tideBubbles(tester), hasLength(5));
      for (final bubble in tideBubbles(tester)) {
        final x = (bubble.rect.right + 3).round();
        final top = firstInColumn(
          pixels,
          x,
          light.sea,
          0,
          bubble.rect.bottom.round() + 40,
        );
        expect(top, isNotNull, reason: 'mer à côté de la bulle ${bubble.mood}');
        expect(
          top!.toDouble(),
          inInclusiveRange(bubble.rect.top - 16, bubble.rect.bottom + 16),
          reason: 'surface à hauteur de la bulle ${bubble.mood}',
        );
      }
    });

    tideTest('CA24 : la scène est décorative : seul le libellé de la marée '
        'est annoncé, pas de soleil, de mouette ni de vague', (
      tester,
      env,
    ) async {
      await env.nominalWeek();
      await showTab(tester, env);

      expect(find.bySemanticsLabel(tideLabel(nominalMoods)), findsOneWidget);
      final labels = semanticLabels(tester).join(' | ').toLowerCase();
      for (final word in ['soleil', 'mouette', 'vague', 'nuage']) {
        expect(labels, isNot(contains(word)), reason: word);
      }
    });

    tideTest('CA24 : sans aucune entrée, la marée s\'affiche : sept « pas '
        'd\'entrée », sept cercles pointillés, aucune bulle', (
      tester,
      env,
    ) async {
      await showTab(tester, env);

      expect(
        find.bySemanticsLabel(tideLabel(List<int?>.filled(7, null))),
        findsOneWidget,
      );
      expect(find.text(insufficientTitle), findsOneWidget);
      expect(tideBubbles(tester), isEmpty);
      expect(tideDashedCircles(tester), 7);
    });

    tideTest('CA24 : avec 2 entrées (pas de bilan chiffré), la marée '
        's\'affiche quand même', (tester, env) async {
      await env.add(2, 4);
      await env.add(5, 1);
      await showTab(tester, env);

      expect(
        find.bySemanticsLabel(tideLabel([null, 4, null, null, 1, null, null])),
        findsOneWidget,
      );
      expect(find.text(insufficientTitle), findsOneWidget);
      expect([for (final b in tideBubbles(tester)) b.mood], [4, 1]);
      expect(tideDashedCircles(tester), 5);
    });

    tideTest('CA24 : avec 1 entrée', (tester, env) async {
      await env.add(7, 5);
      await showTab(tester, env);

      expect(
        find.bySemanticsLabel(
          tideLabel([null, null, null, null, null, null, 5]),
        ),
        findsOneWidget,
      );
      expect([for (final b in tideBubbles(tester)) b.mood], [5]);
    });

    tideTest('CA24 : la marée suit la semaine affichée', (tester, env) async {
      await env.nominalWeek();
      await env.add(3, 5, weeksBack: 1);
      await env.add(4, 1, weeksBack: 1);
      await showTab(tester, env);
      expect(find.bySemanticsLabel(tideLabel(nominalMoods)), findsOneWidget);

      await tapPreviousWeek(tester);

      expect(
        find.bySemanticsLabel(tideLabel([null, null, 5, 1, null, null, null])),
        findsOneWidget,
      );
      expect([for (final b in tideBubbles(tester)) b.mood], [5, 1]);
      await tapNextWeek(tester);
      expect(find.bySemanticsLabel(tideLabel(nominalMoods)), findsOneWidget);
    });

    tideTest('CA24 : une entrée en détresse ou non analysée est dessinée '
        'comme les autres', (tester, env) async {
      await env.add(1, 1, text: distressText, status: AnalysisStatus.skipped);
      await env.add(2, 3);
      await showTab(tester, env);

      expect(
        find.bySemanticsLabel(tideLabel([1, 3, null, null, null, null, null])),
        findsOneWidget,
      );
    });
  });

  group('autocollants (CA25)', () {
    tideTest('CA25 : « Humeur moyenne », « Jours notés » et « Entrées » '
        'viennent en tête du bilan, avant la répartition', (tester, env) async {
      await env.nominalWeek();
      await showTab(tester, env);

      final tops = [
        for (final label in ['Humeur moyenne', 'Jours notés', 'Entrées'])
          tester.getTopLeft(find.text(label)),
      ];
      final bubbleBottom = tideBubbles(tester)
          .map((b) => b.rect.bottom)
          .reduce((a, b) => a > b ? a : b);
      final distribution = tester.getTopLeft(find.text(distributionTitle)).dy;
      for (final top in tops) {
        expect(top.dy, greaterThan(bubbleBottom));
        expect(top.dy, lessThan(distribution));
      }
      // Ordre de lecture : moyenne, jours notés, entrées.
      final ordered = [...tops]
        ..sort(
          (a, b) => a.dy != b.dy ? a.dy.compareTo(b.dy) : a.dx.compareTo(b.dx),
        );
      expect(ordered, tops);
    });

    tideTest('CA25 : les valeurs sont celles de WeeklyReviewCalculator', (
      tester,
      env,
    ) async {
      await env.nominalWeek();
      await showTab(tester, env);
      final review = calculated(env);
      final tenths = review.averageMoodTenths;
      final average = '${tenths ~/ 10},${tenths % 10}';
      expect(average, '3,6');

      bool hasNumber(String text, Object value) =>
          RegExp('(^|\\D)$value(\\D|\$)').hasMatch(text);
      expect(stickerText(tester, 'Humeur moyenne'), contains(average));
      expect(
        hasNumber(stickerText(tester, 'Jours notés'), review.notedDays.length),
        isTrue,
        reason: stickerText(tester, 'Jours notés'),
      );
      expect(
        hasNumber(stickerText(tester, 'Entrées'), review.entryCount),
        isTrue,
        reason: stickerText(tester, 'Entrées'),
      );
    });

    tideTest('CA25 : autre semaine, autres valeurs (humeurs 3, 4, 3, 4 : '
        '3,5 ; 4 entrées ; 4 jours)', (tester, env) async {
      await env.moods([3, 4, 3, 4]);
      await showTab(tester, env);

      expect(stickerText(tester, 'Humeur moyenne'), contains('3,5'));
      expect(stickerText(tester, 'Entrées'), contains('4'));
      expect(stickerText(tester, 'Jours notés'), contains('4'));
    });

    tideTest('CA25 : chaque autocollant a une légère rotation de 3° au plus, '
        'fixe d\'un affichage à l\'autre', (tester, env) async {
      await env.nominalWeek();
      await showTab(tester, env);
      const labels = ['Humeur moyenne', 'Jours notés', 'Entrées'];
      for (final l in labels) {
        stickerOf(tester, l);
      }
      final first = [
        for (final l in labels) rotationAbove(tester, find.text(l)),
      ];

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(tabScreen(env));
      await settle(tester);
      final second = [
        for (final l in labels) rotationAbove(tester, find.text(l)),
      ];

      const limit = 3 * 3.141592653589793 / 180 + 1e-9;
      for (final angle in [...first, ...second]) {
        expect(angle.abs(), lessThanOrEqualTo(limit));
      }
      expect(second, first);
      expect(
        first.any((angle) => angle.abs() > 1e-6),
        isTrue,
        reason: 'au moins un autocollant est légèrement pivoté',
      );
    });

    tideTest('CA25 : les sections de la spec 006 suivent, textes inchangés '
        '(répartition, étiquettes fréquentes, évolution, texte)', (
      tester,
      env,
    ) async {
      await env.nominalWeek();
      await env.moods([3, 3, 3, 3, 3], weeksBack: 1);
      await showTab(tester, env);

      stickerOf(tester, 'Entrées');
      final stickerBottom = tester.getBottomLeft(find.text('Entrées')).dy;
      for (final text in [distributionTitle, tagsTitle, evolutionTitle]) {
        expect(find.text(text), findsOneWidget, reason: text);
        expect(
          tester.getTopLeft(find.text(text)).dy,
          greaterThan(stickerBottom),
        );
      }
      expect(
        tester.getTopLeft(find.text(distributionTitle)).dy,
        lessThan(tester.getTopLeft(find.text(tagsTitle)).dy),
      );
      expect(find.text(validReviewText), findsOneWidget);
      expect(find.text(writtenMention), findsOneWidget);
    });

    tideTest('CA25 : avec moins de 3 entrées, pas d\'autocollants, mais le '
        'message de la spec 006 (CA6)', (tester, env) async {
      await env.add(1, 3);
      await env.add(2, 4);
      await showTab(tester, env);

      expect(find.text('Humeur moyenne'), findsNothing);
      expect(find.text(insufficientTitle), findsOneWidget);
      expect(find.text(insufficientBody(2)), findsOneWidget);
    });
  });

  group('texte à 200 % (CA27)', () {
    tideTest('CA27 : à 200 %, rien ne déborde ni n\'est tronqué, l\'écran '
        'défile', (tester, env) async {
      await env.nominalWeek();
      await showTab(tester, env, textScale: 2.0);

      expect(tester.takeException(), isNull);
      expectNoTruncatedText(
        tester,
        find.byType(WeeklyReviewScreen),
        'onglet Semaine 200 %',
      );
      for (final label in ['Ta semaine', 'Humeur moyenne', 'Entrées']) {
        final rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(0), reason: label);
        expect(rect.right, lessThanOrEqualTo(393), reason: label);
      }
      expect(find.bySemanticsLabel(tideLabel(nominalMoods)), findsOneWidget);
    }, tall: false);

    tideTest('CA27 : à 200 %, sans bilan (2 entrées), la marée ne déborde '
        'pas non plus', (tester, env) async {
      await env.add(2, 4);
      await env.add(5, 1);
      await showTab(tester, env, textScale: 2.0);

      expect(tester.takeException(), isNull);
      expect(
        find.bySemanticsLabel(tideLabel([null, 4, null, null, 1, null, null])),
        findsOneWidget,
      );
      expectNoTruncatedText(
        tester,
        find.byType(WeeklyReviewScreen),
        'marée 200 %',
      );
    }, tall: false);
  });

  group('thème sombre (CA28)', () {
    tideTest('CA28 : thème sombre, ciel, mer et sable prennent les valeurs '
        'sombres ; aucune valeur claire', (tester, env) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await env.nominalWeek();
      final key = GlobalKey();
      await showTab(tester, env, boundary: key);

      final pixels = await capture(tester, key);
      final limit = bodyTop(tester).round();
      expect(countColorAbove(pixels, dark.sky, limit), greaterThan(2000));
      expect(countColorAbove(pixels, dark.sea, limit), greaterThan(2000));
      expect(countColorAbove(pixels, dark.sand, limit), greaterThan(300));
      expect(countColorAbove(pixels, light.sky, limit), 0);
      expect(countColorAbove(pixels, light.sand, limit), 0);
      expect(countColor(pixels, dark.surface), greaterThan(2000));
    });
  });
}
