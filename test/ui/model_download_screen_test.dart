// Écran du modèle (spec 003, CA4, CA5, CA7, CA9 à CA15, CA17 à CA20, CA28 à CA30) :
// les cinq états, sur `FakeModelDownloader`. Les textes font foi dans la maquette
// docs/maquettes/003-telechargement-du-modele/.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/model/model_state.dart';
import 'package:tidemark/ui/screens/model_download_screen.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';

import '../support/distress_harness.dart'
    show allTextsOfScreen, expectNoTruncatedText, paintedColors;
import '../support/fake_model_downloader.dart';
import '../support/model_texts.dart';
import '../support/ui_harness.dart';

Future<FakeModelDownloader> open(
  WidgetTester tester,
  ModelState state, {
  double textScale = 1.0,
}) async {
  usePhoneScreen(tester);
  final downloader = FakeModelDownloader(state);
  await showModelScreen(tester, downloader, textScale: textScale);
  return downloader;
}

void expectTexts(WidgetTester tester, List<String> expected) {
  expect(
    allTextsOfScreen(tester, ModelDownloadScreen),
    unorderedEquals(expected),
  );
}

void expectBackHome(WidgetTester tester) {
  expect(find.text(homeMarker), findsOneWidget);
  expect(find.byType(ModelDownloadScreen), findsNothing);
}

