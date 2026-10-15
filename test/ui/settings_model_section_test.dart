// Réglages, section « Analyse sur le téléphone » (spec 003, CA10, CA23, CA24, CA29,
// CA30). Les textes font foi dans la maquette `Reglages.dc.html`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/model/model_state.dart';
import 'package:tidemark/ui/screens/model_download_screen.dart';
import 'package:tidemark/ui/screens/settings_screen.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';

import '../support/distress_harness.dart'
    show expectNoTruncatedText, paintedColors, settingsSection;
import '../support/fake_model_downloader.dart';
import '../support/fake_settings_repository.dart';
import '../support/model_texts.dart';
import '../support/ui_harness.dart';

/// Écran haut : toute la page est affichée sans défiler.
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<FakeModelDownloader> showSettings(
  WidgetTester tester,
  ModelState state, {
  double textScale = 1.0,
  bool tall = true,
}) async {
  if (tall) {
    useTallScreen(tester);
  } else {
    usePhoneScreen(tester);
  }
  final downloader = FakeModelDownloader(state);
  await tester.pumpWidget(
    testApp(
      SettingsScreen(
        settings: FakeSettingsRepository(),
        downloader: downloader,
      ),
      textScale: textScale,
    ),
  );
  await settle(tester);
  return downloader;
}

void expectAbsentRow() {
  expect(find.text(settingsModelSection), findsOneWidget);
  expect(find.text(settingsModelRow), findsOneWidget);
  expect(find.text(settingsAbsent), findsOneWidget);
  expect(find.text(settingsAbsentNote), findsOneWidget);
  expect(find.text(downloadButton), findsOneWidget);
  expect(find.text(settingsDownloading), findsNothing);
  expect(find.text(settingsSeeDownload), findsNothing);
  expect(find.text(settingsReady), findsNothing);
}

