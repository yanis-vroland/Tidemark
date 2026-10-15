// Confirmation de la suppression totale (spec 005 ; CA14 à CA17, CA20, CA21, CA27,
// CA33 à CA35) : écran, champ « SUPPRIMER », états en cours et en erreur. Vrais
// fichiers dans un dossier temporaire, trousseau et accès aux fichiers factices.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/ui/screens/wipe_confirmation_screen.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';

import '../support/ui_harness.dart';
import '../support/wipe_harness.dart';

const title = 'Tout supprimer ?';
const lead = 'Cette action efface définitivement, sur ce téléphone :';
const itemEntries = 'toutes tes entrées et leurs étiquettes';
const itemSettings = 'tes réglages';
const itemKey = 'la clé qui protège ton journal';
const itemModel = "le modèle d'IA téléchargé";
const itemEntriesNoKey =
    'tes entrées et leurs étiquettes, illisibles sans leur clé';
const warning =
    'Rien ne pourra être récupéré. Pour garder une copie, exporte d\'abord tes '
    'données depuis les Réglages.';
const warningNoKey =
    'Rien ne pourra être récupéré. Sans sa clé, ton journal ne peut pas être '
    'exporté.';
const fieldLabel = 'Pour confirmer, écris SUPPRIMER';
const confirmLabel = 'Tout supprimer définitivement';
const cancelLabel = 'Annuler';
const busyLabel = 'Suppression…';
const busyNote =
    "Si l'app se ferme, la suppression reprendra au prochain lancement.";
const notStartedTitle = "La suppression n'a pas commencé";
const notStartedMessage = "Rien n'a été effacé. Réessaie.";
const incompleteTitle = "La suppression n'est pas terminée";
const incompleteMessage =
    'Une partie de tes données a peut-être déjà été effacée. Réessaie : la '
    'suppression reprend où elle s\'est arrêtée.';
const retryLabel = 'Réessayer';

/// `testWidgets` sur un [WipeEnv] (écran très haut par défaut).
void wipeTest(
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

/// Ouvre la confirmation depuis un accueil (le geste de retour peut la fermer).
Future<void> openConfirmation(
  WidgetTester tester,
  WipeEnv env, {
  bool keyMissing = false,
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    homeWithPush(
      WipeConfirmationScreen(
        wiper: env.wiper(),
        keyMissing: keyMissing,
        onWiped: env.onWiped,
      ),
      textScale: textScale,
    ),
  );
  await tester.tap(find.text('Ouvrir'));
  await settle(tester);
}

/// Écrit « SUPPRIMER » puis touche « Tout supprimer définitivement ».
Future<void> confirm(WidgetTester tester) async {
  await typeConfirmation(tester, 'SUPPRIMER');
  await tester.tap(find.text(confirmLabel));
}

bool shown(String text) => find.text(text).evaluate().isNotEmpty;

bool shownContaining(String text) =>
    find.textContaining(text).evaluate().isNotEmpty;

TextField field(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField));

/// Tout ce qu'une suppression réussie efface (CA18).
void expectEverythingWiped(WipeEnv env) {
  for (final path in const [
    'tidemark/journal.db',
    'tidemark/journal.db-wal',
    'tidemark/journal.db-shm',
    'tidemark/journal.db-journal',
    'tidemark/models',
    'cache/tidemark-export',
    'cache/share_plus',
    'tidemark/wipe-pending',
  ]) {
    expect(env.exists(path), isFalse, reason: path);
  }
  expect(env.keyStore.stored, isNull);
}

