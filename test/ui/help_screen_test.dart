// Écran d'aide (spec 002, CA10 à CA13, CA23, CA25, CA26) : texte fixe, jamais généré.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/ui/screens/help_screen.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';

import '../support/distress_harness.dart';
import '../support/fake_phone_dialer.dart';
import '../support/ui_harness.dart';

const nominalTexts = [
  helpTitle,
  helpIntro,
  '3114',
  'Numéro national de prévention du suicide',
  'Gratuit, 24 h/24, 7 j/7',
  call3114,
  'Danger immédiat ?',
  "Appelle le 112, le numéro d'urgence européen.",
  call112,
  backToJournal,
];

Future<void> showHelp(
  WidgetTester tester,
  FakePhoneDialer dialer, {
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    testApp(HelpScreen(dialer: dialer), textScale: textScale),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void useDarkSystem(WidgetTester tester) {
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

void main() {
  group('texte (CA10)', () {
    testWidgets('CA10 : l\'écran montre exactement les textes de la maquette, '
        'rien d\'autre', (tester) async {
      usePhoneScreen(tester);
      await showHelp(tester, FakePhoneDialer());

      final texts = allTextsOfScreen(tester, HelpScreen);

      expect(texts, unorderedEquals(nominalTexts));
    });

    testWidgets('CA10 : le titre, le 3114 et ses mentions s\'affichent', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await showHelp(tester, FakePhoneDialer());

      expect(find.text('Parler peut aider'), findsOneWidget);
      expect(find.text(helpIntro), findsOneWidget);
      expect(find.text('3114'), findsOneWidget);
      expect(
        find.text('Numéro national de prévention du suicide'),
        findsOneWidget,
      );
      expect(find.text('Gratuit, 24 h/24, 7 j/7'), findsOneWidget);
    });

    testWidgets('CA10 : les trois boutons s\'affichent', (tester) async {
      usePhoneScreen(tester);
      await showHelp(tester, FakePhoneDialer());

      expect(find.text('Appeler le 3114'), findsOneWidget);
      expect(find.text('Appeler le 112'), findsOneWidget);
      expect(find.text('Revenir à mon journal'), findsOneWidget);
    });

    testWidgets(
      'CA10 : sans appel en échec, la mention d\'appel impossible est '
      'absente',
      (tester) async {
        usePhoneScreen(tester);
        await showHelp(tester, FakePhoneDialer());

        expect(find.text(helpTitle), findsOneWidget);
        expect(find.text(dialFailedTitle), findsNothing);
        expect(find.text(dialFailedBody), findsNothing);
      },
    );
  });

  group('appel (CA11, CA12)', () {
    testWidgets('CA11 : « Appeler le 3114 » ouvre le composeur sur le 3114', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final dialer = FakePhoneDialer();
      await showHelp(tester, dialer);

      await tester.tap(find.text('Appeler le 3114'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(dialer.dialed, ['3114']);
      expect(find.text(dialFailedTitle), findsNothing);
    });

    testWidgets('CA11 : « Appeler le 112 » ouvre le composeur sur le 112', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final dialer = FakePhoneDialer();
      await showHelp(tester, dialer);

      await tester.tap(find.text('Appeler le 112'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(dialer.dialed, ['112']);
      expect(find.text(dialFailedTitle), findsNothing);
    });

    testWidgets('CA11 : rien n\'est composé tant qu\'on ne touche pas un '
        'bouton', (tester) async {
      usePhoneScreen(tester);
      final dialer = FakePhoneDialer();
      await showHelp(tester, dialer);
      await tester.pump(const Duration(seconds: 2));

      expect(find.text(call3114), findsOneWidget);
      expect(dialer.dialed, isEmpty);
    });

    testWidgets('CA11 : après l\'appel, l\'écran d\'aide est toujours affiché '
        'et rien n\'a changé', (tester) async {
      usePhoneScreen(tester);
      await showHelp(tester, FakePhoneDialer());

      await tester.tap(find.text('Appeler le 3114'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        allTextsOfScreen(tester, HelpScreen),
        unorderedEquals(nominalTexts),
      );
    });

    for (final (label, number) in [(call3114, '3114'), (call112, '112')]) {
      testWidgets('CA12 : $label, composeur indisponible (faux) : la mention '
          's\'affiche', (tester) async {
        usePhoneScreen(tester);
        final dialer = FakePhoneDialer(succeeds: false);
        await showHelp(tester, dialer);

        await tester.tap(find.text(label));
        await tester.pump(const Duration(milliseconds: 400));

        expect(dialer.dialed, [number]);
        expect(find.text(dialFailedTitle), findsOneWidget);
        expect(find.text(dialFailedBody), findsOneWidget);
      });

      testWidgets('CA12 : $label, composeur en exception : la mention '
          's\'affiche', (tester) async {
        usePhoneScreen(tester);
        final dialer = FakePhoneDialer(error: StateError('pas de téléphonie'));
        await showHelp(tester, dialer);

        await tester.tap(find.text(label));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text(dialFailedTitle), findsOneWidget);
        expect(find.text(dialFailedBody), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('CA12 : après l\'échec, les numéros et les boutons restent '
        'affichés', (tester) async {
      usePhoneScreen(tester);
      await showHelp(tester, FakePhoneDialer(succeeds: false));

      await tester.tap(find.text('Appeler le 3114'));
      await tester.pump(const Duration(milliseconds: 400));

      for (final text in nominalTexts) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
    });
  });

  group('accessibilité (CA23)', () {
    testWidgets('CA23 : le titre est annoncé en premier', (tester) async {
      usePhoneScreen(tester);
      await showHelp(tester, FakePhoneDialer());

      expect(readingOrder(tester).first, helpTitle);
    });

    testWidgets(
      'CA23 : les boutons s\'annoncent « Appeler le 3114 » et « Appeler '
      'le 112 »',
      (tester) async {
        usePhoneScreen(tester);
        await showHelp(tester, FakePhoneDialer());

        for (final label in [call3114, call112]) {
          final node = tester.getSemantics(find.text(label));
          expect(node.label, label);
          expect(node.flagsCollection.isButton, isTrue, reason: label);
        }
      },
    );

    testWidgets('CA23 : « Revenir à mon journal » s\'annonce comme un '
        'bouton', (tester) async {
      usePhoneScreen(tester);
      await showHelp(tester, FakePhoneDialer());

      final node = tester.getSemantics(find.text(backToJournal));

      expect(node.flagsCollection.isButton, isTrue);
    });

    testWidgets('CA23 : le numéro affiché s\'annonce chiffre par chiffre', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await showHelp(tester, FakePhoneDialer());

      final labels = readingOrder(tester);

      expect(
        labels.any((l) => l.contains('3 1 1 4')),
        isTrue,
        reason: '$labels',
      );
      expect(find.bySemanticsLabel(RegExp('3 1 1 4')), findsWidgets);
    });

    testWidgets('CA23 : l\'ordre de lecture suit l\'écran : titre, 3114, 112, '
        'retour', (tester) async {
      usePhoneScreen(tester);
      await showHelp(tester, FakePhoneDialer());

      final labels = readingOrder(tester);
      int at(String part) => labels.indexWhere((l) => l.contains(part));

      expect(at(helpTitle), 0);
      expect(at(call3114), greaterThan(at(helpTitle)));
      expect(at(call112), greaterThan(at(call3114)));
      expect(at(backToJournal), greaterThan(at(call112)));
    });
  });

  group('texte du système à 200 % (CA25)', () {
    testWidgets('CA25 : l\'écran d\'aide ne déborde pas et n\'a aucun texte '
        'tronqué', (tester) async {
      usePhoneScreen(tester);
      await showHelp(tester, FakePhoneDialer(), textScale: 2.0);

      expect(find.text(helpTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
      expectNoTruncatedText(tester, find.byType(HelpScreen), 'aide à 200 %');
    });

    testWidgets('CA25 : l\'écran d\'aide défile et tous ses boutons restent '
        'atteignables', (tester) async {
      usePhoneScreen(tester);
      final dialer = FakePhoneDialer();
      await showHelp(tester, dialer, textScale: 2.0);

      expect(find.byType(Scrollable), findsWidgets);
      for (final label in [call3114, call112, backToJournal]) {
        await tester.scrollUntilVisible(find.text(label), 100);
        final center = tester.getCenter(find.text(label));
        final size = tester.view.physicalSize / tester.view.devicePixelRatio;
        expect(center.dy, inInclusiveRange(0, size.height), reason: label);
      }
      await tester.ensureVisible(find.text(call112));
      await tester.pump();
      await tester.tap(find.text(call112));
      await tester.pump(const Duration(milliseconds: 400));
      expect(dialer.dialed, ['112']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CA25 : avec la mention d\'appel impossible, rien ne déborde', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await showHelp(tester, FakePhoneDialer(succeeds: false), textScale: 2.0);
      await tester.tap(find.text(call3114));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(dialFailedBody), findsOneWidget);
      expect(tester.takeException(), isNull);
      expectNoTruncatedText(tester, find.byType(HelpScreen), 'aide en échec');
    });
  });

  group('thème (CA26)', () {
    testWidgets('CA26 : thème sombre, le fond et les textes suivent la charte '
        'sombre', (tester) async {
      usePhoneScreen(tester);
      useDarkSystem(tester);
      await showHelp(tester, FakePhoneDialer());

      final scaffold = find.ancestor(
        of: find.text(helpTitle),
        matching: find.byType(Scaffold),
      );
      final background = tester
          .widget<Material>(
            find
                .descendant(of: scaffold, matching: find.byType(Material))
                .first,
          )
          .color;
      expect(background, TidemarkColors.dark.surface);
      final colors = paintedColors(tester, find.byType(HelpScreen));
      expect(colors, contains(TidemarkColors.dark.ink));
      expect(colors, contains(TidemarkColors.dark.tide));
      expect(colors, isNot(contains(TidemarkColors.light.surface)));
      expect(colors, isNot(contains(TidemarkColors.light.ink)));
      expect(colors, isNot(contains(TidemarkColors.light.tide)));
    });

    testWidgets('CA26 : thème clair, le fond suit la charte claire', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await showHelp(tester, FakePhoneDialer());

      final colors = paintedColors(tester, find.byType(HelpScreen));

      expect(colors, contains(TidemarkColors.light.ink));
      expect(colors, contains(TidemarkColors.light.tide));
      expect(colors, isNot(contains(TidemarkColors.dark.ink)));
    });

    for (final brightness in Brightness.values) {
      final palette = brightness == Brightness.dark
          ? TidemarkColors.dark
          : TidemarkColors.light;

      testWidgets('CA26 : l\'écran d\'aide n\'utilise jamais la couleur '
          '`danger` ($brightness)', (tester) async {
        usePhoneScreen(tester);
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await showHelp(tester, FakePhoneDialer());

        final colors = paintedColors(tester, find.byType(HelpScreen));

        // Garde-fou du test : le collecteur voit bien les couleurs de la charte.
        expect(colors, contains(palette.ink));
        expect(colors, isNot(contains(palette.danger)));
      });

      testWidgets('CA26 : même avec la mention d\'appel impossible, l\'écran '
          'd\'aide n\'utilise jamais `danger` ($brightness)', (tester) async {
        usePhoneScreen(tester);
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await showHelp(tester, FakePhoneDialer(succeeds: false));
        await tester.tap(find.text(call3114));
        await tester.pump(const Duration(milliseconds: 400));

        final colors = paintedColors(tester, find.byType(HelpScreen));

        expect(find.text(dialFailedTitle), findsOneWidget);
        expect(colors, contains(palette.tideSoft));
        expect(colors, isNot(contains(palette.danger)));
        expect(colors, isNot(contains(TidemarkColors.light.danger)));
        expect(colors, isNot(contains(TidemarkColors.dark.danger)));
      });
    }
  });
}
