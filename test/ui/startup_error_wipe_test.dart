// Écran « journal impossible à ouvrir » avec la spec 005 (CA23, CA26, CA27, CA33 à
// CA35) : bouton « Tout supprimer et repartir de zéro » quand la clé est introuvable,
// écran « La suppression n'est pas terminée » quand la reprise échoue.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/main.dart';
import 'package:tidemark/ui/app_host.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';

import '../support/ui_harness.dart';
import '../support/wipe_harness.dart';

const errorTitle = "Ton journal n'a pas pu être ouvert";
const keyMissingBody =
    'Tes entrées sont toujours sur le téléphone, mais la clé qui les protège est '
    "introuvable. Rien n'a été effacé.";
const otherCauseBody = "Rien n'a été effacé. Ferme l'app, puis rouvre-la.";
const keyMissingAddition =
    'Sans cette clé, elles ne pourront plus être lues. Tu peux tout supprimer et '
    'commencer un nouveau journal.';
const wipeFromScratch = 'Tout supprimer et repartir de zéro';
const incompleteTitle = "La suppression n'est pas terminée";
const incompleteMessage =
    'Une partie de tes données a peut-être déjà été effacée. Réessaie : la '
    "suppression reprend où elle s'est arrêtée.";
const retryLabel = 'Réessayer';

void startupTest(
  String description,
  Future<void> Function(WidgetTester tester, WipeEnv env) body, {
  bool tall = true,
}) {
  testWidgets(description, (tester) async {
    if (tall) {
      useTallScreen(tester);
    } else {
      usePhoneScreen(tester);
    }
    final semantics = tester.ensureSemantics();
    final env = WipeEnv();
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    try {
      await body(tester, env);
    } finally {
      await tester.pumpWidget(const SizedBox());
      env.dispose();
      semantics.dispose();
    }
  });
}

Future<void> show(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await settle(tester);
}

StartupErrorApp keyMissingApp(WipeEnv env) =>
    StartupErrorApp(keyMissing: true, wiper: env.wiper());

const incompleteApp = StartupErrorApp(keyMissing: false, wipeIncomplete: true);

bool shown(String text) => find.text(text).evaluate().isNotEmpty;