void main() {
  group('proposition (CA4, CA5, CA7)', () {
    testWidgets('CA4 : la proposition montre exactement les textes de la '
        'maquette, rien d\'autre', (tester) async {
      await open(tester, const ModelAbsent());

      // Spec 008, CA15 : les textes de la spec 003, plus les quatre autocollants
      // d'étiquettes fictives de l'illustration décorative.
      final texts = allTextsOfScreen(tester, ModelDownloadScreen);
      expect(texts, containsAll(offerTexts));
      expect(texts, hasLength(offerTexts.length + 4));
    });

    testWidgets('CA4 : la taille « 1,1 Go » est dans le texte et dans le '
        'bouton', (tester) async {
      await open(tester, const ModelAbsent());

      expect(find.text(offerSizeTitle), findsOneWidget);
      expect(find.text(downloadButton), findsOneWidget);
      expect(find.textContaining('1,1 Go'), findsNWidgets(3));
    });

    testWidgets('CA4 : les deux boutons s\'annoncent comme des boutons', (
      tester,
    ) async {
      await open(tester, const ModelAbsent());

      for (final label in [downloadButton, later]) {
        final node = tester.getSemantics(find.text(label));
        expect(node.flagsCollection.isButton, isTrue, reason: label);
      }
    });

    testWidgets('CA7 : à l\'ouverture, aucun téléchargement n\'est lancé '
        '(RM11)', (tester) async {
      final downloader = await open(tester, const ModelAbsent());

      expect(downloader.startCalls, 0);
      expect(downloader.cancelCalls, 0);
    });

    testWidgets('CA5 : « Plus tard » ramène à l\'écran précédent, le modèle '
        'reste absent, rien n\'est lancé', (tester) async {
      final downloader = await open(tester, const ModelAbsent());

      await tester.tap(find.text(later));
      await settle(tester);

      expectBackHome(tester);
      expect(downloader.startCalls, 0);
      expect(downloader.cancelCalls, 0);
      expect(downloader.current, isA<ModelAbsent>());
    });

    testWidgets('CA5 : un geste de retour fait de même', (tester) async {
      final downloader = await open(tester, const ModelAbsent());

      await tester.binding.handlePopRoute();
      await settle(tester);

      expectBackHome(tester);
      expect(downloader.startCalls, 0);
      expect(downloader.current, isA<ModelAbsent>());
    });

    testWidgets('CA7 : « Télécharger le modèle (1,1 Go) » lance le '
        'téléchargement et l\'écran passe à la progression', (tester) async {
      final downloader = await open(tester, const ModelAbsent());

      await tester.tap(find.text(downloadButton));
      await settle(tester);

      expect(downloader.startCalls, greaterThanOrEqualTo(1));
      expect(downloader.current, isA<ModelDownloading>());
      expect(find.text(downloadButton), findsNothing);
      expect(find.text(cancelButton), findsOneWidget);
      expect(find.text('0 %'), findsOneWidget);
    });
  });

  group('progression (CA9 à CA13)', () {
    testWidgets('CA9 : la progression montre exactement les textes de la '
        'maquette : 28 %, 312 Mo sur 1,1 Go', (tester) async {
      await open(tester, downloading28);

      expectTexts(tester, progressTexts);
    });

    testWidgets('CA9 : le pourcentage et les mégaoctets sont arrondis à '
        'l\'inférieur', (tester) async {
      // 99 999 999 sur 1 117 320 736 : 8,95 % et 99,99 Mo.
      await open(
        tester,
        const ModelDownloading(receivedBytes: 99999999, totalBytes: totalBytes),
      );

      expect(find.text('8 %'), findsOneWidget);
      expect(find.text('99 Mo sur 1,1 Go'), findsOneWidget);
    });

    testWidgets('CA9 : le début du transfert s\'affiche à 0 %', (tester) async {
      await open(
        tester,
        const ModelDownloading(receivedBytes: 0, totalBytes: totalBytes),
      );

      expect(find.text('0 %'), findsOneWidget);
      expect(find.text('0 Mo sur 1,1 Go'), findsOneWidget);
    });

    testWidgets('CA9 : l\'affichage suit chaque nouvel état, sans quitter '
        'l\'écran', (tester) async {
      final downloader = await open(tester, downloading28);

      downloader.emit(
        const ModelDownloading(
          receivedBytes: 559000000,
          totalBytes: totalBytes,
        ),
      );
      await settle(tester);
      expect(find.text('50 %'), findsOneWidget);
      expect(find.text('559 Mo sur 1,1 Go'), findsOneWidget);
      expect(find.text(progressPercent), findsNothing);

      downloader.emit(
        const ModelDownloading(
          receivedBytes: 570200000,
          totalBytes: totalBytes,
        ),
      );
      await settle(tester);
      expect(find.text('51 %'), findsOneWidget);
      expect(find.text('570 Mo sur 1,1 Go'), findsOneWidget);
    });

    testWidgets('CA9 : la barre de progression suit le pourcentage', (
      tester,
    ) async {
      final downloader = await open(tester, downloading28);
      expect(find.bySemanticsLabel(progressBarLabel), findsWidgets);

      downloader.emit(
        const ModelDownloading(
          receivedBytes: 559000000,
          totalBytes: totalBytes,
        ),
      );
      await settle(tester);

      expect(
        find.bySemanticsLabel('Téléchargement du modèle, 50 %'),
        findsWidgets,
      );
      expect(find.bySemanticsLabel(progressBarLabel), findsNothing);
    });

    testWidgets('CA10 : pendant le téléchargement, l\'écran ne propose aucun '
        'bouton de téléchargement', (tester) async {
      await open(tester, downloading28);

      expect(find.text(downloadButton), findsNothing);
      expect(find.text(retryButton), findsNothing);
    });

    testWidgets('CA11 : « Revenir à mon journal » ramène à l\'écran '
        'précédent, le téléchargement continue', (tester) async {
      final downloader = await open(tester, downloading28);

      await tester.tap(find.text(backToJournalButton));
      await settle(tester);

      expectBackHome(tester);
      expect(downloader.cancelCalls, 0);
      expect(downloader.current, isA<ModelDownloading>());
    });

    testWidgets('CA11 : un geste de retour fait de même, sans annuler', (
      tester,
    ) async {
      final downloader = await open(tester, downloading28);

      await tester.binding.handlePopRoute();
      await settle(tester);

      expectBackHome(tester);
      expect(downloader.cancelCalls, 0);
      expect(downloader.current, isA<ModelDownloading>());
    });

    testWidgets('CA12 : « Annuler le téléchargement » demande confirmation, '
        'sans rien annuler encore', (tester) async {
      final downloader = await open(tester, downloading28);

      await tester.tap(find.text(cancelButton));
      await settle(tester);

      expect(find.text(confirmTitle), findsOneWidget);
      expect(find.text(confirmBody), findsOneWidget);
      expect(find.text(cancelButton), findsNWidgets(2));
      expect(find.text(confirmKeep), findsOneWidget);
      expect(downloader.cancelCalls, 0);
      expect(downloader.current, isA<ModelDownloading>());
    });

    testWidgets('CA12 : « Continuer » ferme la confirmation, le '
        'téléchargement continue', (tester) async {
      final downloader = await open(tester, downloading28);
      await tester.tap(find.text(cancelButton));
      await settle(tester);

      await tester.tap(find.text(confirmKeep));
      await settle(tester);

      expect(find.text(confirmTitle), findsNothing);
      expect(find.text(confirmBody), findsNothing);
      expect(find.text(progressPercent), findsOneWidget);
      expect(find.text(cancelButton), findsOneWidget);
      expect(downloader.cancelCalls, 0);
      expect(downloader.current, isA<ModelDownloading>());
    });

    testWidgets('CA12 : la progression continue de s\'afficher sous la '
        'confirmation', (tester) async {
      final downloader = await open(tester, downloading28);
      await tester.tap(find.text(cancelButton));
      await settle(tester);

      downloader.emit(
        const ModelDownloading(
          receivedBytes: 559000000,
          totalBytes: totalBytes,
        ),
      );
      await settle(tester);
      await tester.tap(find.text(confirmKeep));
      await settle(tester);

      expect(find.text('50 %'), findsOneWidget);
    });

    testWidgets('CA13 : confirmer l\'annulation annule une fois, le modèle '
        'repasse à « absent » et la liste s\'affiche', (tester) async {
      final downloader = await open(tester, downloading28);
      await tester.tap(find.text(cancelButton));
      await settle(tester);

      await tester.tap(find.text(cancelButton).last);
      await settle(tester);

      expect(downloader.cancelCalls, 1);
      expect(downloader.current, isA<ModelAbsent>());
      expectBackHome(tester);
      expect(find.text(confirmTitle), findsNothing);
    });
  });

  group('vérification et prêt (CA14)', () {
    testWidgets('CA14 : la vérification montre exactement les textes de la '
        'maquette, sans bouton d\'annulation', (tester) async {
      await open(tester, verifying);

      expectTexts(tester, verifyingTexts);
      expect(find.text(cancelButton), findsNothing);
      expect(find.text(progressAdvice), findsNothing);
    });

    testWidgets('CA14 : de la progression à la vérification, puis à « Prêt »', (
      tester,
    ) async {
      final downloader = await open(tester, downloading28);

      downloader.emit(verifying);
      await settle(tester);
      expect(find.text(verifyingText), findsOneWidget);
      expect(find.text(cancelButton), findsNothing);

      downloader.emit(ready);
      await settle(tester);
      expectTexts(tester, readyTexts);
      expect(find.text(verifyingText), findsNothing);
    });

    testWidgets('CA14 : « Prêt » montre exactement les textes de la maquette', (
      tester,
    ) async {
      await open(tester, ready);

      expectTexts(tester, readyTexts);
    });

    testWidgets('CA14 : « Revenir à mon journal » depuis « Prêt » ramène à '
        'l\'écran précédent', (tester) async {
      await open(tester, ready);

      await tester.tap(find.text(backToJournalButton));
      await settle(tester);

      expectBackHome(tester);
    });

    testWidgets('CA14 : « Revenir à mon journal » pendant la vérification '
        'ramène à l\'écran précédent sans annuler', (tester) async {
      final downloader = await open(tester, verifying);

      await tester.tap(find.text(backToJournalButton));
      await settle(tester);

      expectBackHome(tester);
      expect(downloader.cancelCalls, 0);
    });
  });

  group('échecs (CA15, CA17 à CA20)', () {
    for (final failure in DownloadFailure.values) {
      testWidgets(
        'CA19 : échec $failure, exactement le bandeau de la maquette, '
        'la phrase « Rien n\'a été gardé » et les deux boutons',
        (tester) async {
          await open(tester, ModelAbsent(failure: failure));

          expectTexts(tester, failureTexts(failure));
        },
      );

      testWidgets('CA19 : échec $failure, titre en danger, phrase en ink', (
        tester,
      ) async {
        await open(tester, ModelAbsent(failure: failure));
        final (title, body) = failures[failure]!;

        expect(colorOfText(tester, title), TidemarkColors.light.danger);
        expect(colorOfText(tester, body), TidemarkColors.light.ink);
      });
    }

    testWidgets('CA15 : l\'échec « fichier faux » s\'affiche quand le '
        'téléchargement se termine mal', (tester) async {
      final downloader = await open(tester, verifying);

      downloader.emit(const ModelAbsent(failure: DownloadFailure.checksum));
      await settle(tester);

      expect(find.text(failChecksumTitle), findsOneWidget);
      expect(find.text(verifyingText), findsNothing);
    });

    testWidgets('CA17 : l\'échec « réseau » s\'affiche quand la connexion '
        'échoue en cours de route', (tester) async {
      final downloader = await open(tester, downloading28);

      downloader.emit(const ModelAbsent(failure: DownloadFailure.network));
      await settle(tester);

      expect(find.text(failNetworkTitle), findsOneWidget);
      expect(find.text(progressPercent), findsNothing);
    });

    testWidgets('CA18 : l\'échec « place » s\'affiche quand l\'écriture '
        'échoue', (tester) async {
      final downloader = await open(tester, downloading28);

      downloader.emit(const ModelAbsent(failure: DownloadFailure.storage));
      await settle(tester);

      expect(find.text(failStorageTitle), findsOneWidget);
    });

    testWidgets('CA20 : « Réessayer (1,1 Go) » relance le téléchargement et '
        'l\'écran repasse à la progression', (tester) async {
      final downloader = await open(
        tester,
        const ModelAbsent(failure: DownloadFailure.network),
      );

      await tester.tap(find.text(retryButton));
      await settle(tester);

      expect(downloader.startCalls, greaterThanOrEqualTo(1));
      expect(downloader.current, isA<ModelDownloading>());
      expect(find.text(failNetworkTitle), findsNothing);
      expect(find.text(cancelButton), findsOneWidget);
    });

    testWidgets('CA20 : « Plus tard » ramène à l\'écran précédent, sans '
        'relancer', (tester) async {
      final downloader = await open(
        tester,
        const ModelAbsent(failure: DownloadFailure.checksum),
      );

      await tester.tap(find.text(later));
      await settle(tester);

      expectBackHome(tester);
      expect(downloader.startCalls, 0);
    });

    testWidgets('CA20 : un geste de retour ramène à l\'écran précédent, sans '
        'relancer', (tester) async {
      final downloader = await open(
        tester,
        const ModelAbsent(failure: DownloadFailure.storage),
      );

      await tester.binding.handlePopRoute();
      await settle(tester);

      expectBackHome(tester);
      expect(downloader.startCalls, 0);
    });

    testWidgets('CA19 : un modèle absent sans échec récent montre la '
        'proposition, pas un bandeau d\'erreur', (tester) async {
      await open(tester, const ModelAbsent());

      expect(find.text(offerTitle), findsOneWidget);
      expect(find.text(failNothingKept), findsNothing);
    });
  });

  group('accessibilité (CA28)', () {
    testWidgets('CA28 : la barre s\'annonce « Téléchargement du modèle, '
        '28 % »', (tester) async {
      await open(tester, downloading28);

      expect(find.bySemanticsLabel(progressBarLabel), findsWidgets);
    });

    testWidgets('CA28 : la vérification est annoncée (status)', (tester) async {
      await open(tester, verifying);

      expect(isAnnounced(tester, find.text(verifyingText)), isTrue);
    });

    testWidgets('CA28 : « Le modèle est prêt » est annoncé (status)', (
      tester,
    ) async {
      await open(tester, ready);

      expect(isAnnounced(tester, find.text(readyTitle)), isTrue);
    });

    for (final failure in DownloadFailure.values) {
      testWidgets('CA28 : l\'échec $failure est annoncé (alert)', (
        tester,
      ) async {
        await open(tester, ModelAbsent(failure: failure));

        expect(
          isAnnounced(tester, find.text(failures[failure]!.$1), alert: true),
          isTrue,
        );
      });
    }

    testWidgets('CA28 : le titre est le premier texte lu', (tester) async {
      await open(tester, downloading28);

      expect(readingOrderOf(tester).first, modelTitle);
    });

    testWidgets('CA28 : les boutons s\'annoncent comme des boutons', (
      tester,
    ) async {
      await open(tester, downloading28);

      for (final label in [cancelButton, backToJournalButton]) {
        final node = tester.getSemantics(find.text(label));
        expect(node.flagsCollection.isButton, isTrue, reason: label);
      }
    });
  });

  group('texte du système à 200 % (CA29)', () {
    final states = <String, ModelState>{
      'proposition': const ModelAbsent(),
      'progression': downloading28,
      'vérification': verifying,
      'échec réseau': const ModelAbsent(failure: DownloadFailure.network),
      'échec fichier faux': const ModelAbsent(
        failure: DownloadFailure.checksum,
      ),
      'échec place': const ModelAbsent(failure: DownloadFailure.storage),
      'prêt': ready,
    };

    for (final MapEntry(key: name, value: state) in states.entries) {
      testWidgets('CA29 : $name, aucun texte tronqué ni débordement', (
        tester,
      ) async {
        await open(tester, state, textScale: 2.0);

        expect(tester.takeException(), isNull);
        expectNoTruncatedText(
          tester,
          find.byType(ModelDownloadScreen),
          '$name à 200 %',
        );
        expect(find.byType(Scrollable), findsWidgets);
      });
    }

    testWidgets('CA29 : proposition, les boutons restent atteignables en '
        'défilant', (tester) async {
      final downloader = await open(
        tester,
        const ModelAbsent(),
        textScale: 2.0,
      );

      await tester.scrollUntilVisible(find.text(downloadButton), 100);
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(
        tester.getCenter(find.text(downloadButton)).dy,
        inInclusiveRange(0, size.height),
      );
      await tester.tap(find.text(downloadButton));
      await settle(tester);

      expect(downloader.startCalls, greaterThanOrEqualTo(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('CA29 : proposition, « Plus tard » reste atteignable', (
      tester,
    ) async {
      await open(tester, const ModelAbsent(), textScale: 2.0);

      await tester.scrollUntilVisible(find.text(later), 100);
      await tester.tap(find.text(later));
      await settle(tester);

      expectBackHome(tester);
    });

    testWidgets('CA29 : progression, les deux boutons restent atteignables', (
      tester,
    ) async {
      await open(tester, downloading28, textScale: 2.0);

      for (final label in [cancelButton, backToJournalButton]) {
        await tester.scrollUntilVisible(find.text(label), 100);
        final size = tester.view.physicalSize / tester.view.devicePixelRatio;
        expect(
          tester.getCenter(find.text(label)).dy,
          inInclusiveRange(0, size.height),
          reason: label,
        );
      }
    });

    testWidgets('CA29 : échec, « Réessayer » et « Plus tard » restent '
        'atteignables', (tester) async {
      final downloader = await open(
        tester,
        const ModelAbsent(failure: DownloadFailure.network),
        textScale: 2.0,
      );

      await tester.ensureVisible(find.text(retryButton));
      await tester.pump();
      await tester.tap(find.text(retryButton));
      await settle(tester);

      expect(downloader.startCalls, greaterThanOrEqualTo(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('CA29 : la confirmation d\'annulation ne déborde pas et ses '
        'deux boutons restent atteignables', (tester) async {
      await open(tester, downloading28, textScale: 2.0);
      await tester.scrollUntilVisible(find.text(cancelButton), 100);
      await tester.tap(find.text(cancelButton));
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(confirmTitle), findsOneWidget);
      await tester.ensureVisible(find.text(confirmKeep));
      await tester.pump();
      await tester.tap(find.text(confirmKeep));
      await settle(tester);

      expect(find.text(confirmTitle), findsNothing);
    });

    testWidgets('CA29 : prêt, « Revenir à mon journal » reste atteignable', (
      tester,
    ) async {
      await open(tester, ready, textScale: 2.0);

      await tester.scrollUntilVisible(find.text(backToJournalButton), 100);
      await tester.tap(find.text(backToJournalButton));
      await settle(tester);

      expectBackHome(tester);
    });
  });

  group('thème sombre (CA30)', () {
    final states = <String, ModelState>{
      'proposition': const ModelAbsent(),
      'progression': downloading28,
      'vérification': verifying,
      'échec': const ModelAbsent(failure: DownloadFailure.network),
      'prêt': ready,
    };

    for (final MapEntry(key: name, value: state) in states.entries) {
      testWidgets('CA30 : $name, le fond et les couleurs suivent la charte '
          'sombre', (tester) async {
        useDarkSystem(tester);
        await open(tester, state);

        final scaffold = find.descendant(
          of: find.byType(ModelDownloadScreen),
          matching: find.byType(Scaffold),
        );
        final background = tester
            .widget<Material>(
              find
                  .descendant(
                    of: scaffold.first,
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .color;
        expect(background, TidemarkColors.dark.surface);
        final colors = paintedColors(tester, find.byType(ModelDownloadScreen));
        expect(colors, contains(TidemarkColors.dark.ink));
        expect(colors, contains(TidemarkColors.dark.tide));
        expect(colors, isNot(contains(TidemarkColors.light.surface)));
        // `ink` clair vaut `on-mood`, texte des autocollants de l'illustration
        // dans les deux thèmes (spec 008, CA15) : il n'est plus interdit ici.
        expect(colors, isNot(contains(TidemarkColors.light.tide)));
        expect(colors, isNot(contains(TidemarkColors.light.danger)));
      });
    }

    testWidgets('CA30 : échec, le titre est en danger sombre', (tester) async {
      useDarkSystem(tester);
      await open(tester, const ModelAbsent(failure: DownloadFailure.network));

      expect(colorOfText(tester, failNetworkTitle), TidemarkColors.dark.danger);
    });

    testWidgets('CA30 : thème clair, le fond suit la charte claire', (
      tester,
    ) async {
      await open(tester, const ModelAbsent());

      final scaffold = find.descendant(
        of: find.byType(ModelDownloadScreen),
        matching: find.byType(Scaffold),
      );
      final background = tester
          .widget<Material>(
            find
                .descendant(of: scaffold.first, matching: find.byType(Material))
                .first,
          )
          .color;
      expect(background, TidemarkColors.light.surface);
    });
  });
}

/// Étiquettes non vides lues par un lecteur d'écran, dans l'ordre de parcours.
List<String> readingOrderOf(WidgetTester tester) => tester.semantics
    .simulatedAccessibilityTraversal()
    .map((node) => node.label)
    .where((label) => label.isNotEmpty)
    .toList();