void main() {
  group('état du modèle (CA23)', () {
    testWidgets('CA23 : modèle absent, « Non téléchargé · 1,1 Go » et le '
        'bouton de téléchargement', (tester) async {
      await showSettings(tester, const ModelAbsent());

      expectAbsentRow();
    });

    testWidgets('CA23 : après un échec, la ligne montre toujours « Non '
        'téléchargé » et le bouton', (tester) async {
      await showSettings(
        tester,
        const ModelAbsent(failure: DownloadFailure.network),
      );

      expectAbsentRow();
    });

    testWidgets('CA23 : modèle en téléchargement, « Téléchargement : 28 % », '
        'une barre et « Voir le téléchargement »', (tester) async {
      await showSettings(tester, downloading28);

      expect(find.text(settingsModelSection), findsOneWidget);
      expect(find.text(settingsModelRow), findsOneWidget);
      expect(find.text(settingsDownloading), findsOneWidget);
      expect(find.text(settingsSeeDownload), findsOneWidget);
      expect(find.bySemanticsLabel(progressBarLabel), findsWidgets);
      expect(find.text(settingsAbsent), findsNothing);
      expect(find.text(settingsReady), findsNothing);
    });

    testWidgets('CA23 : modèle prêt, « Prêt · 1,1 Go sur ton téléphone »', (
      tester,
    ) async {
      await showSettings(tester, ready);

      expect(find.text(settingsModelSection), findsOneWidget);
      expect(find.text(settingsModelRow), findsOneWidget);
      expect(find.text(settingsReady), findsOneWidget);
      expect(find.text(settingsReadyNote), findsOneWidget);
      expect(find.text(settingsAbsent), findsNothing);
      expect(find.text(settingsDownloading), findsNothing);
      expect(find.text(downloadButton), findsNothing);
      expect(find.text(settingsSeeDownload), findsNothing);
    });

    testWidgets('CA23 : la section est au-dessus de la section « Écran '
        'd\'aide », qui reste affichée', (tester) async {
      await showSettings(tester, const ModelAbsent());

      final model = tester.getTopLeft(find.text(settingsModelSection)).dy;
      final help = tester.getTopLeft(find.text(settingsSection)).dy;
      expect(model, lessThan(help));
      expect(tester.getTopLeft(find.text(settingsModelRow)).dy, lessThan(help));
      expect(tester.getTopLeft(find.text(downloadButton)).dy, lessThan(help));
    });

    testWidgets('CA23 : l\'état se met à jour sans quitter l\'écran : absent, '
        'téléchargement, prêt', (tester) async {
      final downloader = await showSettings(tester, const ModelAbsent());
      expectAbsentRow();

      downloader.emit(downloading28);
      await settle(tester);
      expect(find.text(settingsDownloading), findsOneWidget);
      expect(find.text(settingsAbsent), findsNothing);
      expect(find.text(downloadButton), findsNothing);

      downloader.emit(
        const ModelDownloading(
          receivedBytes: 559000000,
          totalBytes: totalBytes,
        ),
      );
      await settle(tester);
      expect(find.text('Téléchargement : 50 %'), findsOneWidget);

      downloader.emit(ready);
      await settle(tester);
      expect(find.text(settingsReady), findsOneWidget);
      expect(find.text(settingsDownloading), findsNothing);
      expect(find.text('Téléchargement : 50 %'), findsNothing);
    });

    testWidgets('CA23 : un échec ou une annulation en cours ramène la ligne à '
        '« Non téléchargé »', (tester) async {
      final downloader = await showSettings(tester, downloading28);

      downloader.emit(const ModelAbsent(failure: DownloadFailure.checksum));
      await settle(tester);

      expectAbsentRow();
    });

    testWidgets('CA23 : un modèle supprimé repasse à « Non téléchargé »', (
      tester,
    ) async {
      final downloader = await showSettings(tester, ready);

      downloader.emit(const ModelAbsent());
      await settle(tester);

      expectAbsentRow();
    });
  });

  group('pas de second téléchargement (CA10)', () {
    testWidgets('CA10 : en téléchargement, aucun bouton de téléchargement', (
      tester,
    ) async {
      await showSettings(tester, downloading28);

      expect(find.text(downloadButton), findsNothing);
      expect(find.text(retryButton), findsNothing);
    });

    testWidgets('CA10 : pendant la vérification, aucun bouton de '
        'téléchargement', (tester) async {
      await showSettings(tester, verifying);

      expect(find.text(downloadButton), findsNothing);
      expect(find.text(settingsAbsent), findsNothing);
    });

    testWidgets('CA10 : pour un modèle prêt, aucun bouton de téléchargement', (
      tester,
    ) async {
      await showSettings(tester, ready);

      expect(find.text(downloadButton), findsNothing);
    });
  });

  group('ouverture de l\'écran du modèle (CA24)', () {
    testWidgets('CA24 : « Télécharger le modèle (1,1 Go) » ouvre la '
        'proposition, sans lancer le téléchargement', (tester) async {
      final downloader = await showSettings(tester, const ModelAbsent());

      await tester.tap(find.text(downloadButton));
      await settle(tester);

      expect(find.byType(ModelDownloadScreen), findsOneWidget);
      expect(find.text(offerTitle), findsOneWidget);
      expect(downloader.startCalls, 0);
      expect(downloader.current, isA<ModelAbsent>());
    });

    testWidgets('CA24 : la proposition ouverte depuis les Réglages ramène aux '
        'Réglages avec « Plus tard »', (tester) async {
      await showSettings(tester, const ModelAbsent());
      await tester.tap(find.text(downloadButton));
      await settle(tester);

      await tester.tap(find.text(later));
      await settle(tester);

      expect(find.byType(ModelDownloadScreen), findsNothing);
      expect(find.text(settingsModelSection), findsOneWidget);
    });

    testWidgets('CA24 : après un échec, le bouton ouvre la proposition', (
      tester,
    ) async {
      final downloader = await showSettings(
        tester,
        const ModelAbsent(failure: DownloadFailure.network),
      );

      await tester.tap(find.text(downloadButton));
      await settle(tester);

      expect(find.byType(ModelDownloadScreen), findsOneWidget);
      expect(downloader.startCalls, 0);
    });

    testWidgets('CA24 : « Voir le téléchargement » ouvre la progression', (
      tester,
    ) async {
      final downloader = await showSettings(tester, downloading28);

      await tester.tap(find.text(settingsSeeDownload));
      await settle(tester);

      expect(find.byType(ModelDownloadScreen), findsOneWidget);
      expect(find.text(modelTitle), findsOneWidget);
      expect(find.text(progressPercent), findsOneWidget);
      expect(find.text(cancelButton), findsOneWidget);
      expect(downloader.startCalls, 0);
      expect(downloader.current, isA<ModelDownloading>());
    });

    testWidgets('CA24 : la progression ouverte depuis les Réglages continue '
        'de se mettre à jour', (tester) async {
      final downloader = await showSettings(tester, downloading28);
      await tester.tap(find.text(settingsSeeDownload));
      await settle(tester);

      downloader.emit(
        const ModelDownloading(
          receivedBytes: 559000000,
          totalBytes: totalBytes,
        ),
      );
      await settle(tester);

      expect(find.text('50 %'), findsOneWidget);
    });
  });

  group('texte du système à 200 % (CA29)', () {
    final states = <String, ModelState>{
      'absent': const ModelAbsent(),
      'téléchargement': downloading28,
      'prêt': ready,
    };

    for (final MapEntry(key: name, value: state) in states.entries) {
      testWidgets('CA29 : $name, aucun texte tronqué ni débordement', (
        tester,
      ) async {
        await showSettings(tester, state, textScale: 2.0, tall: false);

        expect(find.text(settingsModelSection), findsOneWidget);
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(
          tester,
          find.byType(SettingsScreen),
          'réglages à 200 %, modèle $name',
        );
        expect(find.byType(Scrollable), findsWidgets);
      });
    }

    testWidgets('CA29 : absent, le bouton reste atteignable et ouvre la '
        'proposition', (tester) async {
      await showSettings(
        tester,
        const ModelAbsent(),
        textScale: 2.0,
        tall: false,
      );

      await tester.ensureVisible(find.text(downloadButton));
      await tester.pump();
      await tester.tap(find.text(downloadButton));
      await settle(tester);

      expect(find.text(offerTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CA29 : en téléchargement, « Voir le téléchargement » reste '
        'atteignable', (tester) async {
      await showSettings(tester, downloading28, textScale: 2.0, tall: false);

      await tester.ensureVisible(find.text(settingsSeeDownload));
      await tester.pump();
      await tester.tap(find.text(settingsSeeDownload));
      await settle(tester);

      expect(find.text(progressPercent), findsOneWidget);
    });
  });

  group('thème sombre (CA30)', () {
    final states = <String, ModelState>{
      'absent': const ModelAbsent(),
      'téléchargement': downloading28,
      'prêt': ready,
    };

    for (final MapEntry(key: name, value: state) in states.entries) {
      testWidgets('CA30 : $name, les couleurs suivent la charte sombre', (
        tester,
      ) async {
        useDarkSystem(tester);
        await showSettings(tester, state);

        final background = tester
            .widget<Material>(
              find
                  .descendant(
                    of: find.byType(SettingsScreen),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .color;
        expect(background, TidemarkColors.dark.surface);
        final colors = paintedColors(tester, find.byType(SettingsScreen));
        expect(colors, contains(TidemarkColors.dark.ink));
        expect(colors, contains(TidemarkColors.dark.inkMuted));
        expect(colors, contains(TidemarkColors.dark.tide));
        expect(colors, isNot(contains(TidemarkColors.light.surface)));
        expect(colors, isNot(contains(TidemarkColors.light.ink)));
        expect(colors, isNot(contains(TidemarkColors.light.inkMuted)));
        expect(colors, isNot(contains(TidemarkColors.light.tide)));
      });
    }
  });
}