void main() {
  group('CA26 : clé introuvable', () {
    startupTest('CA26 : les textes de la spec 001 sont gardés, le texte et le '
        'bouton de suppression sont ajoutés', (tester, env) async {
      await show(tester, keyMissingApp(env));

      expect(find.text(errorTitle), findsOneWidget);
      expect(find.text(keyMissingBody), findsOneWidget);
      expect(find.text(keyMissingAddition), findsOneWidget);
      expect(find.text(wipeFromScratch), findsOneWidget);
      expect(isEnabled(tester, wipeFromScratch), isTrue);
      expect(
        tester.getTopLeft(find.text(wipeFromScratch)).dy,
        greaterThan(tester.getTopLeft(find.text(keyMissingAddition)).dy),
      );
    });

    startupTest('CA26 : « Tout supprimer et repartir de zéro » est en danger '
        '(texte et bordure), sur surface-raised, thème clair', (
      tester,
      env,
    ) async {
      await show(tester, keyMissingApp(env));

      expectDangerButton(tester, wipeFromScratch, TidemarkColors.light);
    });

    startupTest('CA26 : pour toute autre cause, ni le texte ni le bouton', (
      tester,
      env,
    ) async {
      // Même si un JournalWiper est passé : le bouton ne dépend que de la cause.
      await show(
        tester,
        StartupErrorApp(keyMissing: false, wiper: env.wiper()),
      );

      expect(find.text(errorTitle), findsOneWidget);
      expect(find.text(otherCauseBody), findsOneWidget);
      expect(find.text(keyMissingAddition), findsNothing);
      expect(find.text(wipeFromScratch), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    startupTest('CA26 : autre cause sans suppression, ni texte ni bouton', (
      tester,
      env,
    ) async {
      await show(tester, const StartupErrorApp(keyMissing: false));

      expect(find.text(otherCauseBody), findsOneWidget);
      expect(find.text(keyMissingAddition), findsNothing);
      expect(find.text(wipeFromScratch), findsNothing);
    });

    startupTest('CA26 : l\'écran ne lance rien de lui-même', (
      tester,
      env,
    ) async {
      env.populate();

      await show(tester, keyMissingApp(env));
      await settleIo(tester);

      expect(find.text(wipeFromScratch), findsOneWidget);
      expect(env.log, isEmpty);
      expect(env.exists('tidemark/journal.db'), isTrue);
    });
  });

  group('CA27 : le bouton ouvre la confirmation', () {
    startupTest('CA27 : la confirmation s\'affiche avec « Retour », la liste '
        'et l\'avertissement adaptés', (tester, env) async {
      await show(tester, keyMissingApp(env));

      await tester.tap(find.text(wipeFromScratch));
      await settle(tester);

      expect(find.text('Tout supprimer ?'), findsOneWidget);
      expect(find.text('Retour'), findsOneWidget);
      expect(
        find.textContaining(
          'tes entrées et leurs étiquettes, illisibles sans leur clé',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('tes réglages'), findsOneWidget);
      expect(find.textContaining("le modèle d'IA téléchargé"), findsOneWidget);
      expect(
        find.textContaining('la clé qui protège ton journal'),
        findsNothing,
      );
      expect(
        find.text(
          'Rien ne pourra être récupéré. Sans sa clé, ton journal ne peut pas '
          'être exporté.',
        ),
        findsOneWidget,
      );
      expect(find.text('Pour confirmer, écris SUPPRIMER'), findsOneWidget);
      expect(isEnabled(tester, 'Tout supprimer définitivement'), isFalse);
      expect(
        env.log,
        isEmpty,
        reason: 'rien n\'est effacé avant la confirmation',
      );
    });

    startupTest('CA27 : « Retour » ramène à l\'écran « journal impossible à '
        'ouvrir », rien n\'est effacé', (tester, env) async {
      env.populate();
      await show(tester, keyMissingApp(env));
      await tester.tap(find.text(wipeFromScratch));
      await settle(tester);

      await tester.tap(find.text('Retour'));
      await settle(tester);

      expect(find.text('Tout supprimer ?'), findsNothing);
      expect(find.text(errorTitle), findsOneWidget);
      expect(find.text(wipeFromScratch), findsOneWidget);
      expect(env.log, isEmpty);
    });

    startupTest('CA27 : un geste de retour ramène à l\'écran « journal '
        'impossible à ouvrir »', (tester, env) async {
      await show(tester, keyMissingApp(env));
      await tester.tap(find.text(wipeFromScratch));
      await settle(tester);

      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(find.text(errorTitle), findsOneWidget);
    });
  });

  group('CA23 : suppression non terminée', () {
    startupTest('CA23 : titre « La suppression n\'est pas terminée », texte de '
        'CA21 et bouton « Réessayer »', (tester, env) async {
      await show(tester, incompleteApp);

      expect(find.text(incompleteTitle), findsOneWidget);
      expect(find.text(incompleteMessage), findsOneWidget);
      expect(find.text(retryLabel), findsOneWidget);
      expect(isEnabled(tester, retryLabel), isTrue);
      expect(find.text(errorTitle), findsNothing);
      expect(find.text(wipeFromScratch), findsNothing);
      expect(find.text(keyMissingAddition), findsNothing);
    });

    startupTest('CA23 : « Réessayer » rouvre l\'app avec le message de fin '
        '(restart avec wiped: true)', (tester, env) async {
      final calls = <bool>[];
      await show(
        tester,
        AppHost(
          initial: incompleteApp,
          restart: ({required wiped}) async {
            calls.add(wiped);
            return const Directionality(
              textDirection: TextDirection.ltr,
              child: Text('app rouverte'),
            );
          },
        ),
      );

      await tester.tap(find.text(retryLabel));
      await pumpUntil(tester, () => shown('app rouverte'));

      expect(calls, [true]);
      expect(find.text(incompleteTitle), findsNothing);
    });

    startupTest('CA23 : « Réessayer » sans AppHost ne plante pas', (
      tester,
      env,
    ) async {
      await show(tester, incompleteApp);

      await tester.tap(find.text(retryLabel));
      await settleIo(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(incompleteTitle), findsOneWidget);
    });

    startupTest('CA23 : l\'écran n\'efface rien de lui-même', (
      tester,
      env,
    ) async {
      env.populate();

      await show(tester, incompleteApp);
      await settleIo(tester);

      expect(find.text(incompleteTitle), findsOneWidget);
      expect(env.log, isEmpty);
    });
  });

  group('CA33 : lecteur d\'écran', () {
    startupTest('CA33 : « Tout supprimer et repartir de zéro » s\'annonce '
        'comme un bouton actif', (tester, env) async {
      await show(tester, keyMissingApp(env));

      final node = tester.getSemantics(find.text(wipeFromScratch));

      expect(node.label, contains(wipeFromScratch));
      expect(node.flagsCollection.isButton, isTrue);
      expect(isEnabled(tester, wipeFromScratch), isTrue);
    });

    startupTest('CA33 : « Réessayer » s\'annonce comme un bouton actif', (
      tester,
      env,
    ) async {
      await show(tester, incompleteApp);

      final node = tester.getSemantics(find.text(retryLabel));

      expect(node.flagsCollection.isButton, isTrue);
      expect(isEnabled(tester, retryLabel), isTrue);
    });
  });

  group('CA34 : texte du système à 200 %', () {
    startupTest('CA34 : clé introuvable, l\'écran défile, rien ne déborde, le '
        'bouton est atteignable', (tester, env) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      await show(tester, keyMissingApp(env));

      for (final fragment in [keyMissingBody, keyMissingAddition]) {
        await scrollTo(tester, find.text(fragment));
        expect(
          paragraphOf(tester, fragment).truncated,
          isFalse,
          reason: fragment,
        );
      }
      await scrollTo(tester, find.text(wipeFromScratch));
      expect(tester.takeException(), isNull);
    }, tall: false);

    startupTest('CA34 : suppression non terminée, l\'écran défile, rien ne '
        'déborde, « Réessayer » est atteignable', (tester, env) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      await show(tester, incompleteApp);

      await scrollTo(tester, find.text(incompleteMessage));
      expect(paragraphOf(tester, incompleteMessage).truncated, isFalse);
      await scrollTo(tester, find.text(retryLabel));
      expect(tester.takeException(), isNull);
    }, tall: false);

    startupTest('CA34 : autre cause, rien ne déborde', (tester, env) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      await show(tester, const StartupErrorApp(keyMissing: false));

      expect(paragraphOf(tester, otherCauseBody).truncated, isFalse);
      expect(tester.takeException(), isNull);
    }, tall: false);
  });

  group('CA35 : thème sombre', () {
    startupTest('CA35 : « Tout supprimer et repartir de zéro » a son texte et '
        'sa bordure en danger sombre, sur surface-raised sombre, jamais un '
        'fond danger', (tester, env) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await show(tester, keyMissingApp(env));

      expectDangerButton(tester, wipeFromScratch, TidemarkColors.dark);
      expect(
        buttonColors(tester, wipeFromScratch).background,
        isNot(TidemarkColors.dark.danger),
      );
    });

    startupTest('CA35 : le titre de l\'écran est en danger sombre', (
      tester,
      env,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await show(tester, incompleteApp);

      final title = tester.widget<Text>(find.text(incompleteTitle));
      expect(title.style?.color, TidemarkColors.dark.danger);
    });
  });
}
