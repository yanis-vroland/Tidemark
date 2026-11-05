// Démarrage et bienvenue (spec 009, CA1 à CA3, CA5, CA6) : `startApp` calcule
// `showWelcome` = réglage « bienvenue vue » à faux ET journal sans entrée ; toute
// erreur de lecture donne `false`. Journal de faux : aucune base, aucun réseau.
// La suppression totale (CA4) est dans test/ui/wipe_flow_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/main.dart';
import 'package:tidemark/ui/screens/home_shell.dart';
import 'package:tidemark/ui/screens/welcome_screen.dart';

import '../support/fake_entry_repository.dart';
import '../support/fake_model_downloader.dart';
import '../support/fake_settings_repository.dart';
import '../support/ui_harness.dart';

Journal journalOf(FakeEntryRepository repo, FakeSettingsRepository settings) =>
    Journal(
      entries: repo,
      settings: settings,
      downloader: FakeModelDownloader(readyModel),
    );

Future<TidemarkApp> start(
  WidgetTester tester,
  FakeEntryRepository repo,
  FakeSettingsRepository settings,
) async {
  final app = await tester.runAsync(
    () => startApp(open: () async => journalOf(repo, settings)),
  );
  return app! as TidemarkApp;
}

Future<void> show(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await settle(tester);
}

FakeEntryRepository journalWithOneEntry() =>
    FakeEntryRepository()
      ..seed(mood: 3, createdAt: DateTime(2026, 10, 14, 8, 15));

void main() {
  group('premier lancement (CA1)', () {
    testWidgets('CA1 : réglage à faux et aucune entrée, la bienvenue '
        's\'affiche à la place du journal', (tester) async {
      usePhoneScreen(tester);
      final app = await start(
        tester,
        FakeEntryRepository(),
        FakeSettingsRepository(),
      );

      expect(app.showWelcome, isTrue);
      await show(tester, app);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text("C'est parti"), findsOneWidget);
      expect(find.byType(HomeShell), findsNothing);
    });
  });

  group('lancements suivants (CA2)', () {
    testWidgets('CA2 : « C\'est parti » enregistre le réglage ; au lancement '
        'suivant, la bienvenue ne s\'affiche plus, même sans entrée', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final repo = FakeEntryRepository();
      final settings = FakeSettingsRepository();
      await show(tester, await start(tester, repo, settings));
      await tester.tap(find.text("C'est parti"));
      await settle(tester);
      expect(settings.welcomeShown, isTrue);
      await tester.pumpWidget(const SizedBox());

      final second = await start(tester, repo, settings);

      expect(second.showWelcome, isFalse);
      await show(tester, second);
      expect(find.byType(WelcomeScreen), findsNothing);
      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.text('Ta première entrée apparaîtra ici'), findsOneWidget);
    });

    testWidgets('CA2 : réglage à vrai, la bienvenue ne s\'affiche pas', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final settings = FakeSettingsRepository()..welcomeShown = true;

      final app = await start(tester, FakeEntryRepository(), settings);

      expect(app.showWelcome, isFalse);
      await show(tester, app);
      expect(find.byType(WelcomeScreen), findsNothing);
    });
  });

  group('mise à jour depuis une version sans bienvenue (CA3)', () {
    testWidgets('CA3 : au moins une entrée et réglage à faux, pas de '
        'bienvenue', (tester) async {
      usePhoneScreen(tester);
      final settings = FakeSettingsRepository();

      final app = await start(tester, journalWithOneEntry(), settings);

      expect(app.showWelcome, isFalse);
      await show(tester, app);
      expect(find.byType(WelcomeScreen), findsNothing);
      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.text('Ton journal'), findsOneWidget);
    });

    testWidgets('CA3 : une seule entrée suffit, quelle que soit son '
        'ancienneté', (tester) async {
      usePhoneScreen(tester);
      final repo = FakeEntryRepository()
        ..seed(mood: 1, createdAt: DateTime(2024, 1, 2, 9));

      final app = await start(tester, repo, FakeSettingsRepository());

      expect(app.showWelcome, isFalse);
    });
  });

  group('erreurs de lecture (CA6)', () {
    testWidgets('CA6 : lecture du réglage en erreur, pas de bienvenue même '
        'avec un journal vide', (tester) async {
      usePhoneScreen(tester);
      final settings = FakeSettingsRepository()
        ..welcomeReadError = StateError('lecture impossible');

      final app = await start(tester, FakeEntryRepository(), settings);

      expect(app.showWelcome, isFalse);
      await show(tester, app);
      expect(find.byType(WelcomeScreen), findsNothing);
      expect(find.byType(HomeShell), findsOneWidget);
    });

    testWidgets('CA6 : lecture des entrées en erreur, pas de bienvenue', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final repo = FakeEntryRepository()
        ..latestEntriesError = StateError('lecture impossible');

      final app = await start(tester, repo, FakeSettingsRepository());

      expect(app.showWelcome, isFalse);
      await show(tester, app);
      expect(find.byType(WelcomeScreen), findsNothing);
      expect(find.byType(HomeShell), findsOneWidget);
    });

    testWidgets(
      'CA6 : lectures en erreur, l\'accueil gère l\'erreur (spec 001, '
      'CA32) : « Ton journal n\'a pas pu être lu »',
      (tester) async {
        usePhoneScreen(tester);
        final repo = FakeEntryRepository()
          ..latestEntriesError = StateError('lecture impossible')
          ..watchError = StateError('lecture impossible');
        final settings = FakeSettingsRepository()
          ..welcomeReadError = StateError('lecture impossible');

        final app = await start(tester, repo, settings);
        await show(tester, app);

        expect(app.showWelcome, isFalse);
        expect(find.text("Ton journal n'a pas pu être lu"), findsOneWidget);
        expect(find.text('Ta première entrée apparaîtra ici'), findsNothing);
      },
    );

    testWidgets('CA6 : les deux lectures en erreur, pas de bienvenue', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final repo = FakeEntryRepository()
        ..latestEntriesError = StateError('lecture impossible');
      final settings = FakeSettingsRepository()
        ..welcomeReadError = StateError('lecture impossible');

      final app = await start(tester, repo, settings);

      expect(app.showWelcome, isFalse);
    });
  });

  group('erreur à l\'écriture (CA5)', () {
    testWidgets('CA5 : l\'accueil s\'affiche quand même ; la bienvenue '
        'reviendra au lancement suivant', (tester) async {
      usePhoneScreen(tester);
      final repo = FakeEntryRepository();
      final settings = FakeSettingsRepository()
        ..welcomeWriteError = StateError('écriture impossible');
      await show(tester, await start(tester, repo, settings));

      await tester.tap(find.text("C'est parti"));
      await settle(tester);

      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(settings.welcomeShown, isFalse);
      await tester.pumpWidget(const SizedBox());

      final second = await start(tester, repo, settings);
      expect(second.showWelcome, isTrue);
    });
  });
}
