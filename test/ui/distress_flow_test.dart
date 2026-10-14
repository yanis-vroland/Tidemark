// Parcours complets de la spec 002 avec TidemarkApp : liste, saisie, écran d'aide,
// retour à la liste, réglages.
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/distress/distress_detector.dart';
import 'package:tidemark/entries/entry.dart';

import '../support/distress_harness.dart';
import '../support/ui_harness.dart';

const emptyListTitle = 'Ta première entrée apparaîtra ici';

void expectHelpShown(WidgetTester tester) {
  expect(find.text(helpTitle), findsOneWidget);
  expect(find.text(call3114), findsOneWidget);
  expect(find.text('Comment ça va ?'), findsNothing);
  expect(find.text('Ton journal'), findsNothing);
  expect(find.text('Nouvelle entrée'), findsNothing);
}

void expectListShown(WidgetTester tester) {
  expect(find.text('Ton journal'), findsOneWidget);
  expect(find.text('Nouvelle entrée'), findsOneWidget);
  expect(find.text(helpTitle), findsNothing);
  expect(find.text('Comment ça va ?'), findsNothing);
}

/// Entrée à 1 de la veille, sans texte, déjà dans le journal.
void seedLow(GuardEnv env, DateTime at) =>
    env.repo.seed(mood: 1, createdAt: at);

