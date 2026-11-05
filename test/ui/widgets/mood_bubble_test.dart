// Bulle de marée (spec 008, CA5 à CA7) : niveau d'eau, visage, sémantique,
// assertion sur l'humeur. Les pixels sont lus sur une capture : le test ne dépend
// pas de la façon dont la bulle est dessinée.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';
import 'package:tidemark/ui/widgets/mood_bubble.dart';

import '../../support/playful_harness.dart';
import '../../support/ui_harness.dart';

const levels = [0.17, 0.32, 0.48, 0.64, 0.79];
const margin = 8.0;

/// Une bulle de [size] au centre, dans une marge où le flottement pourrait déborder.
Future<Pixels> render(
  WidgetTester tester,
  int mood, {
  double size = 150,
  bool dark = false,
}) async {
  usePhoneScreen(tester);
  if (dark) useDarkPlatform(tester);
  final key = GlobalKey();
  await tester.pumpWidget(
    ambientApp(
      Center(
        child: RepaintBoundary(
          key: key,
          child: Padding(
            padding: const EdgeInsets.all(margin),
            child: MoodBubble(mood: mood, size: size),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  return capture(tester, key);
}

void main() {
  group('niveau d\'eau (CA5)', () {
    test('CA5 : waterLevel rend 17, 32, 48, 64 et 79 % du diamètre', () {
      for (var mood = 1; mood <= 5; mood++) {
        expect(
          MoodBubble.waterLevel(mood),
          closeTo(levels[mood - 1], 0.01),
          reason: 'humeur $mood',
        );
      }
    });

    test('CA5 : les niveaux sont strictement croissants', () {
      for (var mood = 2; mood <= 5; mood++) {
        expect(
          MoodBubble.waterLevel(mood),
          greaterThan(MoodBubble.waterLevel(mood - 1)),
        );
      }
    });

    for (var mood = 1; mood <= 5; mood++) {
      testWidgets('CA5 : humeur $mood, l\'eau dessinée monte à '
          '${(levels[mood - 1] * 100).round()} % du disque', (tester) async {
        const size = 150.0;
        final pixels = await render(tester, mood);
        final water = TidemarkColors.light.moodColor(mood);

        final top = topmost(pixels, water);

        expect(top, isNotNull, reason: 'aucun pixel d\'eau mood-$mood');
        final drawn = (margin + size - top!) / size;
        expect(drawn, closeTo(levels[mood - 1], 0.04));
      });

      testWidgets('CA5 : humeur $mood, le disque est rempli de mood-$mood-soft '
          'au-dessus de l\'eau', (tester) async {
        final pixels = await render(tester, mood);

        expect(
          countColor(pixels, TidemarkColors.light.moodSoftColor(mood)),
          greaterThan(500),
        );
      });
    }

    testWidgets('CA5 : plus l\'humeur est haute, plus il y a d\'eau', (
      tester,
    ) async {
      final counts = <int>[];
      for (var mood = 1; mood <= 5; mood++) {
        final pixels = await render(tester, mood);
        counts.add(countColor(pixels, TidemarkColors.light.moodColor(mood)));
      }
      for (var i = 1; i < counts.length; i++) {
        expect(counts[i], greaterThan(counts[i - 1]), reason: '$counts');
      }
    });
  });

  group('visage (CA5)', () {
    test('CA5 : cinq visages distincts, dans l\'ordre de la spec', () {
      final faces = [for (var m = 1; m <= 5; m++) MoodBubble.faceFor(m)];
      expect(faces, [
        BubbleFace.tearful,
        BubbleFace.low,
        BubbleFace.flat,
        BubbleFace.smile,
        BubbleFace.beaming,
      ]);
      expect(faces.toSet(), hasLength(5));
    });

    testWidgets('CA5 : un visage en on-mood est dessiné pour chaque humeur', (
      tester,
    ) async {
      for (var mood = 1; mood <= 5; mood++) {
        final pixels = await render(tester, mood);
        expect(
          countColor(pixels, TidemarkColors.light.onMood),
          greaterThan(20),
          reason: 'humeur $mood',
        );
      }
    });

    testWidgets(
      'CA5 : la larme bubble-tear n\'est dessinée que pour l\'humeur 1',
      (tester) async {
        final tear = TidemarkColors.light.bubbleTear;
        expect(countColor(await render(tester, 1), tear), greaterThan(5));
        for (var mood = 2; mood <= 5; mood++) {
          expect(
            countColor(await render(tester, mood), tear),
            0,
            reason: '$mood',
          );
        }
      },
    );

    testWidgets('CA5 : les joues bubble-cheek ne sont dessinées que pour les '
        'humeurs 4 et 5', (tester) async {
      final cheek = TidemarkColors.light.bubbleCheek;
      for (var mood = 1; mood <= 3; mood++) {
        expect(
          countColor(await render(tester, mood), cheek),
          0,
          reason: '$mood',
        );
      }
      for (var mood = 4; mood <= 5; mood++) {
        expect(
          countColor(await render(tester, mood), cheek),
          greaterThan(5),
          reason: '$mood',
        );
      }
    });

    testWidgets('CA5 : un reflet bubble-shine est dessiné sur chaque bulle', (
      tester,
    ) async {
      for (var mood = 1; mood <= 5; mood++) {
        expect(
          countColor(
            await render(tester, mood),
            TidemarkColors.light.bubbleShine,
          ),
          greaterThan(3),
          reason: 'humeur $mood',
        );
      }
    });
  });

  group('couleurs identiques dans les deux thèmes', () {
    for (var mood = 1; mood <= 5; mood++) {
      testWidgets('humeur $mood : la bulle est la même en clair et en sombre', (
        tester,
      ) async {
        final light = await render(tester, mood);
        await tester.pumpWidget(const SizedBox());
        final dark = await render(tester, mood, dark: true);

        expect(dark.bytes, light.bytes);
      });
    }
  });

  group('sémantique (CA6)', () {
    testWidgets('CA6 : la bulle n\'est pas annoncée, seule la sémantique du '
        'parent l\'est', (tester) async {
      usePhoneScreen(tester);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ambientApp(
          Center(
            child: Semantics(
              container: true,
              label: 'Humeur 4 sur 5 : Bien',
              child: const MoodBubble(mood: 4, size: 48),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final node = tester.getSemantics(
        find.bySemanticsLabel('Humeur 4 sur 5 : Bien'),
      );
      final labelled = <SemanticsNode>[];
      void visit(SemanticsNode n) {
        final data = n.getSemanticsData();
        if (data.label.isNotEmpty || data.value.isNotEmpty) labelled.add(n);
        n.visitChildren((c) {
          visit(c);
          return true;
        });
      }

      visit(
        tester
            .binding
            .renderViews
            .first
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!,
      );

      expect(labelled, [node], reason: 'seul le parent porte un texte');
      var children = 0;
      node.visitChildren((_) {
        children++;
        return true;
      });
      expect(children, 0, reason: 'la bulle ne crée aucun nœud');
      semantics.dispose();
    });

    testWidgets('CA6 : seule la bulle, sans parent, ne crée aucun nœud '
        'annoncé', (tester) async {
      usePhoneScreen(tester);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ambientApp(const Center(child: MoodBubble(mood: 2, size: 120))),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final labelled = <SemanticsNode>[];
      void visit(SemanticsNode n) {
        final data = n.getSemanticsData();
        if (data.label.isNotEmpty ||
            data.value.isNotEmpty ||
            data.hasAction(SemanticsAction.tap)) {
          labelled.add(n);
        }
        n.visitChildren((c) {
          visit(c);
          return true;
        });
      }

      visit(
        tester
            .binding
            .renderViews
            .first
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!,
      );
      expect(labelled, isEmpty);
      semantics.dispose();
    });
  });

  group('humeur hors de 1 à 5 (CA7)', () {
    for (final mood in [0, 6, -1, 10]) {
      testWidgets('CA7 : l\'humeur $mood lève une erreur d\'assertion', (
        tester,
      ) async {
        usePhoneScreen(tester);
        Object? error;
        try {
          await tester.pumpWidget(
            ambientApp(Center(child: MoodBubble(mood: mood, size: 48))),
          );
        } catch (e) {
          error = e;
        }
        error ??= tester.takeException();

        expect(error, isA<AssertionError>());
      });
    }
  });
}
