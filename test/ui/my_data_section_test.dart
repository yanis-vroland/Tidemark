// Section « Mes données » des Réglages (spec 005 ; CA1, CA2, CA3, CA9, CA11, CA12,
// CA13, CA33 à CA35) : export sur l'appui de la personne, états du bouton, erreurs.
// Vrais fichiers dans un dossier temporaire, feuille de partage factice.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/ui/screens/settings_screen.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';

import '../support/fake_model_downloader.dart';
import '../support/fake_settings_repository.dart';
import '../support/ui_harness.dart';
import '../support/wipe_harness.dart';

const intro =
    'Tout reste sur ce téléphone. Tu peux en faire une copie, ou tout effacer.';
const exportLabel = 'Exporter mes données';
const exportMention =
    "Un fichier JSON avec toutes tes entrées et leurs étiquettes. Il n'est pas "
    "chiffré : choisis bien où tu l'envoies.";
const emptyMention = "Ton journal est vide : il n'y a rien à exporter.";
const busyLabel = "Préparation de l'export…";
const retryLabel = "Réessayer l'export";
const failTitle = "L'export n'a pas abouti";
const failMessage =
    "Aucun fichier n'a été partagé. Vérifie la place libre sur le téléphone, "
    'puis réessaie.';
const wipeLabel = 'Tout supprimer';
const wipeMention =
    'Efface définitivement tes entrées, tes réglages, la clé de ton journal et '
    "le modèle d'IA téléchargé.";