void main() {
  group('détection à l\'enregistrement', () {
    testWidgets(
      'CA1 : un texte en détresse ouvre l\'écran d\'aide à la place de '
      'la liste, et l\'entrée est « non analysée »',
      (tester) async {
        usePhoneScreen(tester);
        final env = GuardEnv();
        await tester.pumpWidget(env.app());
        await settle(tester);

        await env.enterEntry(tester, fixedNow, 3, 'J’ai envie de mourir.');

        expectHelpShown(tester);
        expect(env.repo.entries, hasLength(1));
        expect(env.repo.entries.single.analysisStatus, AnalysisStatus.skipped);
        expect(env.repo.entries.single.text, 'J’ai envie de mourir.');
        expect(env.repo.addCalls.single.status, AnalysisStatus.skipped);
      },
    );

    dbTestWidgets('CA1 : sur la vraie base, l\'entrée en détresse est '
        'enregistrée « non analysée » et l\'écran d\'aide s\'affiche', (
      tester,
      env,
    ) async {
      await tester.pumpWidget(env.app());
      await settle(tester);
      await openForm(tester);

      await pickMood(tester, 2);
      await tester.enterText(textInput, 'je veux disparaître');
      await tester.pump();
      await tester.tap(find.text('Enregistrer'));
      await settle(tester);

      expectHelpShown(tester);
      final saved = await env.entries(tester);
      expect(saved.single.analysisStatus, AnalysisStatus.skipped);
      expect(saved.single.text, 'je veux disparaître');
    });

    testWidgets(
      'CA2 : majuscules, accents, apostrophe typographique, ponctuation '
      'et retours à la ligne',
      (tester) async {
        usePhoneScreen(tester);
        final env = GuardEnv();
        await tester.pumpWidget(env.app());
        await settle(tester);

        await env.enterEntry(tester, fixedNow, 4, 'J’ai ENVIE de…\nmourir.');

        expectHelpShown(tester);
      },
    );

    testWidgets('CA4 : un texte sans expression enregistre « en attente » et '
        'ramène à la liste', (tester) async {
      usePhoneScreen(tester);
      final env = GuardEnv();
      await tester.pumpWidget(env.app());
      await settle(tester);

      await env.enterEntry(tester, fixedNow, 4, 'Balade au bord de l’eau.');

      expectListShown(tester);
      expect(find.textContaining('Balade au bord de l'), findsOneWidget);
      expect(env.repo.entries.single.analysisStatus, AnalysisStatus.pending);
    });

    testWidgets('CA3 : un mot qui contient une expression ne déclenche pas '
        'l\'écran d\'aide', (tester) async {
      usePhoneScreen(tester);
      final env = GuardEnv();
      await tester.pumpWidget(env.app());
      await settle(tester);

      await env.enterEntry(tester, fixedNow, 4, 'suicidexyz');

      expectListShown(tester);
    });

    testWidgets('CA6 : une troisième entrée à 1 sans texte, dans les 7 jours, '
        'ouvre l\'écran d\'aide et passe « non analysée »', (tester) async {
      usePhoneScreen(tester);
      final env = GuardEnv();
      seedLow(env, DateTime(2026, 10, 8, 20));
      seedLow(env, DateTime(2026, 10, 12, 20));
      await tester.pumpWidget(env.app());
      await settle(tester);

      await env.enterEntry(tester, fixedNow, 1);

      expectHelpShown(tester);
      expect(env.repo.entries.first.analysisStatus, AnalysisStatus.skipped);
      expect(env.repo.entries, hasLength(3));
    });

    testWidgets(
      'CA6 : une troisième entrée à 1 avec un texte banal ouvre aussi '
      'l\'écran d\'aide, et n\'est jamais « en attente »',
      (tester) async {
        usePhoneScreen(tester);
        final env = GuardEnv();
        seedLow(env, DateTime(2026, 10, 8, 20));
        seedLow(env, DateTime(2026, 10, 12, 20));
        await tester.pumpWidget(env.app());
        await settle(tester);

        await env.enterEntry(tester, fixedNow, 1, 'Journée très lourde.');

        expectHelpShown(tester);
        expect(env.repo.entries.first.analysisStatus, AnalysisStatus.skipped);
      },
    );

    testWidgets('CA7 : deux entrées à 1 dont une d\'une autre humeur entre '
        'elles ne déclenchent rien', (tester) async {
      usePhoneScreen(tester);
      final env = GuardEnv();
      seedLow(env, DateTime(2026, 10, 8, 20));
      env.repo.seed(mood: 3, createdAt: DateTime(2026, 10, 12, 20));
      await tester.pumpWidget(env.app());
      await settle(tester);

      await env.enterEntry(tester, fixedNow, 1);

      expectListShown(tester);
    });

    testWidgets('CA8 : détresse du texte et série à la fois, l\'écran d\'aide '
        's\'affiche une seule fois', (tester) async {
      usePhoneScreen(tester);
      final env = GuardEnv();
      seedLow(env, DateTime(2026, 10, 8, 20));
      seedLow(env, DateTime(2026, 10, 12, 20));
      await tester.pumpWidget(env.app());
      await settle(tester);

      await env.enterEntry(tester, fixedNow, 1, 'envie de mourir');

      expectHelpShown(tester);
      expect(find.text(helpTitle), findsOneWidget);
      await tester.tap(find.text(backToJournal));
      await settle(tester);
      expectListShown(tester);
    });

    testWidgets('CA9 : si l\'enregistrement échoue, aucune détection ne montre '
        'l\'écran d\'aide, même avec un texte en détresse', (tester) async {
      usePhoneScreen(tester);
      final env = GuardEnv();
      seedLow(env, DateTime(2026, 10, 8, 20));
      seedLow(env, DateTime(2026, 10, 12, 20));
      env.repo.beforeAdd = () async => throw StateError('stockage plein');
      await tester.pumpWidget(env.app());
      await settle(tester);

      await env.enterEntry(tester, fixedNow, 1, 'envie de mourir');

      expect(find.text("L'entrée n'a pas été enregistrée"), findsOneWidget);
      expect(find.text(helpTitle), findsNothing);
      expect(find.text('Comment ça va ?'), findsOneWidget);
      expect(env.repo.entries, hasLength(2));
    });

    testWidgets(
      'CA21 : si la lecture du degré échoue, l\'enregistrement aboutit '
      'et « Normale » s\'applique',
      (tester) async {
        usePhoneScreen(tester);
        final env = GuardEnv();
        env.settings.readError = StateError('lecture impossible');
        seedLow(env, DateTime(2026, 10, 8, 20));
        seedLow(env, DateTime(2026, 10, 12, 20));
        await tester.pumpWidget(env.app());
        await settle(tester);

        await env.enterEntry(tester, fixedNow, 1, 'Triste.');

        expectHelpShown(tester);
        expect(find.text("L'entrée n'a pas été enregistrée"), findsNothing);
      },
    );

    testWidgets('CA21 : si la lecture du degré échoue, une entrée banale est '
        'quand même enregistrée', (tester) async {
      usePhoneScreen(tester);
      final env = GuardEnv();
      env.settings.readError = StateError('lecture impossible');
      await tester.pumpWidget(env.app());
      await settle(tester);

      await env.enterEntry(tester, fixedNow, 4, 'Belle journée.');

      expectListShown(tester);
      expect(env.repo.entries, hasLength(1));
      expect(find.text("L'entrée n'a pas été enregistrée"), findsNothing);
    });
  });

  group('série prolongée et degré changé (CA27, CA29)', () {
    testWidgets('CA27 : une quatrième entrée à 1 rouvre l\'écran d\'aide', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final env = GuardEnv();
      await tester.pumpWidget(env.app());
      await settle(tester);

      await env.enterEntry(tester, DateTime(2026, 10, 14, 8), 1, 'Triste un.');
      expectListShown(tester);
      await env.enterEntry(
        tester,
        DateTime(2026, 10, 14, 12),
        1,
        'Triste deux.',
      );
      expectListShown(tester);
      await env.enterEntry(
        tester,
        DateTime(2026, 10, 14, 16),
        1,
        'Triste trois.',
      );
      expectHelpShown(tester);
      await tester.tap(find.text(backToJournal));
      await settle(tester);
      expectListShown(tester);

      await env.enterEntry(
        tester,
        DateTime(2026, 10, 14, 20),
        1,
        'Triste quatre.',
      );

      expectHelpShown(tester);
      expect(env.repo.entries.first.analysisStatus, AnalysisStatus.skipped);
    });

    Future<void> firstLowThenSettings(
      WidgetTester tester,
      GuardEnv env, {
      required bool switchToHigh,
    }) async {
      await tester.pumpWidget(env.app());
      await settle(tester);
      await env.enterEntry(tester, DateTime(2026, 10, 12, 20), 1, 'Triste.');
      expectListShown(tester);
      if (switchToHigh) {
        await tester.tap(find.bySemanticsLabel('Réglages').first);
        await settle(tester);
        await tester.tap(find.text(highLabel));
        await settle(tester);
        await tester.tap(find.text(settingsBack));
        await settle(tester);
        expectListShown(tester);
      }
    }

    testWidgets('CA29 : après le passage à « Haute », une entrée à 1 dans les '
        '3 jours ouvre l\'écran d\'aide', (tester) async {
      usePhoneScreen(tester);
      final env = GuardEnv();

      await firstLowThenSettings(tester, env, switchToHigh: true);
      await env.enterEntry(tester, DateTime(2026, 10, 14, 20), 1, 'Encore.');

      expect(env.settings.value, LowMoodSensitivity.high);
      expectHelpShown(tester);
    });

    testWidgets('CA29 : sans changement de degré, la même entrée ne déclenche '
        'rien (témoin du test précédent)', (tester) async {
      usePhoneScreen(tester);
      final env = GuardEnv();

      await firstLowThenSettings(tester, env, switchToHigh: false);
      await env.enterEntry(tester, DateTime(2026, 10, 14, 20), 1, 'Encore.');

      expectListShown(tester);
    });

    testWidgets('CA19 : le degré choisi dans les Réglages s\'applique à '
        'l\'enregistrement suivant', (tester) async {
      usePhoneScreen(tester);
      final env = GuardEnv();
      env.repo.seed(mood: 1, createdAt: DateTime(2026, 10, 13, 20));
      await tester.pumpWidget(env.app());
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('Réglages').first);
      await settle(tester);

      await tester.tap(find.text(highLabel));
      await settle(tester);
      await tester.tap(find.text(settingsBack));
      await settle(tester);
      await env.enterEntry(tester, fixedNow, 1, 'Encore.');

      expect(env.settings.setCalls, [LowMoodSensitivity.high]);
      expectHelpShown(tester);
    });
  });

  group('écran d\'aide dans l\'app (CA11 à CA13)', () {
    Future<GuardEnv> helpOnScreen(WidgetTester tester) async {
      usePhoneScreen(tester);
      final env = GuardEnv();
      env.repo.seed(
        mood: 3,
        text: 'Une entrée plus ancienne.',
        createdAt: DateTime(2026, 10, 14, 8, 15),
      );
      await tester.pumpWidget(env.app());
      await settle(tester);
      await env.enterEntry(tester, fixedNow, 2, 'envie de mourir');
      expectHelpShown(tester);
      return env;
    }

    testWidgets('CA11 : « Appeler le 3114 » ouvre le composeur et laisse '
        'l\'écran d\'aide affiché', (tester) async {
      final env = await helpOnScreen(tester);

      await tester.tap(find.text(call3114));
      await settle(tester);

      expect(env.dialer.dialed, ['3114']);
      expectHelpShown(tester);
      expect(find.text(dialFailedTitle), findsNothing);
    });

    testWidgets('CA12 : sans composeur, la mention d\'appel impossible '
        's\'affiche dans l\'app', (tester) async {
      final env = await helpOnScreen(tester);
      env.dialer.succeeds = false;

      await tester.tap(find.text(call112));
      await settle(tester);

      expect(env.dialer.dialed, ['112']);
      expect(find.text(dialFailedTitle), findsOneWidget);
      expect(find.text(dialFailedBody), findsOneWidget);
      expectHelpShown(tester);
    });

    testWidgets('CA13 : « Revenir à mon journal » affiche la liste avec la '
        'nouvelle entrée en tête, sans repasser par la saisie', (tester) async {
      await helpOnScreen(tester);

      await tester.tap(find.text(backToJournal));
      await settle(tester);

      expectListShown(tester);
      expect(find.text('21:40'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('21:40')).dy,
        lessThan(tester.getTopLeft(find.text('08:15')).dy),
      );
      expect(find.textContaining('envie de mourir'), findsOneWidget);
    });

    testWidgets('CA13 : un geste de retour affiche la liste, la saisie ne '
        'réapparaît pas', (tester) async {
      final env = await helpOnScreen(tester);

      await tester.binding.handlePopRoute();
      await settle(tester);

      expectListShown(tester);
      expect(find.text('21:40'), findsOneWidget);
      expect(env.repo.entries, hasLength(2));
    });

    testWidgets('CA13 : après le retour, la liste fonctionne : une nouvelle '
        'saisie reste possible', (tester) async {
      final env = await helpOnScreen(tester);
      await tester.tap(find.text(backToJournal));
      await settle(tester);

      await openForm(tester);

      expect(find.text('Comment ça va ?'), findsOneWidget);
      expect(env.repo.entries, hasLength(2));
    });
  });
}
