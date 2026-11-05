// Écran de bienvenue (spec 009, CA1, CA2, CA5, CA27, CA28), vu par `TidemarkApp` avec
// `showWelcome: true` : le constructeur de `WelcomeScreen` n'est pas figé par la spec.
// Dépôt et réglages factices, aucune base.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/ui/screens/home_shell.dart';
import 'package:tidemark/ui/screens/welcome_screen.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';
import 'package:tidemark/ui/widgets/tidemark_logo.dart';

import '../support/distress_harness.dart' show expectNoTruncatedText;
import '../support/fake_entry_repository.dart';
import '../support/home_harness.dart';
import '../support/playful_harness.dart';
import '../support/ui_harness.dart';

const startLabel = "C'est parti";
const steps = [
  'Choisis une bulle, ajoute un mot si tu veux.',
  'Ramasse un coquillage à chaque entrée.',
  'Regarde ta semaine monter et descendre.',
];
const privacy = 'Rien ne quitte ton téléphone.';

HomeEnv env() => HomeEnv(FakeEntryRepository(clock: () => fixedNow));

Future<void> showWelcome(WidgetTester tester, HomeEnv env) async {
  await tester.pumpWidget(env.fullApp(showWelcome: true));
  await settle(tester);
}

void main() {
  group('contenu (CA1)', () {
    homeTest('CA1 : le logo, « Tidemark », le titre, les trois étapes, la '
        'mention et « C\'est parti »', (tester) async {
      await showWelcome(tester, env());

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(TidemarkLogo), findsOneWidget);
      expect(find.text('Tidemark'), findsOneWidget);
      expect(find.text(checkInDay), findsOneWidget);
      for (final step in steps) {
        expect(find.text(step), findsOneWidget, reason: step);
      }
      expect(find.text(privacy), findsOneWidget);
      expect(find.text(startLabel), findsOneWidget);
    });

    homeTest('CA1 : le titre « Comment va ta marée aujourd\'hui ? » est fixe, '
        'même le soir', (tester) async {
      final e = env()..now = eveningNow;
      await showWelcome(tester, e);

      expect(find.text(checkInDay), findsOneWidget);
      expect(find.text(checkInEvening), findsNothing);
    });

    homeTest('CA1 : les trois étapes se lisent dans l\'ordre, de haut en '
        'bas', (tester) async {
      await showWelcome(tester, env());

      final tops = [
        tester.getTopLeft(find.text(checkInDay)).dy,
        for (final step in steps) tester.getTopLeft(find.text(step)).dy,
        tester.getTopLeft(find.text(privacy)).dy,
        tester.getTopLeft(find.text(startLabel)).dy,
      ];
      expect(tops, [...tops]..sort());
      expect(tops.toSet(), hasLength(tops.length));
    });

    homeTest('CA1 : la bienvenue remplace le journal : ni liste, ni barre de '
        'navigation', (tester) async {
      await showWelcome(tester, env());

      expect(find.byType(HomeShell), findsNothing);
      expect(find.text('Ton journal'), findsNothing);
      expect(find.text('Nouvelle entrée'), findsNothing);
      expect(find.text(emptyJournalTitle), findsNothing);
    });

    homeTest('CA1 : « C\'est parti » est annoncé comme un bouton', (
      tester,
    ) async {
      await showWelcome(tester, env());

      expect(isButtonNode(tester, find.bySemanticsLabel(startLabel)), isTrue);
    });

    homeTest('CA1 : sans showWelcome, le journal s\'affiche d\'emblée', (
      tester,
    ) async {
      final e = env();
      await tester.pumpWidget(e.fullApp());
      await settle(tester);

      expect(find.byType(WelcomeScreen), findsNothing);
      expect(find.byType(HomeShell), findsOneWidget);
    });
  });

  group('« C\'est parti » (CA2, CA5)', () {
    homeTest('CA2 : le réglage « bienvenue vue » passe à vrai et l\'accueil du '
        'journal s\'affiche', (tester) async {
      final e = env();
      await showWelcome(tester, e);
      expect(e.settings.welcomeShown, isFalse);

      await tester.tap(find.text(startLabel));
      await settle(tester);

      expect(e.settings.welcomeShown, isTrue);
      expect(e.settings.setWelcomeShownCalls, 1);
      expect(find.byType(WelcomeScreen), findsNothing);
      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.text('Ton journal'), findsOneWidget);
      expect(find.text('Nouvelle entrée'), findsOneWidget);
    });

    homeTest('CA2 : la bienvenue n\'est pas réaffichée en revenant sur '
        'l\'accueil (barre, Réglages)', (tester) async {
      final e = env();
      await showWelcome(tester, e);
      await tester.tap(find.text(startLabel));
      await settle(tester);

      await openTab(tester, 'Semaine');
      await openTab(tester, 'Journal');

      expect(find.byType(WelcomeScreen), findsNothing);
      expect(e.settings.setWelcomeShownCalls, 1);
    });

    homeTest('CA5 : erreur à l\'écriture du réglage, l\'accueil s\'affiche '
        'quand même, sans message', (tester) async {
      final e = env();
      e.settings.welcomeWriteError = StateError('écriture impossible');
      await showWelcome(tester, e);

      await tester.tap(find.text(startLabel));
      await settle(tester);

      expect(e.settings.setWelcomeShownCalls, 1);
      expect(e.settings.welcomeShown, isFalse);
      expect(find.byType(WelcomeScreen), findsNothing);
      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.text('Ton journal'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(MaterialBanner), findsNothing);
      expect(find.textContaining('erreur'), findsNothing);
      expect(find.textContaining('Réessaie'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('texte à 200 % (CA27)', () {
    homeTest(
      'CA27 : rien n\'est tronqué ni ne déborde, l\'écran défile jusqu\'à '
      '« C\'est parti »',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        useScreen(tester, tall: false);

        await showWelcome(tester, env());

        expect(tester.takeException(), isNull);
        expectNoTruncatedText(
          tester,
          find.byType(WelcomeScreen),
          'bienvenue 200 %',
        );
        await tester.scrollUntilVisible(
          find.text(startLabel),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(startLabel), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      tall: false,
    );

    // Non-régression (revue IA de la PR #49) : la pastille du numéro avait une
    // taille fixe de 40 ; à 200 %, le chiffre en débordait.
    for (final scale in [1.0, 2.0]) {
      homeTest('CA27 : à ${(scale * 100).round()} %, chaque numéro d\'étape '
          'tient dans sa pastille ronde, d\'au moins 40 de côté', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await showWelcome(tester, env());

        for (final number in ['1', '2', '3']) {
          final text = find.descendant(
            of: find.byType(WelcomeScreen),
            matching: find.text(number),
          );
          expect(text, findsOneWidget, reason: 'numéro $number');
          final badge = find
              .ancestor(
                of: text,
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is DecoratedBox &&
                      w.decoration is BoxDecoration &&
                      (w.decoration as BoxDecoration).shape == BoxShape.circle,
                ),
              )
              .first;
          // Taille du texte mis en page sans contrainte : une boîte trop petite
          // rogne la taille rendue du RenderParagraph, pas le dessin du chiffre.
          final paragraph = tester.renderObject<RenderParagraph>(text);
          final textSize = paragraph.getDryLayout(const BoxConstraints());
          final textRect = Rect.fromCenter(
            center: tester.getCenter(text),
            width: textSize.width,
            height: textSize.height,
          );
          final badgeRect = tester.getRect(badge);
          expect(
            badgeRect.width,
            closeTo(badgeRect.height, 0.01),
            reason: 'pastille $number ronde',
          );
          expect(
            badgeRect.width,
            greaterThanOrEqualTo(40),
            reason: 'pastille $number',
          );
          if (scale == 1.0) {
            expect(badgeRect.size, const Size.square(40), reason: 'à 100 %');
          }
          expect(
            badgeRect.inflate(0.01).contains(textRect.topLeft) &&
                badgeRect.inflate(0.01).contains(textRect.bottomRight),
            isTrue,
            reason: 'numéro $number ($textRect) dans sa pastille ($badgeRect)',
          );
        }
      });
    }
  });

  group('thème (CA28)', () {
    for (final brightness in Brightness.values) {
      homeTest('CA28 : thème ${brightness.name}, le ciel et le texte prennent '
          'les valeurs ${brightness.name} des jetons', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final colors = brightness == Brightness.dark
            ? TidemarkColors.dark
            : TidemarkColors.light;
        final other = brightness == Brightness.dark
            ? TidemarkColors.light
            : TidemarkColors.dark;
        final key = GlobalKey();
        await tester.pumpWidget(
          ambientApp(
            RepaintBoundary(key: key, child: env().fullApp(showWelcome: true)),
          ),
        );
        await settle(tester);

        expect(
          Theme.of(tester.element(find.byType(WelcomeScreen))).brightness,
          brightness,
        );
        final pixels = await capture(tester, key);
        expect(countColor(pixels, colors.sky), greaterThan(500));
        expect(countColor(pixels, other.sky), 0);
      });
    }
  });
}
