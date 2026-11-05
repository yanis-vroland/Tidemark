// L'écran d'aide reste calme (spec 008, CA14 ; spec 002) : aucune bulle, aucun
// autocollant pivoté, aucune animation d'ambiance, même avec AmbientMotion activé.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/ui/screens/help_screen.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';
import 'package:tidemark/ui/widgets/mood_bubble.dart';

import 'package:tidemark/main.dart';

import '../support/distress_harness.dart';
import '../support/fake_model_downloader.dart';
import '../support/fake_phone_dialer.dart';
import '../support/playful_harness.dart';
import '../support/ui_harness.dart';

Future<void> showHelp(
  WidgetTester tester, {
  bool ambient = true,
  bool reduceMotion = false,
}) async {
  usePhoneScreen(tester);
  await tester.pumpWidget(
    ambientApp(
      HelpScreen(dialer: FakePhoneDialer()),
      ambient: ambient,
      reduceMotion: reduceMotion,
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('CA14 : avec AmbientMotion activé, aucune bulle de marée', (
    tester,
  ) async {
    await showHelp(tester);

    expect(find.byType(HelpScreen), findsOneWidget);
    expect(find.byType(MoodBubble), findsNothing);
  });

  testWidgets('CA14 : avec AmbientMotion activé, aucune animation ne tourne, '
      'même après plusieurs secondes', (tester) async {
    await showHelp(tester);
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pump(const Duration(seconds: 5));

    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('CA14 : aucun élément pivoté dans l\'écran d\'aide', (
    tester,
  ) async {
    await showHelp(tester);

    final transforms = tester.widgetList<Transform>(
      find.descendant(
        of: find.byType(HelpScreen),
        matching: find.byType(Transform),
      ),
    );
    for (final t in transforms) {
      final m = t.transform.storage;
      expect(
        math.atan2(m[1], m[0]).abs(),
        lessThan(1e-9),
        reason: 'rotation non nulle',
      );
    }
    expect(
      find.descendant(
        of: find.byType(HelpScreen),
        matching: find.byType(RotationTransition),
      ),
      findsNothing,
    );
  });

  testWidgets('CA14 : l\'écran d\'aide est identique avec et sans '
      'AmbientMotion (mêmes textes, même fond)', (tester) async {
    await showHelp(tester, ambient: false);
    final withoutMotion = allTextsOfScreen(tester, HelpScreen);
    final background = scaffoldColor(tester, find.text('3114'));
    await tester.pumpWidget(const SizedBox());

    await showHelp(tester, ambient: true);

    expect(allTextsOfScreen(tester, HelpScreen), withoutMotion);
    expect(scaffoldColor(tester, find.text('3114')), background);
  });

  testWidgets('CA14 : seuls les jetons de fond et de texte v2 s\'appliquent '
      '(clair)', (tester) async {
    await showHelp(tester);

    expect(
      scaffoldColor(tester, find.text('3114')),
      TidemarkColors.light.surface,
    );
    expect(
      paintedTextColor(tester, find.text('Parler peut aider')),
      TidemarkColors.light.ink,
    );
  });

  testWidgets('CA14, CA19 : même écran en sombre, aux valeurs sombres', (
    tester,
  ) async {
    useDarkPlatform(tester);
    await showHelp(tester);

    expect(
      scaffoldColor(tester, find.text('3114')),
      TidemarkColors.dark.surface,
    );
    expect(
      paintedTextColor(tester, find.text('Parler peut aider')),
      TidemarkColors.dark.ink,
    );
    expect(find.byType(MoodBubble), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('CA14 : atteint depuis la saisie sous AmbientMotion, l\'écran '
      'd\'aide reste calme', (tester) async {
    usePhoneScreen(tester);
    final env = GuardEnv();
    await tester.pumpWidget(
      TidemarkApp(
        repository: env.repo,
        settings: env.settings,
        dialer: env.dialer,
        clock: () => env.now,
        downloader: FakeModelDownloader(readyModel),
        ambientMotion: true,
      ),
    );
    await settle(tester);

    await env.enterEntry(tester, fixedNow, 3, 'J’ai envie de mourir.');

    expect(find.text(helpTitle), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.hasRunningAnimations, isFalse);
    expect(
      find.descendant(
        of: find.byType(HelpScreen),
        matching: find.byType(MoodBubble),
      ),
      findsNothing,
    );
  });
}