void main() {
  group('CA14 : l\'écran de confirmation, depuis les Réglages', () {
    dataTest('CA14 : « Tout supprimer » ouvre la confirmation, avec le titre, '
        'la liste, l\'avertissement, le champ, le bouton désactivé et '
        '« Annuler »', (tester, env) async {
      await tester.pumpWidget(env.settingsOnTop());
      await tester.tap(find.text('Ouvrir'));
      await settle(tester);

      await tester.tap(find.text('Tout supprimer'));
      await settle(tester);

      expect(find.text(title), findsOneWidget);
      expect(find.text(lead), findsOneWidget);
      for (final item in [itemEntries, itemSettings, itemKey, itemModel]) {
        expect(find.textContaining(item), findsOneWidget, reason: item);
      }
      expect(find.text(warning), findsOneWidget);
      expect(find.text(fieldLabel), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(confirmLabel), findsOneWidget);
      expect(isEnabled(tester, confirmLabel), isFalse);
      expect(find.text(cancelLabel), findsOneWidget);
      expect(find.text('Réglages'), findsOneWidget, reason: 'lien de retour');
      expect(find.text('Mes données'), findsNothing);
    });

    wipeTest('CA14 : la liste dit ce qui sera effacé, dans l\'ordre de la '
        'spec', (tester, env) async {
      await openConfirmation(tester, env);

      final tops = [
        for (final item in [itemEntries, itemSettings, itemKey, itemModel])
          tester.getTopLeft(find.textContaining(item)).dy,
      ];
      expect(tops, [...tops]..sort());
      expect(tester.getTopLeft(find.text(lead)).dy, lessThan(tops.first));
      expect(
        tester.getTopLeft(find.text(title)).dy,
        lessThan(tester.getTopLeft(find.text(lead)).dy),
      );
    });

    wipeTest('CA14 : l\'ouverture de l\'écran n\'efface rien', (
      tester,
      env,
    ) async {
      env.populate();

      await openConfirmation(tester, env);
      await settleIo(tester);

      expect(find.text(title), findsOneWidget);
      expect(env.log, isEmpty);
      expect(env.exists('tidemark/journal.db'), isTrue);
      expect(env.keyStore.stored, isNotNull);
    });
  });

  group('CA15 : le champ « SUPPRIMER »', () {
    const accepted = [
      'SUPPRIMER',
      'supprimer',
      'Supprimer',
      '  SUPPRIMER',
      'supprimer   ',
      '  Supprimer  ',
    ];
    const rejected = [
      '',
      'SUPPRIME',
      'SUPPRIMER.',
      'SUP PRIMER',
      'SUPPRIMERS',
      'SUPPRIMÉ',
      'OUI',
    ];

    for (final value in accepted) {
      wipeTest('CA15 : « $value » active le bouton', (tester, env) async {
        await openConfirmation(tester, env);

        await typeConfirmation(tester, value);

        expect(isEnabled(tester, confirmLabel), isTrue);
      });
    }

    for (final value in rejected) {
      wipeTest('CA15 : « $value » laisse le bouton désactivé', (
        tester,
        env,
      ) async {
        await openConfirmation(tester, env);

        await typeConfirmation(tester, value);

        expect(isEnabled(tester, confirmLabel), isFalse);
      });
    }

    wipeTest('CA15 : le bouton se désactive de nouveau si le texte est '
        'modifié', (tester, env) async {
      await openConfirmation(tester, env);
      await typeConfirmation(tester, 'SUPPRIMER');
      expect(isEnabled(tester, confirmLabel), isTrue);

      await typeConfirmation(tester, 'SUPPRIMER.');

      expect(isEnabled(tester, confirmLabel), isFalse);
    });

    wipeTest('CA15 : un appui sur le bouton désactivé n\'efface rien', (
      tester,
      env,
    ) async {
      env.populate();
      await openConfirmation(tester, env);
      await typeConfirmation(tester, 'SUPPRIME');

      await tester.tap(find.text(confirmLabel), warnIfMissed: false);
      await settleIo(tester);

      expect(env.log, isEmpty);
    });

    wipeTest('CA15 : clavier en majuscules, sans correction automatique, sans '
        'suggestions ni apprentissage du clavier', (tester, env) async {
      await openConfirmation(tester, env);

      final input = field(tester);

      expect(input.textCapitalization, TextCapitalization.characters);
      expect(input.autocorrect, isFalse);
      expect(input.enableSuggestions, isFalse);
      expect(input.enableIMEPersonalizedLearning, isFalse);
    });
  });

  group('CA16 : annuler', () {
    dataTest('CA16 : « Annuler » ramène aux Réglages, rien n\'est effacé', (
      tester,
      env,
    ) async {
      env.wipe.populate();
      await tester.pumpWidget(env.settingsOnTop());
      await tester.tap(find.text('Ouvrir'));
      await settle(tester);
      await tester.tap(find.text('Tout supprimer'));
      await settle(tester);
      await typeConfirmation(tester, 'SUPPRIMER');

      await tester.tap(find.text(cancelLabel));
      await settle(tester);

      expect(find.text(title), findsNothing);
      expect(find.text('Mes données'), findsOneWidget);
      expect(find.text('Réglages'), findsOneWidget);
      expect(env.wipe.log, isEmpty);
      expect(env.wipe.exists('tidemark/journal.db'), isTrue);
      expect(env.wipe.keyStore.stored, isNotNull);
    });

    dataTest('CA16 : le lien « Réglages » ramène aux Réglages, rien n\'est '
        'effacé', (tester, env) async {
      env.wipe.populate();
      await tester.pumpWidget(env.settingsOnTop());
      await tester.tap(find.text('Ouvrir'));
      await settle(tester);
      await tester.tap(find.text('Tout supprimer'));
      await settle(tester);

      await tester.tap(find.text('Réglages'));
      await settle(tester);

      expect(find.text(title), findsNothing);
      expect(find.text('Mes données'), findsOneWidget);
      expect(env.wipe.log, isEmpty);
    });

    dataTest('CA16 : un geste de retour ramène aux Réglages, rien n\'est '
        'effacé', (tester, env) async {
      env.wipe.populate();
      await tester.pumpWidget(env.settingsOnTop());
      await tester.tap(find.text('Ouvrir'));
      await settle(tester);
      await tester.tap(find.text('Tout supprimer'));
      await settle(tester);

      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(find.text(title), findsNothing);
      expect(find.text('Mes données'), findsOneWidget);
      expect(env.wipe.log, isEmpty);
      expect(env.wipe.keyStore.stored, isNotNull);
    });
  });

  group('CA17 : suppression en cours', () {
    wipeTest('CA17 : « Suppression… » désactivé, champ désactivé, plus de '
        '« Annuler » ni de retour, mention affichée, retour sans effet', (
      tester,
      env,
    ) async {
      env.populate();
      final gate = Completer<void>();
      env.closeBody = () => gate.future;
      await openConfirmation(tester, env);

      await confirm(tester);
      await pumpUntil(tester, () => env.log.contains('closeJournal'));

      expect(find.text(busyLabel), findsOneWidget);
      expect(isEnabled(tester, busyLabel), isFalse);
      expect(find.text(confirmLabel), findsNothing);
      expect(field(tester).enabled, isFalse);
      expect(find.text(cancelLabel), findsNothing);
      expect(find.text('Réglages'), findsNothing);
      expect(find.text(busyNote), findsOneWidget);
      expect(env.wipedCalls, 0);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text(title), findsOneWidget);
      expect(find.text(busyLabel), findsOneWidget);

      gate.complete();
      await pumpUntil(tester, () => env.wipedCalls == 1);
    });

    wipeTest('CA17 : les étapes ont lieu dans l\'ordre de la section '
        '« Suppression totale »', (tester, env) async {
      env.populate();
      await openConfirmation(tester, env);

      await confirm(tester);
      await pumpUntil(tester, () => env.wipedCalls == 1);

      expectWipeSteps(env.log, wipeStepGroups);
    });

    wipeTest('CA18 : après la suppression, tout est effacé et le marqueur '
        'd\'installation reste', (tester, env) async {
      env.populate();
      await openConfirmation(tester, env);

      await confirm(tester);
      await pumpUntil(tester, () => env.wipedCalls == 1);

      expectEverythingWiped(env);
      expect(env.exists('tidemark/installed'), isTrue);
      expect(env.wipedCalls, 1);
    });

    wipeTest('CA17 : sans onWiped ni AppHost, la suppression va à son terme '
        'sans erreur', (tester, env) async {
      env.populate();
      await tester.pumpWidget(
        homeWithPush(WipeConfirmationScreen(wiper: env.wiper())),
      );
      await tester.tap(find.text('Ouvrir'));
      await settle(tester);

      await confirm(tester);
      await pumpUntil(
        tester,
        () =>
            env.log.isNotEmpty &&
            env.log.last == 'deleteFile tidemark/wipe-pending',
      );
      await settleIo(tester);

      expectEverythingWiped(env);
      expect(tester.takeException(), isNull);
    });
  });

  group('CA20 : le marqueur ne peut pas être écrit', () {
    wipeTest('CA20 : bandeau « La suppression n\'a pas commencé », rien n\'est '
        'effacé, « Annuler » reste disponible, « Réessayer » est actif', (
      tester,
      env,
    ) async {
      env.populate();
      env.files.failOn.add('createFile tidemark/wipe-pending');
      await openConfirmation(tester, env);

      await confirm(tester);
      await pumpUntil(tester, () => shown(notStartedTitle));
      await settleIo(tester);

      expect(find.text(notStartedMessage), findsOneWidget);
      expect(find.text(cancelLabel), findsOneWidget);
      expect(isEnabled(tester, cancelLabel), isTrue);
      expect(find.text(retryLabel), findsOneWidget);
      expect(isEnabled(tester, retryLabel), isTrue);
      expect(find.text(busyLabel), findsNothing);
      expect(env.log, ['createFile tidemark/wipe-pending']);
      expect(env.exists('tidemark/journal.db'), isTrue);
      expect(env.exists('tidemark/models'), isTrue);
      expect(env.keyStore.stored, isNotNull);
      expect(env.wipedCalls, 0);
      expect(isAnnounced(tester, notStartedTitle), isTrue);
    });

    wipeTest('CA20 : « Annuler » ferme l\'écran, rien n\'est effacé', (
      tester,
      env,
    ) async {
      env.populate();
      env.files.failOn.add('createFile tidemark/wipe-pending');
      await openConfirmation(tester, env);
      await confirm(tester);
      await pumpUntil(tester, () => shown(notStartedTitle));

      await tester.tap(find.text(cancelLabel));
      await settle(tester);

      expect(find.text(title), findsNothing);
      expect(env.exists('tidemark/journal.db'), isTrue);
    });

    wipeTest('CA20 : « Réessayer », une fois l\'écriture possible, efface '
        'tout', (tester, env) async {
      env.populate();
      env.files.failOn.add('createFile tidemark/wipe-pending');
      await openConfirmation(tester, env);
      await confirm(tester);
      await pumpUntil(tester, () => shown(notStartedTitle));
      env.repair();
      env.log.clear();

      await tester.tap(find.text(retryLabel));
      await pumpUntil(tester, () => env.wipedCalls == 1);

      expectWipeSteps(env.log, wipeStepGroups);
      expectEverythingWiped(env);
    });
  });

  group('CA21 : une étape suivante échoue', () {
    for (final failing in wipeFailurePoints) {
      wipeTest('CA21 : échec à « $failing » : bandeau « La suppression n\'est '
          'pas terminée », « Réessayer », ni « Annuler » ni retour', (
        tester,
        env,
      ) async {
        env.populate();
        env.failAt(failing);
        await openConfirmation(tester, env);

        await confirm(tester);
        await pumpUntil(tester, () => shown(incompleteTitle));
        await settleIo(tester);

        expect(find.text(incompleteMessage), findsOneWidget);
        expect(find.text(retryLabel), findsOneWidget);
        expect(isEnabled(tester, retryLabel), isTrue);
        expect(find.text(cancelLabel), findsNothing);
        expect(find.text('Réglages'), findsNothing);
        expect(find.text(busyLabel), findsNothing);
        expect(isAnnounced(tester, incompleteTitle), isTrue);
        expectWipeStoppedAt(env.log, failing);
        expect(env.exists('tidemark/wipe-pending'), isTrue);
        expect(env.wipedCalls, 0);

        // Pas de retour possible : le geste de retour ne fait rien.
        await tester.binding.handlePopRoute();
        await settle(tester);
        expect(find.text(title), findsOneWidget);
        expect(find.text(incompleteTitle), findsOneWidget);
      });

      wipeTest('CA21 : après un échec à « $failing », « Réessayer » rejoue la '
          'reprise sans réécrire « SUPPRIMER »', (tester, env) async {
        env.populate();
        env.failAt(failing);
        await openConfirmation(tester, env);
        await confirm(tester);
        await pumpUntil(tester, () => shown(incompleteTitle));
        await settleIo(tester);
        env.repair();
        env.log.clear();

        await tester.tap(find.text(retryLabel));
        await pumpUntil(tester, () => env.wipedCalls == 1);

        expectEverythingWiped(env);
        expect(env.log, isNot(contains('createFile tidemark/wipe-pending')));
        expect(env.exists('tidemark/installed'), isTrue);
      });
    }

    wipeTest('CA21 : une panne qui persiste laisse l\'écran sur « La '
        'suppression n\'est pas terminée », « Réessayer » reste proposé', (
      tester,
      env,
    ) async {
      env.populate();
      env.failAt('deleteAll');
      await openConfirmation(tester, env);
      await confirm(tester);
      await pumpUntil(tester, () => shown(incompleteTitle));
      await settleIo(tester);
      env.log.clear();

      await tester.tap(find.text(retryLabel));
      await pumpUntil(tester, () => env.log.contains('deleteAll'));
      await settleIo(tester);

      expect(find.text(incompleteTitle), findsOneWidget);
      expect(isEnabled(tester, retryLabel), isTrue);
      expect(find.text(cancelLabel), findsNothing);
      expect(env.wipedCalls, 0);
      expect(env.keyStore.stored, isNotNull);
    });
  });

  group('CA27 : confirmation ouverte depuis « clé introuvable »', () {
    wipeTest('CA27 : « Retour », liste adaptée et avertissement adapté', (
      tester,
      env,
    ) async {
      await openConfirmation(tester, env, keyMissing: true);

      expect(find.text(title), findsOneWidget);
      expect(find.text('Retour'), findsOneWidget);
      expect(find.text('Réglages'), findsNothing);
      expect(find.text(lead), findsOneWidget);
      expect(find.textContaining(itemEntriesNoKey), findsOneWidget);
      expect(find.textContaining(itemSettings), findsOneWidget);
      expect(find.textContaining(itemModel), findsOneWidget);
      expect(find.textContaining(itemKey), findsNothing);
      expect(find.textContaining(itemEntries), findsNothing);
      expect(find.text(warningNoKey), findsOneWidget);
      expect(find.text(warning), findsNothing);
      expect(find.text(fieldLabel), findsOneWidget);
      expect(find.text(confirmLabel), findsOneWidget);
      expect(isEnabled(tester, confirmLabel), isFalse);
      expect(find.text(cancelLabel), findsOneWidget);
    });

    wipeTest('CA27 : « Retour » ferme la confirmation, rien n\'est effacé', (
      tester,
      env,
    ) async {
      env.populate();
      await openConfirmation(tester, env, keyMissing: true);

      await tester.tap(find.text('Retour'));
      await settle(tester);

      expect(find.text(title), findsNothing);
      expect(env.log, isEmpty);
    });

    wipeTest('CA27 : après confirmation, la suppression a lieu comme en CA17', (
      tester,
      env,
    ) async {
      env.populate();
      // Clé introuvable : la base existe, sa clé n'est plus là.
      env.keyStore.stored = null;
      await openConfirmation(tester, env, keyMissing: true);

      await confirm(tester);
      await pumpUntil(tester, () => env.wipedCalls == 1);

      expectWipeSteps(env.log, wipeStepGroups);
      expectEverythingWiped(env);
    });
  });

  group('CA33 : lecteur d\'écran', () {
    wipeTest('CA33 : les boutons s\'annoncent par leur libellé, comme boutons, '
        'avec leur état', (tester, env) async {
      await openConfirmation(tester, env);

      for (final label in [confirmLabel, cancelLabel]) {
        final node = tester.getSemantics(find.text(label));
        expect(node.label, contains(label));
        expect(node.flagsCollection.isButton, isTrue, reason: label);
      }
      expect(isEnabled(tester, confirmLabel), isFalse);
      expect(isEnabled(tester, cancelLabel), isTrue);

      await typeConfirmation(tester, 'supprimer');

      expect(isEnabled(tester, confirmLabel), isTrue);
    });

    wipeTest('CA33 : le champ s\'annonce « Pour confirmer, écris SUPPRIMER »', (
      tester,
      env,
    ) async {
      await openConfirmation(tester, env);

      final node = tester.getSemantics(find.byType(TextField));

      expect(node.label, contains(fieldLabel));
      expect(node.flagsCollection.isTextField, isTrue);
    });

    wipeTest('CA33 : « Suppression… » est annoncé dès son apparition, bouton '
        'désactivé', (tester, env) async {
      env.populate();
      final gate = Completer<void>();
      env.closeBody = () => gate.future;
      await openConfirmation(tester, env);

      await confirm(tester);
      await pumpUntil(tester, () => env.log.contains('closeJournal'));

      expect(isAnnounced(tester, busyLabel), isTrue);
      expect(isEnabled(tester, busyLabel), isFalse);

      gate.complete();
      await pumpUntil(tester, () => env.wipedCalls == 1);
    });
  });

  group('CA34 : texte du système à 200 %', () {
    wipeTest('CA34 : l\'écran défile, rien ne déborde, les boutons sont '
        'atteignables, les textes entiers', (tester, env) async {
      await openConfirmation(tester, env, textScale: 2.0);

      for (final fragment in [lead, warning, fieldLabel]) {
        await scrollTo(tester, find.text(fragment));
        expect(
          paragraphOf(tester, fragment).truncated,
          isFalse,
          reason: fragment,
        );
      }
      await scrollTo(tester, find.text(confirmLabel));
      await scrollTo(tester, find.text(cancelLabel));
      expect(tester.takeException(), isNull);
    }, tall: false);

    wipeTest('CA34 : variante « clé introuvable », rien ne déborde, les '
        'boutons sont atteignables', (tester, env) async {
      await openConfirmation(tester, env, keyMissing: true, textScale: 2.0);

      await scrollTo(tester, find.text(warningNoKey));
      await scrollTo(tester, find.text(confirmLabel));
      await scrollTo(tester, find.text(cancelLabel));
      expect(tester.takeException(), isNull);
    }, tall: false);

    wipeTest('CA34 : suppression en cours, la mention est atteignable', (
      tester,
      env,
    ) async {
      env.populate();
      final gate = Completer<void>();
      env.closeBody = () => gate.future;
      await openConfirmation(tester, env, textScale: 2.0);
      await typeConfirmation(tester, 'SUPPRIMER');
      await scrollTo(tester, find.text(confirmLabel));
      await tester.tap(find.text(confirmLabel));
      await pumpUntil(tester, () => env.log.contains('closeJournal'));

      await scrollTo(tester, find.text(busyLabel));
      await scrollTo(tester, find.text(busyNote));
      expect(paragraphOf(tester, busyNote).truncated, isFalse);
      expect(tester.takeException(), isNull);

      gate.complete();
      await pumpUntil(tester, () => env.wipedCalls == 1);
    }, tall: false);

    wipeTest('CA34 : suppression interrompue, le bandeau et « Réessayer » sont '
        'atteignables', (tester, env) async {
      env.populate();
      env.failAt('deleteAll');
      await openConfirmation(tester, env, textScale: 2.0);
      await typeConfirmation(tester, 'SUPPRIMER');
      await scrollTo(tester, find.text(confirmLabel));
      await tester.tap(find.text(confirmLabel));
      await pumpUntil(tester, () => shown(incompleteTitle));
      await settleIo(tester);

      await scrollTo(tester, find.text(incompleteMessage));
      await scrollTo(tester, find.text(retryLabel));
      expect(paragraphOf(tester, incompleteMessage).truncated, isFalse);
      expect(tester.takeException(), isNull);
    }, tall: false);
  });

  group('CA35 : thème sombre', () {
    wipeTest('CA35 : « Tout supprimer définitivement » a son texte et sa '
        'bordure en danger sombre, sur surface-raised sombre, jamais un fond '
        'danger', (tester, env) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await openConfirmation(tester, env);
      await typeConfirmation(tester, 'SUPPRIMER');

      expect(
        Theme.of(tester.element(find.byType(WipeConfirmationScreen)))
            .brightness,
        Brightness.dark,
      );
      expectDangerButton(tester, confirmLabel, TidemarkColors.dark);
      expect(
        buttonColors(tester, confirmLabel).background,
        isNot(TidemarkColors.dark.danger),
      );
    });

    wipeTest('CA35 : variante « clé introuvable », même style', (
      tester,
      env,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await openConfirmation(tester, env, keyMissing: true);
      await typeConfirmation(tester, 'SUPPRIMER');

      expectDangerButton(tester, confirmLabel, TidemarkColors.dark);
    });

    wipeTest('CA35 : thème clair, le bouton est en danger clair', (
      tester,
      env,
    ) async {
      await openConfirmation(tester, env);
      await typeConfirmation(tester, 'SUPPRIMER');

      expectDangerButton(tester, confirmLabel, TidemarkColors.light);
    });

    wipeTest('CA35 : le bandeau « La suppression n\'est pas terminée » est en '
        'danger sombre', (tester, env) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      env.populate();
      env.failAt('deleteAll');
      await openConfirmation(tester, env);
      await confirm(tester);
      await pumpUntil(tester, () => shown(incompleteTitle));

      final banner = tester.widget<Text>(find.text(incompleteTitle));
      expect(banner.style?.color, TidemarkColors.dark.danger);
    });
  });
}
