// Spec 007 : logo dans l'état vide de la liste (CA4, CA5, CA7).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/ui/screens/entry_list_screen.dart';
import 'package:tidemark/ui/widgets/tidemark_logo.dart';

import '../support/fake_model_downloader.dart';
import '../support/fake_settings_repository.dart';
import '../support/ui_harness.dart';

Widget listScreen(DbEnv env) => testApp(
  EntryListScreen(
    repository: env.repo,
    settings: FakeSettingsRepository(),
    clock: () => env.now,
    downloader: FakeModelDownloader(readyModel),
  ),
);

const emptyTitle = 'Ta première entrée apparaîtra ici';

void useBrightness(WidgetTester tester, Brightness brightness) {
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

void main() {
  for (final brightness in Brightness.values) {
    group('thème ${brightness.name}', () {
      dbTestWidgets('CA4 : état vide, un logo de 64 points au-dessus de '
          '« Ta première entrée apparaîtra ici »', (tester, env) async {
        useBrightness(tester, brightness);
        await tester.pumpWidget(listScreen(env));
        await settle(tester);

        final logo = find.byType(TidemarkLogo);
        expect(logo, findsOneWidget);
        expect(tester.getSize(logo), const Size(64, 64));
        expect(
          tester.getBottomLeft(logo).dy,
          lessThanOrEqualTo(tester.getTopLeft(find.text(emptyTitle)).dy),
          reason: 'le logo est au-dessus du texte',
        );
      });

      dbTestWidgets('CA4 : le titre « Ton journal » et l\'icône « Réglages » '
          'sont toujours là', (tester, env) async {
        useBrightness(tester, brightness);
        await tester.pumpWidget(listScreen(env));
        await settle(tester);

        expect(find.text('Ton journal'), findsOneWidget);
        expect(find.bySemanticsLabel('Réglages'), findsWidgets);
        expect(find.text(emptyTitle), findsOneWidget);
      });
    });
  }

  dbTestWidgets('CA7 : avec au moins une entrée, aucun logo', (
    tester,
    env,
  ) async {
    await env.seedJournal(tester);
    await tester.pumpWidget(listScreen(env));
    await settle(tester);

    expect(find.byType(TidemarkLogo), findsNothing);
  });

  dbTestWidgets('CA7 : pendant le chargement, aucun logo', (tester, env) async {
    await tester.pumpWidget(listScreen(env));
    // Premier cadre : le flux n'a pas encore émis.
    expect(find.text(emptyTitle), findsNothing);
    expect(find.byType(TidemarkLogo), findsNothing);
    await settle(tester);
  });

  dbTestWidgets(
    'CA5 : le logo n\'est pas annoncé, aucun libellé « Tidemark »',
    (tester, env) async {
      await tester.pumpWidget(listScreen(env));
      await settle(tester);

      expect(find.byType(TidemarkLogo), findsOneWidget);
      expect(find.bySemanticsLabel('Tidemark'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('logo', caseSensitive: false)),
        findsNothing,
      );
    },
  );

  dbTestWidgets('Cas limite : texte à 200 %, le logo garde sa taille', (
    tester,
    env,
  ) async {
    await tester.pumpWidget(
      testApp(
        EntryListScreen(
          repository: env.repo,
          settings: FakeSettingsRepository(),
          clock: () => env.now,
          downloader: FakeModelDownloader(readyModel),
        ),
        textScale: 2.0,
      ),
    );
    await settle(tester);

    expect(tester.getSize(find.byType(TidemarkLogo)), const Size(64, 64));
    expect(tester.takeException(), isNull);
  });
}
