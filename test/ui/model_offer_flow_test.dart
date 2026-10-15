// Parcours de l'application autour du modèle (spec 003, CA1 à CA3, CA5, CA6, CA11,
// CA13, CA21) : saisie, proposition, liste, Réglages. L'application entière sur des
// faux : aucun réseau.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/main.dart';
import 'package:tidemark/model/model_downloader.dart';
import 'package:tidemark/model/model_state.dart';
import 'package:tidemark/ui/screens/model_download_screen.dart';

import '../support/distress_harness.dart' show backToJournal, helpTitle;
import '../support/fake_entry_repository.dart';
import '../support/fake_model_downloader.dart';
import '../support/fake_model_transport.dart';
import '../support/fake_phone_dialer.dart';
import '../support/fake_settings_repository.dart';
import '../support/model_fixtures.dart';
import '../support/model_texts.dart';
import '../support/ui_harness.dart';

const calmText = 'Journée calme au bord de l\'eau.';
const neutralText = 'Rien de spécial aujourd\'hui.';

class OfferEnv {
  OfferEnv({ModelState? model, ModelDownloader? downloader})
    : downloader =
          downloader ?? FakeModelDownloader(model ?? const ModelAbsent()),
      settings = FakeSettingsRepository() {
    repo = FakeEntryRepository(clock: () => now);
  }

  late final FakeEntryRepository repo;
  final FakeSettingsRepository settings;
  final ModelDownloader downloader;
  final FakePhoneDialer dialer = FakePhoneDialer();
  DateTime now = fixedNow;

  FakeModelDownloader get fake => downloader as FakeModelDownloader;

  Widget app() => TidemarkApp(
    repository: repo,
    settings: settings,
    dialer: dialer,
    clock: () => now,
    downloader: downloader,
  );

  /// Saisit une entrée par l'interface : humeur, texte éventuel, « Enregistrer ».
  Future<void> save(WidgetTester tester, int mood, [String? text]) async {
    await openForm(tester);
    await pickMood(tester, mood);
    if (text != null) {
      await tester.enterText(textInput, text);
      await tester.pump();
    }
    await tester.tap(find.text('Enregistrer'));
    await settle(tester);
  }

  /// Deux humeurs « Très bas » récentes : une troisième ouvre l'écran d'aide.
  void seedSeries() {
    repo.seed(mood: 1, createdAt: DateTime(2026, 10, 8, 20));
    repo.seed(mood: 1, createdAt: DateTime(2026, 10, 12, 20));
  }
}

Future<OfferEnv> start(
  WidgetTester tester, {
  ModelState? model,
  bool offerShown = false,
  ModelDownloader? downloader,
}) async {
  usePhoneScreen(tester);
  final env = OfferEnv(model: model, downloader: downloader);
  env.settings.modelOfferShown = offerShown;
  await tester.pumpWidget(env.app());
  await settle(tester);
  return env;
}

void expectOfferShown(WidgetTester tester) {
  expect(find.byType(ModelDownloadScreen), findsOneWidget);
  expect(find.text(offerTitle), findsOneWidget);
  expect(find.text(downloadButton), findsOneWidget);
}

void expectNoOffer(WidgetTester tester) {
  expect(find.byType(ModelDownloadScreen), findsNothing);
  expect(find.text(offerTitle), findsNothing);
}

void expectListShown(WidgetTester tester) {
  expect(find.text('Ton journal'), findsOneWidget);
  expect(find.text('Nouvelle entrée'), findsOneWidget);
}