Future<void> showSettings(
  WidgetTester tester,
  DataEnv env, {
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(env.settingsScreen(textScale: textScale));
  await settle(tester);
}

bool shown(String text) => find.text(text).evaluate().isNotEmpty;

double top(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  group('CA1 : la section « Mes données »', () {
    dataTest('CA1 : sous « Écran d\'aide », avec la phrase, les deux boutons '
        'et leurs mentions, dans cet ordre', (tester, env) async {
      await showSettings(tester, env);

      for (final text in [
        'Mes données',
        intro,
        exportLabel,
        exportMention,
        wipeLabel,
        wipeMention,
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      final order = [
        top(tester, "Écran d'aide"),
        top(tester, 'Mes données'),
        top(tester, intro),
        top(tester, exportLabel),
        top(tester, exportMention),
        top(tester, wipeLabel),
        top(tester, wipeMention),
      ];
      expect(order, [...order]..sort(), reason: 'ordre vertical des éléments');
      expect(order.toSet(), hasLength(order.length));
    });

    dataTest('CA1 : « Mes données » est un titre de section', (
      tester,
      env,
    ) async {
      await showSettings(tester, env);

      expect(
        tester.getSemantics(find.text('Mes données')).flagsCollection.isHeader,
        isTrue,
      );
    });

    dataTest('CA1 : « Tout supprimer » est en danger (texte et bordure), sur '
        'surface-raised, thème clair', (tester, env) async {
      await showSettings(tester, env);

      expectDangerButton(tester, wipeLabel, TidemarkColors.light);
    });

    dataTest('CA1 : les deux boutons sont actifs quand le journal a des '
        'entrées', (tester, env) async {
      await showSettings(tester, env);

      expect(isEnabled(tester, exportLabel), isTrue);
      expect(isEnabled(tester, wipeLabel), isTrue);
    });

    testWidgets('CA1 : sans DataActions, aucune section « Mes données »', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(
        testApp(
          SettingsScreen(
            settings: FakeSettingsRepository(),
            downloader: FakeModelDownloader(readyModel),
          ),
        ),
      );
      await settle(tester);

      expect(find.text('Mes données'), findsNothing);
    });
  });

  group('CA2 : lecture des réglages en cours', () {
    dataTest('CA2 : tant que le degré n\'est pas lu, la section n\'est pas '
        'visible', (tester, env) async {
      env.settings.watchGate = Completer<void>();

      await showSettings(tester, env);

      expect(find.text('Mes données'), findsNothing);
      expect(find.text(exportLabel), findsNothing);
      expect(find.text(wipeLabel), findsNothing);

      // Le degré est lu : la section apparaît.
      env.settings.watchGate!.complete();
      await settle(tester);

      expect(find.text('Mes données'), findsOneWidget);
      expect(find.text(exportLabel), findsOneWidget);
      expect(find.text(wipeLabel), findsOneWidget);
    });
  });

  group('CA3 : export en cours', () {
    dataTest('CA3 : un appui prépare l\'export : « Préparation de l\'export… » '
        'désactivé, « Tout supprimer » désactivé, retour sans effet, puis la '
        'feuille s\'ouvre avec un seul fichier', (tester, env) async {
      env.settings.readGate = Completer<void>();
      env.sheet.hold = Completer<void>();
      await tester.pumpWidget(env.settingsOnTop());
      await tester.tap(find.text('Ouvrir'));
      await settle(tester);

      await tester.tap(find.text(exportLabel));
      await pumpUntil(tester, () => shown(busyLabel));

      expect(find.text(exportLabel), findsNothing);
      expect(isEnabled(tester, busyLabel), isFalse);
      expect(isEnabled(tester, wipeLabel), isFalse);
      expect(
        env.sheet.shared,
        isEmpty,
        reason: 'la feuille n\'est pas ouverte',
      );

      // Un geste de retour ne fait rien.
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('Réglages'), findsOneWidget);
      expect(shown(busyLabel), isTrue);

      env.settings.readGate!.complete();
      await pumpUntil(tester, () => env.sheet.shared.isNotEmpty);

      expect(env.sheet.shared, hasLength(1));
      expect(
        env.sheet.shared.single.name,
        'tidemark-export-2026-10-14-2152.json',
      );
      expect(env.sheet.shared.single.mimeType, 'application/json');

      // La feuille est ouverte : le bouton reste occupé, le retour sans effet.
      expect(shown(busyLabel), isTrue);
      expect(isEnabled(tester, wipeLabel), isFalse);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('Réglages'), findsOneWidget);

      env.sheet.hold!.complete();
      await pumpUntil(tester, () => shown(exportLabel));
    });

    dataTest('CA3 : le fichier remis à la feuille est le JSON de l\'export', (
      tester,
      env,
    ) async {
      await showSettings(tester, env);

      await tester.tap(find.text(exportLabel));
      await pumpUntil(tester, () => env.sheet.shared.isNotEmpty);

      final json = jsonDecode(env.sheet.shared.single.content) as Map;
      expect(json['formatVersion'], 2);
      expect((json['settings'] as Map)['lowMoodSensitivity'], 'high');
      expect(json['entries'], hasLength(1));
      await pumpUntil(tester, () => shown(exportLabel));
    });
  });

  group('CA9 : la feuille se ferme', () {
    dataTest('CA9 : fichier effacé, aucun message, les deux boutons '
        'reviennent à leur état normal', (tester, env) async {
      env.sheet.hold = Completer<void>();
      await showSettings(tester, env);
      await tester.tap(find.text(exportLabel));
      await pumpUntil(tester, () => env.sheet.shared.isNotEmpty);
      expect(
        env.wipe.contents(Directory('${env.wipe.cache.path}/tidemark-export')),
        isNotEmpty,
        reason: 'le fichier existe tant que la feuille est ouverte',
      );

      env.sheet.hold!.complete();
      await pumpUntil(tester, () => shown(exportLabel));
      await settleIo(tester);

      expect(env.wipe.exportLeftovers(), isEmpty);
      expect(find.text(failTitle), findsNothing);
      expect(find.text(busyLabel), findsNothing);
      expect(isEnabled(tester, exportLabel), isTrue);
      expect(isEnabled(tester, wipeLabel), isTrue);
      expect(find.text(exportMention), findsOneWidget);
    });
  });

  group('CA11 : erreur pendant l\'export', () {
    final failures = <String, (void Function(DataEnv), void Function(DataEnv))>{
      'lecture des entrées': (
        (env) => env.entries.allEntriesError = StateError('base illisible'),
        (env) => env.entries.allEntriesError = null,
      ),
      'lecture du réglage': (
        (env) => env.settings.readError = StateError('réglage illisible'),
        (env) => env.settings.readError = null,
      ),
      'écriture du fichier': (
        // Le cache est un fichier ordinaire : aucun dossier ne peut y être créé.
        (env) => File(env.wipe.cache.path).writeAsStringSync('bloque'),
        (env) => File(env.wipe.cache.path).deleteSync(),
      ),
      'ouverture de la feuille de partage': (
        (env) => env.sheet.error = StateError('aucune feuille'),
        (env) => env.sheet.error = null,
      ),
    };

    for (final MapEntry(key: name, value: (fail, repair)) in failures.entries) {
      dataTest('CA11 : $name en échec : bandeau, « Réessayer l\'export », '
          'aucun fichier temporaire, puis un nouvel essai réussit', (
        tester,
        env,
      ) async {
        await showSettings(tester, env);
        fail(env);

        await tester.tap(find.text(exportLabel));
        await pumpUntil(tester, () => shown(failTitle));
        await settleIo(tester);

        expect(find.text(failMessage), findsOneWidget);
        expect(find.text(retryLabel), findsOneWidget);
        expect(find.text(exportLabel), findsNothing);
        expect(find.text(busyLabel), findsNothing);
        expect(isEnabled(tester, retryLabel), isTrue);
        expect(env.wipe.exportLeftovers(), isEmpty);

        repair(env);
        env.sheet.shared.clear();
        await tester.tap(find.text(retryLabel));
        await pumpUntil(tester, () => shown(exportLabel));

        expect(env.sheet.shared, hasLength(1));
        expect(find.text(failTitle), findsNothing);
        expect(find.text(failMessage), findsNothing);
        expect(env.wipe.exportLeftovers(), isEmpty);
      });
    }

    dataTest('CA11 : le bandeau d\'erreur est annoncé dès son apparition', (
      tester,
      env,
    ) async {
      await showSettings(tester, env);
      env.entries.allEntriesError = StateError('base illisible');

      await tester.tap(find.text(exportLabel));
      await pumpUntil(tester, () => shown(failTitle));

      expect(isAnnounced(tester, failTitle), isTrue);
    });

    dataTest('CA11 : après une erreur, « Tout supprimer » reste utilisable', (
      tester,
      env,
    ) async {
      await showSettings(tester, env);
      env.entries.allEntriesError = StateError('base illisible');

      await tester.tap(find.text(exportLabel));
      await pumpUntil(tester, () => shown(failTitle));

      expect(isEnabled(tester, wipeLabel), isTrue);
    });
  });

  group('CA12 : journal vide', () {
    dataTest('CA12 : « Exporter mes données » est désactivé, la mention '
        'devient « Ton journal est vide »', (tester, env) async {
      await showSettings(tester, env);

      expect(isEnabled(tester, exportLabel), isFalse);
      expect(find.text(emptyMention), findsOneWidget);
      expect(find.text(exportMention), findsNothing);
      expect(isEnabled(tester, wipeLabel), isTrue);
    }, seed: false);

    dataTest(
      'CA12 : un appui sur le bouton désactivé n\'ouvre pas la feuille',
      (tester, env) async {
        await showSettings(tester, env);

        await tester.tap(find.text(exportLabel), warnIfMissed: false);
        await settleIo(tester);

        expect(env.sheet.shared, isEmpty);
        expect(find.text(busyLabel), findsNothing);
      },
      seed: false,
    );

    dataTest('CA12 : avec une entrée, la mention habituelle est affichée', (
      tester,
      env,
    ) async {
      await showSettings(tester, env);

      expect(find.text(exportMention), findsOneWidget);
      expect(find.text(emptyMention), findsNothing);
    });
  });

  group('CA13 : l\'export n\'a lieu que sur l\'appui', () {
    dataTest('CA13 : ouvrir les Réglages n\'ouvre pas la feuille et n\'écrit '
        'aucun fichier', (tester, env) async {
      await showSettings(tester, env);
      await settleIo(tester);

      expect(find.text(exportLabel), findsOneWidget);
      expect(env.sheet.shared, isEmpty);
      expect(env.wipe.cache.existsSync(), isFalse);
    });

    dataTest('CA13 : un appui sur « Exporter mes données » ouvre la feuille '
        'une seule fois', (tester, env) async {
      await showSettings(tester, env);

      await tester.tap(find.text(exportLabel));
      await pumpUntil(tester, () => env.sheet.shared.isNotEmpty);
      await pumpUntil(tester, () => shown(exportLabel));
      await settleIo(tester);

      expect(env.sheet.shared, hasLength(1));
    });
  });

  group('CA33 : lecteur d\'écran', () {
    dataTest('CA33 : les boutons s\'annoncent par leur libellé, comme boutons, '
        'avec leur état', (tester, env) async {
      await showSettings(tester, env);

      for (final label in [exportLabel, wipeLabel]) {
        final node = tester.getSemantics(find.text(label));
        expect(node.label, contains(label));
        expect(node.flagsCollection.isButton, isTrue, reason: label);
        expect(isEnabled(tester, label), isTrue, reason: label);
      }
    });

    dataTest('CA33 : journal vide, le bouton d\'export s\'annonce désactivé', (
      tester,
      env,
    ) async {
      await showSettings(tester, env);

      final node = tester.getSemantics(find.text(exportLabel));
      expect(node.flagsCollection.isButton, isTrue);
      expect(isEnabled(tester, exportLabel), isFalse);
    }, seed: false);

    dataTest('CA33 : « Préparation de l\'export… » est annoncé dès son '
        'apparition, bouton désactivé', (tester, env) async {
      env.settings.readGate = Completer<void>();
      await showSettings(tester, env);

      await tester.tap(find.text(exportLabel));
      await pumpUntil(tester, () => shown(busyLabel));

      expect(isAnnounced(tester, busyLabel), isTrue);
      expect(isEnabled(tester, busyLabel), isFalse);
      expect(isEnabled(tester, wipeLabel), isFalse);

      env.settings.readGate!.complete();
      await pumpUntil(tester, () => shown(exportLabel));
    });
  });

  group('CA34 : texte du système à 200 %', () {
    dataTest('CA34 : l\'écran défile, rien ne déborde, les deux boutons et '
        'leurs mentions sont atteignables et entiers', (tester, env) async {
      await showSettings(tester, env, textScale: 2.0);

      for (final label in [exportLabel, wipeLabel]) {
        await scrollTo(tester, find.text(label));
      }
      for (final fragment in [intro, exportMention, wipeMention]) {
        await scrollTo(tester, find.text(fragment));
        expect(
          paragraphOf(tester, fragment).truncated,
          isFalse,
          reason: fragment,
        );
      }
      expect(tester.takeException(), isNull);
    }, tall: false);

    dataTest(
      'CA34 : journal vide, la mention et le bouton sont atteignables',
      (tester, env) async {
        await showSettings(tester, env, textScale: 2.0);

        await scrollTo(tester, find.text(emptyMention));
        await scrollTo(tester, find.text(wipeLabel));
        expect(tester.takeException(), isNull);
      },
      seed: false,
      tall: false,
    );

    dataTest('CA34 : en erreur, le bandeau et « Réessayer l\'export » sont '
        'atteignables', (tester, env) async {
      await showSettings(tester, env, textScale: 2.0);
      env.entries.allEntriesError = StateError('base illisible');
      await scrollTo(tester, find.text(exportLabel));

      await tester.tap(find.text(exportLabel));
      await pumpUntil(tester, () => shown(failTitle));

      await scrollTo(tester, find.text(failMessage));
      await scrollTo(tester, find.text(retryLabel));
      expect(paragraphOf(tester, failMessage).truncated, isFalse);
      expect(tester.takeException(), isNull);
    }, tall: false);
  });

  group('CA35 : thème sombre', () {
    dataTest('CA35 : « Tout supprimer » a son texte et sa bordure en danger '
        'sombre, sur surface-raised sombre, jamais un fond danger', (
      tester,
      env,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;

      await showSettings(tester, env);

      expect(
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.dark,
      );
      expectDangerButton(tester, wipeLabel, TidemarkColors.dark);
      expect(
        buttonColors(tester, wipeLabel).background,
        isNot(TidemarkColors.dark.danger),
      );
    });

    dataTest('CA35 : le bandeau d\'erreur de l\'export est en danger sombre', (
      tester,
      env,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await showSettings(tester, env);
      env.entries.allEntriesError = StateError('base illisible');

      await tester.tap(find.text(exportLabel));
      await pumpUntil(tester, () => shown(failTitle));

      final title = tester.widget<Text>(find.text(failTitle));
      expect(title.style?.color, TidemarkColors.dark.danger);
    });
  });
}