void main() {
  group(
    'la proposition s\'ouvre après la première entrée en attente (CA1)',
    () {
      testWidgets(
        'CA1 : modèle absent, proposition jamais affichée : une entrée '
        '« en attente » ouvre la proposition à la place de la liste',
        (tester) async {
          final env = await start(tester);

          await env.save(tester, 3, calmText);

          expectOfferShown(tester);
          expect(find.text('Comment ça va ?'), findsNothing);
          expect(find.text('Nouvelle entrée'), findsNothing);
          expect(env.repo.entries, hasLength(1));
        },
      );

      testWidgets('CA1 : la proposition est marquée comme affichée', (
        tester,
      ) async {
        final env = await start(tester);
        expect(env.settings.modelOfferShown, isFalse);

        await env.save(tester, 3, calmText);

        expect(env.settings.modelOfferShown, isTrue);
      });

      testWidgets('CA1 : rien n\'est téléchargé tant que la personne n\'a pas '
          'appuyé', (tester) async {
        final env = await start(tester);

        await env.save(tester, 3, calmText);

        expect(env.fake.startCalls, 0);
        expect(env.fake.current, isA<ModelAbsent>());
      });

      testWidgets('CA1 : ouvrir la saisie sans enregistrer n\'ouvre pas la '
          'proposition', (tester) async {
        final env = await start(tester);

        await openForm(tester);
        await tester.binding.handlePopRoute();
        await settle(tester);

        expectNoOffer(tester);
        expect(env.settings.modelOfferShown, isFalse);
        expectListShown(tester);
      });

      testWidgets('CA1 : l\'humeur la plus basse, isolée, avec un texte sans '
          'terme de détresse, ouvre la proposition', (tester) async {
        final env = await start(tester);

        await env.save(tester, 1, calmText);

        expectOfferShown(tester);
        expect(env.settings.modelOfferShown, isTrue);
      });

      testWidgets('CA5 : « Plus tard » ramène à la liste, qui montre l\'entrée '
          'enregistrée ; rien n\'est téléchargé', (tester) async {
        final env = await start(tester);
        await env.save(tester, 3, calmText);

        await tester.tap(find.text(later));
        await settle(tester);

        expectNoOffer(tester);
        expectListShown(tester);
        expect(find.textContaining('Journée calme'), findsOneWidget);
        expect(env.fake.startCalls, 0);
        expect(env.fake.current, isA<ModelAbsent>());
        expect(env.settings.modelOfferShown, isTrue);
      });

      testWidgets('CA5 : un geste de retour ramène à la liste, sans '
          'télécharger', (tester) async {
        final env = await start(tester);
        await env.save(tester, 3, calmText);

        await tester.binding.handlePopRoute();
        await settle(tester);

        expectNoOffer(tester);
        expectListShown(tester);
        expect(env.fake.startCalls, 0);
        expect(env.fake.current, isA<ModelAbsent>());
      });

      testWidgets('CA5 : après « Plus tard », la proposition ne revient plus '
          'd\'elle-même à l\'entrée suivante', (tester) async {
        final env = await start(tester);
        await env.save(tester, 3, calmText);
        await tester.tap(find.text(later));
        await settle(tester);

        await env.save(tester, 4, neutralText);

        expectNoOffer(tester);
        expectListShown(tester);
        expect(env.repo.entries, hasLength(2));
      });
    },
  );

  group('pas de proposition (CA2)', () {
    testWidgets('CA2 : une entrée sans texte ouvre la liste, la proposition '
        'reste « jamais affichée »', (tester) async {
      final env = await start(tester);

      await env.save(tester, 3);

      expectNoOffer(tester);
      expectListShown(tester);
      expect(env.repo.entries, hasLength(1));
      expect(env.settings.modelOfferShown, isFalse);
    });

    testWidgets('CA2 : un texte fait seulement d\'espaces compte pour une '
        'entrée sans texte', (tester) async {
      final env = await start(tester);

      await env.save(tester, 3, '   ');

      expectNoOffer(tester);
      expect(env.settings.modelOfferShown, isFalse);
    });

    testWidgets('CA2 : un texte de détresse ouvre l\'écran d\'aide, pas la '
        'proposition', (tester) async {
      final env = await start(tester);

      await env.save(tester, 3, 'envie de mourir');

      expect(find.text(helpTitle), findsOneWidget);
      expectNoOffer(tester);
      expect(env.settings.modelOfferShown, isFalse);
    });

    testWidgets('CA2 : après l\'écran d\'aide, la liste s\'affiche sans '
        'proposition, toujours « jamais affichée »', (tester) async {
      final env = await start(tester);
      await env.save(tester, 3, 'envie de mourir');

      await tester.tap(find.text(backToJournal));
      await settle(tester);

      expectNoOffer(tester);
      expectListShown(tester);
      expect(env.settings.modelOfferShown, isFalse);
    });

    testWidgets('CA2 : une série d\'humeurs « Très bas » sans texte ouvre '
        'l\'écran d\'aide, pas la proposition', (tester) async {
      final env = await start(tester);
      env.seedSeries();

      await env.save(tester, 1);

      expect(find.text(helpTitle), findsOneWidget);
      expectNoOffer(tester);
      expect(env.settings.modelOfferShown, isFalse);
    });

    testWidgets('CA2 : une série d\'humeurs « Très bas » avec un texte sans '
        'terme de détresse ouvre l\'écran d\'aide, pas la proposition', (
      tester,
    ) async {
      final env = await start(tester);
      env.seedSeries();

      await env.save(tester, 1, neutralText);

      expect(find.text(helpTitle), findsOneWidget);
      expectNoOffer(tester);
      expect(env.settings.modelOfferShown, isFalse);
    });

    testWidgets('CA2 : après l\'écran d\'aide d\'une série, la liste '
        's\'affiche sans proposition', (tester) async {
      final env = await start(tester);
      env.seedSeries();
      await env.save(tester, 1, neutralText);

      await tester.tap(find.text(backToJournal));
      await settle(tester);

      expectNoOffer(tester);
      expectListShown(tester);
      expect(env.settings.modelOfferShown, isFalse);
    });
  });

  group('proposition déjà affichée ou modèle déjà là (CA3)', () {
    // Ajouté après la revue de code : un échec récent (téléchargement lancé
    // depuis les Réglages) ne doit pas ouvrir l'écran sur cet échec à la place de
    // la proposition.
    testWidgets(
      'CA3 : modèle absent après un échec : la liste s\'affiche, sans '
      'écran du modèle',
      (tester) async {
        final env = await start(
          tester,
          model: const ModelAbsent(failure: DownloadFailure.network),
        );

        await env.save(tester, 3, calmText);

        expectNoOffer(tester);
        expectListShown(tester);
        expect(env.fake.startCalls, 0);
      },
    );

    testWidgets('CA3 : proposition déjà affichée : la liste s\'affiche, sans '
        'proposition', (tester) async {
      final env = await start(tester, offerShown: true);

      await env.save(tester, 3, calmText);

      expectNoOffer(tester);
      expectListShown(tester);
      expect(find.textContaining('Journée calme'), findsOneWidget);
      expect(env.fake.startCalls, 0);
    });

    testWidgets('CA3 : modèle en téléchargement : la liste s\'affiche, sans '
        'proposition', (tester) async {
      final env = await start(tester, model: downloading28);

      await env.save(tester, 3, calmText);

      expectNoOffer(tester);
      expectListShown(tester);
      expect(env.fake.startCalls, 0);
    });

    testWidgets('CA3 : modèle en vérification : la liste s\'affiche, sans '
        'proposition', (tester) async {
      final env = await start(tester, model: verifying);

      await env.save(tester, 3, calmText);

      expectNoOffer(tester);
      expectListShown(tester);
    });

    testWidgets('CA3 : modèle prêt : la liste s\'affiche, sans proposition', (
      tester,
    ) async {
      final env = await start(tester, model: ready);

      await env.save(tester, 3, calmText);

      expectNoOffer(tester);
      expectListShown(tester);
      expect(env.fake.startCalls, 0);
    });
  });

  group('parcours avec le téléchargement (CA11, CA13)', () {
    testWidgets('CA7 : « Télécharger » dans la proposition lance un '
        'téléchargement et montre la progression', (tester) async {
      final env = await start(tester);
      await env.save(tester, 3, calmText);

      await tester.tap(find.text(downloadButton));
      await settle(tester);

      expect(env.fake.startCalls, greaterThanOrEqualTo(1));
      expect(find.text(cancelButton), findsOneWidget);
      expect(find.text(downloadButton), findsNothing);
    });

    testWidgets('CA11 : « Revenir à mon journal » affiche la liste, le '
        'téléchargement continue et les Réglages montrent sa progression', (
      tester,
    ) async {
      final env = await start(tester);
      await env.save(tester, 3, calmText);
      await tester.tap(find.text(downloadButton));
      await settle(tester);

      await tester.tap(find.text(backToJournalButton));
      await settle(tester);

      expectListShown(tester);
      expect(env.fake.cancelCalls, 0);
      expect(env.fake.current, isA<ModelDownloading>());
      await tester.tap(find.bySemanticsLabel('Réglages').first);
      await settle(tester);
      expect(find.text('Téléchargement : 0 %'), findsOneWidget);
      expect(find.text(settingsSeeDownload), findsOneWidget);
      expect(find.text(downloadButton), findsNothing);
    });

    testWidgets('CA11 : depuis les Réglages, « Voir le téléchargement » '
        'rouvre la progression', (tester) async {
      final env = await start(tester, model: downloading28);
      await tester.tap(find.bySemanticsLabel('Réglages').first);
      await settle(tester);

      await tester.tap(find.text(settingsSeeDownload));
      await settle(tester);

      expect(find.text(progressPercent), findsOneWidget);
      expect(env.fake.startCalls, 0);
    });

    testWidgets('CA13 : annulation confirmée : la liste s\'affiche et le '
        'modèle est « absent »', (tester) async {
      final env = await start(tester);
      await env.save(tester, 3, calmText);
      await tester.tap(find.text(downloadButton));
      await settle(tester);
      await tester.tap(find.text(cancelButton));
      await settle(tester);

      await tester.tap(find.text(cancelButton).last);
      await settle(tester);

      expectNoOffer(tester);
      expectListShown(tester);
      expect(env.fake.cancelCalls, 1);
      expect(env.fake.current, isA<ModelAbsent>());
    });

    testWidgets('CA20 : après un échec, « Plus tard » ramène à la liste', (
      tester,
    ) async {
      final env = await start(tester);
      await env.save(tester, 3, calmText);
      await tester.tap(find.text(downloadButton));
      await settle(tester);

      env.fake.emit(const ModelAbsent(failure: DownloadFailure.network));
      await settle(tester);
      expect(find.text(failNetworkTitle), findsOneWidget);
      await tester.tap(find.text(later));
      await settle(tester);

      expectNoOffer(tester);
      expectListShown(tester);
    });
  });

  group('aucune requête sans appui (CA6)', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('tidemark_ca6_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    testWidgets('CA6 : saisie, proposition, « Plus tard », liste, détail, '
        'Réglages et écran d\'aide : le transport ne reçoit aucune demande', (
      tester,
    ) async {
      final transport = FakeModelTransport();
      final downloader = HttpModelDownloader(
        transport: transport,
        folder: Directory('${tmp.path}/models'),
        source: testSource,
      );
      final env = await start(tester, downloader: downloader);

      // Saisie, puis la proposition s'ouvre d'elle-même.
      await env.save(tester, 3, calmText);
      expectOfferShown(tester);
      await tester.tap(find.text(later));
      await settle(tester);

      // Détail d'une entrée, puis retour.
      await tester.tap(find.textContaining('Journée calme'));
      await settle(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);

      // Réglages : la proposition y est proposée, sans être lancée.
      await tester.tap(find.bySemanticsLabel('Réglages').first);
      await settle(tester);
      expect(find.text(downloadButton), findsOneWidget);
      await tester.tap(find.text(downloadButton));
      await settle(tester);
      expectOfferShown(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);

      // Écran d'aide.
      await env.save(tester, 2, 'envie de mourir');
      expect(find.text(helpTitle), findsOneWidget);
      await tester.tap(find.text(backToJournal));
      await settle(tester);

      expect(transport.calls, isEmpty);
      expect(Directory('${tmp.path}/models').existsSync(), isFalse);
    });

    testWidgets('CA6 : un seul appui sur « Télécharger » suffit à lancer un '
        'téléchargement, et pas deux', (tester) async {
      final env = await start(tester);
      await env.save(tester, 3, calmText);
      expect(env.fake.startCalls, 0);

      await tester.tap(find.text(downloadButton));
      await settle(tester);

      expect(env.fake.startCalls, 1);
    });
  });

  group('démarrage (CA21)', () {
    Journal journalOf(
      FakeEntryRepository repo,
      FakeSettingsRepository settings,
      FakeModelDownloader downloader,
    ) => Journal(entries: repo, settings: settings, downloader: downloader);

    testWidgets('CA21 : au démarrage, l\'état du modèle est déduit des '
        'fichiers, une fois', (tester) async {
      usePhoneScreen(tester);
      final downloader = FakeModelDownloader();

      final app = await startApp(
        open: () async => journalOf(
          FakeEntryRepository(),
          FakeSettingsRepository(),
          downloader,
        ),
      );

      expect(app, isA<TidemarkApp>());
      expect(downloader.checkAtStartupCalls, 1);
      expect(downloader.startCalls, 0);
    });

    testWidgets('CA21 : une erreur de la vérification laisse le modèle absent '
        'et l\'application démarre', (tester) async {
      usePhoneScreen(tester);
      final downloader = FakeModelDownloader()
        ..checkAtStartupError = StateError('dossier illisible');

      final app = await startApp(
        open: () async => journalOf(
          FakeEntryRepository(),
          FakeSettingsRepository(),
          downloader,
        ),
      );

      expect(app, isA<TidemarkApp>());
      expect(downloader.current, isA<ModelAbsent>());
      expect(downloader.startCalls, 0);
    });

    testWidgets(
      'CA21 : au démarrage, la proposition ne s\'ouvre pas, même avec '
      'une entrée « en attente »',
      (tester) async {
        usePhoneScreen(tester);
        final repo = FakeEntryRepository();
        repo.seed(
          mood: 3,
          text: calmText,
          createdAt: DateTime(2026, 10, 14, 8),
        );
        final settings = FakeSettingsRepository();
        final downloader = FakeModelDownloader();
        final app = await startApp(
          open: () async => journalOf(repo, settings, downloader),
        );

        await tester.pumpWidget(app);
        await settle(tester);

        expectNoOffer(tester);
        expect(find.text('Ton journal'), findsOneWidget);
        expect(settings.modelOfferShown, isFalse);
        expect(downloader.startCalls, 0);
      },
    );
  });
}
