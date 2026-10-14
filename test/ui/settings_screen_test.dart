// Réglages (spec 002, CA17 à CA20, CA22, CA24 à CA26) : degré de sensibilité aux
// humeurs basses.
import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/distress/distress_detector.dart';
import 'package:tidemark/ui/screens/settings_screen.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';

import '../support/distress_harness.dart';
import '../support/fake_model_downloader.dart';
import '../support/fake_settings_repository.dart';
import '../support/ui_harness.dart';

Future<void> showSettings(
  WidgetTester tester,
  FakeSettingsRepository settings, {
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    testApp(
      SettingsScreen(settings: settings, downloader: FakeModelDownloader()),
      textScale: textScale,
    ),
  );
  await settle(tester);
}

const options = [
  (LowMoodSensitivity.high, highLabel, highDetail),
  (LowMoodSensitivity.normal, normalLabel, normalDetail),
  (LowMoodSensitivity.low, lowLabel, lowDetail),
];

void main() {
  group('accès depuis la liste (CA17)', () {
    final states = <String, void Function(GuardEnv env)>{
      'avec des entrées': (env) {
        env.repo.seed(
          mood: 3,
          text: 'Journée calme.',
          createdAt: DateTime(2026, 10, 13, 8),
        );
        env.repo.seed(mood: 4, createdAt: DateTime(2026, 10, 14, 8));
      },
      'vide': (env) {},
      'en chargement': (env) => env.repo.neverEmit = true,
      'en erreur': (env) =>
          env.repo.watchError = StateError('lecture impossible'),
    };

    for (final MapEntry(key: name, value: prepare) in states.entries) {
      testWidgets('CA17 : liste $name, l\'icône « Réglages » ouvre l\'écran '
          'Réglages', (tester) async {
        usePhoneScreen(tester);
        final env = GuardEnv();
        prepare(env);
        await tester.pumpWidget(env.app());
        await settle(tester);

        final icon = find.bySemanticsLabel('Réglages');
        expect(icon, findsWidgets);
        await tester.tap(icon.first);
        await settle(tester);

        expect(find.text(settingsTitle), findsOneWidget);
        expect(find.text(settingsSection), findsOneWidget);
        expect(find.text('Nouvelle entrée'), findsNothing);
      });

      testWidgets('CA17 : liste $name, l\'icône est à côté du titre « Ton '
          'journal »', (tester) async {
        usePhoneScreen(tester);
        final env = GuardEnv();
        prepare(env);
        await tester.pumpWidget(env.app());
        await settle(tester);

        final title = tester.getRect(find.text('Ton journal'));
        final icon = tester.getRect(find.bySemanticsLabel('Réglages').first);

        expect(icon.overlaps(title), isFalse);
        expect((icon.center.dy - title.center.dy).abs(), lessThan(24));
      });
    }

    testWidgets('CA17 : l\'icône s\'annonce « Réglages » comme un bouton', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final env = GuardEnv();
      await tester.pumpWidget(env.app());
      await settle(tester);

      final node = tester.getSemantics(find.bySemanticsLabel('Réglages').first);

      expect(node.label, 'Réglages');
      expect(node.flagsCollection.isButton, isTrue);
    });

    testWidgets('CA17 : le retour « Journal » ramène à la liste', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final env = GuardEnv();
      env.repo.seed(
        mood: 3,
        text: 'Journée calme.',
        createdAt: DateTime(2026, 10, 13, 8),
      );
      await tester.pumpWidget(env.app());
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('Réglages').first);
      await settle(tester);

      await tester.tap(find.text(settingsBack));
      await settle(tester);

      expect(find.text('Ton journal'), findsOneWidget);
      expect(find.text(settingsSection), findsNothing);
      expect(find.textContaining('Journée calme'), findsOneWidget);
    });
  });

  group('contenu (CA18)', () {
    testWidgets('CA18 : titre, retour, section, présentation et mention', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await showSettings(tester, FakeSettingsRepository());

      expect(find.text(settingsTitle), findsOneWidget);
      expect(find.text(settingsBack), findsOneWidget);
      expect(find.text(settingsSection), findsOneWidget);
      expect(find.text(settingsIntro), findsOneWidget);
      expect(find.text(settingsNote), findsOneWidget);
    });

    testWidgets('CA18 : les trois degrés et leur description', (tester) async {
      usePhoneScreen(tester);
      await showSettings(tester, FakeSettingsRepository());

      for (final (_, label, detail) in options) {
        expect(find.text(label), findsOneWidget, reason: label);
        expect(find.text(detail), findsOneWidget, reason: detail);
      }
    });

    testWidgets('CA18 : sans choix, « Normale (recommandée) » est le degré '
        'choisi', (tester) async {
      usePhoneScreen(tester);
      await showSettings(tester, FakeSettingsRepository());

      expect(radioChecked(tester, normalLabel), isTrue);
      expect(radioChecked(tester, highLabel), isFalse);
      expect(radioChecked(tester, lowLabel), isFalse);
    });

    for (final (sensitivity, label, _) in options) {
      testWidgets('CA18 : le degré enregistré (${sensitivity.name}) est celui '
          'qui est coché', (tester) async {
        usePhoneScreen(tester);
        await showSettings(tester, FakeSettingsRepository(sensitivity));

        for (final (other, otherLabel, _) in options) {
          expect(
            radioChecked(tester, otherLabel),
            other == sensitivity,
            reason: '$otherLabel avec $label choisi',
          );
        }
      });
    }

    testWidgets('CA18 : aucune mention ne laisse croire qu\'on peut désactiver '
        'l\'écran d\'aide', (tester) async {
      usePhoneScreen(tester);
      await showSettings(tester, FakeSettingsRepository());

      expect(find.text(settingsNote), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      expect(find.text('Désactivé'), findsNothing);
      expect(find.text('Jamais'), findsNothing);
    });
  });

  group('choix du degré (CA19, CA20)', () {
    for (final (sensitivity, label, _) in options) {
      testWidgets('CA19 : toucher « $label » l\'enregistre aussitôt et le '
          'coche', (tester) async {
        usePhoneScreen(tester);
        // Un autre degré que celui touché au départ.
        final start = sensitivity == LowMoodSensitivity.normal
            ? LowMoodSensitivity.high
            : LowMoodSensitivity.normal;
        final settings = FakeSettingsRepository(start);
        await showSettings(tester, settings);

        await tester.tap(find.text(label));
        await settle(tester);

        expect(settings.setCalls, [sensitivity]);
        expect(settings.value, sensitivity);
        for (final (other, otherLabel, _) in options) {
          expect(radioChecked(tester, otherLabel), other == sensitivity);
        }
        expect(find.text(settingsSaveFailedTitle), findsNothing);
      });
    }

    testWidgets('CA19 : le degré est enregistré sans bouton « Enregistrer »', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await showSettings(tester, FakeSettingsRepository());

      expect(find.text(normalLabel), findsOneWidget);
      expect(find.text('Enregistrer'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('CA19 : l\'écran rouvert montre le degré enregistré', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final settings = FakeSettingsRepository();
      await showSettings(tester, settings);
      await tester.tap(find.text(lowLabel));
      await settle(tester);

      await tester.pumpWidget(const SizedBox());
      await showSettings(tester, settings);

      expect(radioChecked(tester, lowLabel), isTrue);
      expect(radioChecked(tester, normalLabel), isFalse);
    });

    testWidgets('CA19 : le choix suit les changements du dépôt', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final settings = FakeSettingsRepository();
      await showSettings(tester, settings);

      await settings.setLowMoodSensitivity(LowMoodSensitivity.high);
      await settle(tester);

      expect(radioChecked(tester, highLabel), isTrue);
      expect(radioChecked(tester, normalLabel), isFalse);
    });

    testWidgets('CA20 : si l\'enregistrement échoue, le bandeau s\'affiche et '
        'le degré précédent reste coché', (tester) async {
      usePhoneScreen(tester);
      final settings = FakeSettingsRepository()
        ..writeError = StateError('écriture impossible');
      await showSettings(tester, settings);
      expect(find.text(settingsSaveFailedTitle), findsNothing);

      await tester.tap(find.text(lowLabel));
      await settle(tester);

      expect(settings.setCalls, [LowMoodSensitivity.low]);
      expect(find.text(settingsSaveFailedTitle), findsOneWidget);
      expect(find.text(settingsSaveFailedBody), findsOneWidget);
      expect(radioChecked(tester, normalLabel), isTrue);
      expect(radioChecked(tester, lowLabel), isFalse);
      expect(settings.value, LowMoodSensitivity.normal);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CA20 : le titre du bandeau est peint avec la couleur `danger` '
        'de la charte', (tester) async {
      usePhoneScreen(tester);
      final settings = FakeSettingsRepository()
        ..writeError = StateError('écriture impossible');
      await showSettings(tester, settings);

      await tester.tap(find.text(highLabel));
      await settle(tester);

      final title = tester.renderObject<RenderParagraph>(
        find.text(settingsSaveFailedTitle),
      );
      expect(title.text.style?.color, TidemarkColors.light.danger);
      expect(
        paintedColors(tester, find.byType(SettingsScreen)),
        contains(TidemarkColors.light.danger),
      );
    });

    testWidgets('CA20 : le bandeau n\'affiche pas le texte de l\'erreur '
        'technique', (tester) async {
      usePhoneScreen(tester);
      final settings = FakeSettingsRepository()
        ..writeError = StateError('écriture impossible');
      await showSettings(tester, settings);

      await tester.tap(find.text(highLabel));
      await settle(tester);

      expect(find.textContaining('impossible'), findsNothing);
      expect(find.textContaining('StateError'), findsNothing);
    });
  });

  group('chargement (CA22)', () {
    testWidgets('CA22 : pendant la lecture, seuls le retour « Journal » et le '
        'titre sont visibles', (tester) async {
      usePhoneScreen(tester);
      final settings = FakeSettingsRepository()..neverEmit = true;
      await showSettings(tester, settings);

      expect(find.text(settingsBack), findsOneWidget);
      expect(find.text(settingsTitle), findsOneWidget);
      expect(find.text(settingsSection), findsNothing);
      expect(find.text(settingsIntro), findsNothing);
      expect(find.text(settingsNote), findsNothing);
      for (final (_, label, detail) in options) {
        expect(find.text(label), findsNothing);
        expect(find.text(detail), findsNothing);
      }
      expect(
        allTextsOfScreen(tester, SettingsScreen),
        unorderedEquals([settingsTitle, settingsBack]),
      );
    });

    testWidgets('CA22 : pendant la lecture, aucun indicateur de progression '
        'n\'est affiché', (tester) async {
      usePhoneScreen(tester);
      final settings = FakeSettingsRepository()..neverEmit = true;
      await showSettings(tester, settings);

      expect(find.text(settingsTitle), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  // Ajouté après la revue de code (spec 002, cas limites : lecture du degré
  // impossible dans l'écran Réglages).
  testWidgets('lecture du degré impossible : « Normale » est coché et un choix '
      'reste possible', (tester) async {
    usePhoneScreen(tester);
    final settings = FakeSettingsRepository()
      ..readError = StateError('lecture impossible');
    await showSettings(tester, settings);

    expect(radioChecked(tester, normalLabel), isTrue);
    await tester.tap(find.text(highLabel));
    await settle(tester);
    expect(settings.setCalls, [LowMoodSensitivity.high]);
    // Ajouté après la revue IA : l'écran montre le degré enregistré, pas
    // « Normale », même si la lecture reste en échec.
    expect(radioChecked(tester, highLabel), isTrue);
    expect(radioChecked(tester, normalLabel), isFalse);
  });

  group('accessibilité (CA24)', () {
    for (final (sensitivity, label, detail) in options) {
      testWidgets('CA24 : « $label » s\'annonce comme un bouton radio avec '
          'son nom, sa description et son état', (tester) async {
        usePhoneScreen(tester);
        await showSettings(tester, FakeSettingsRepository());

        final node = tester.getSemantics(find.text(label));

        expect(node.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
        expect(node.label, contains(label));
        expect(node.label, contains(detail));
        expect(
          node.flagsCollection.isChecked,
          sensitivity == LowMoodSensitivity.normal
              ? CheckedState.isTrue
              : CheckedState.isFalse,
        );
      });
    }

    testWidgets('CA24 : après un choix, l\'état annoncé change', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await showSettings(tester, FakeSettingsRepository());

      await tester.tap(find.text(highLabel));
      await settle(tester);

      expect(
        tester.getSemantics(find.text(highLabel)).flagsCollection.isChecked,
        CheckedState.isTrue,
      );
      expect(
        tester.getSemantics(find.text(normalLabel)).flagsCollection.isChecked,
        CheckedState.isFalse,
      );
    });

    testWidgets('CA24 : le retour « Journal » s\'annonce comme un bouton', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await showSettings(tester, FakeSettingsRepository());

      expect(
        tester.getSemantics(find.text(settingsBack)).flagsCollection.isButton,
        isTrue,
      );
    });
  });

  group('texte du système à 200 % (CA25)', () {
    testWidgets('CA25 : Réglages ne déborde pas et aucun texte n\'est '
        'tronqué', (tester) async {
      usePhoneScreen(tester);
      await showSettings(tester, FakeSettingsRepository(), textScale: 2.0);

      expect(tester.takeException(), isNull);
      expect(find.text(settingsSection), findsOneWidget);
      expectNoTruncatedText(
        tester,
        find.byType(SettingsScreen),
        'réglages à 200 %',
      );
    });

    testWidgets('CA25 : les trois degrés et la mention restent atteignables et '
        'un degré se choisit', (tester) async {
      usePhoneScreen(tester);
      final settings = FakeSettingsRepository();
      await showSettings(tester, settings, textScale: 2.0);

      await tester.scrollUntilVisible(find.text(settingsNote), 100);
      await tester.ensureVisible(find.text(lowLabel));
      await tester.pump();
      await tester.tap(find.text(lowLabel));
      await settle(tester);

      expect(settings.value, LowMoodSensitivity.low);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CA25 : avec le bandeau d\'erreur, rien ne déborde', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final settings = FakeSettingsRepository()
        ..writeError = StateError('écriture impossible');
      await showSettings(tester, settings, textScale: 2.0);

      await tester.ensureVisible(find.text(highLabel));
      await tester.pump();
      await tester.tap(find.text(highLabel));
      await settle(tester);

      expect(find.text(settingsSaveFailedTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
      expectNoTruncatedText(
        tester,
        find.byType(SettingsScreen),
        'réglages en erreur',
      );
    });
  });

  group('thème sombre (CA26)', () {
    void useDarkSystem(WidgetTester tester) {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    }

    testWidgets('CA26 : Réglages utilise les couleurs sombres de la charte', (
      tester,
    ) async {
      usePhoneScreen(tester);
      useDarkSystem(tester);
      await showSettings(tester, FakeSettingsRepository());

      final scaffold = find.ancestor(
        of: find.text(settingsTitle),
        matching: find.byType(Scaffold),
      );
      final background = tester
          .widget<Material>(
            find
                .descendant(of: scaffold, matching: find.byType(Material))
                .first,
          )
          .color;
      expect(background, TidemarkColors.dark.surface);
      final title = tester.renderObject<RenderParagraph>(
        find.text(settingsTitle),
      );
      expect(title.text.style?.color, TidemarkColors.dark.ink);
      final colors = paintedColors(tester, find.byType(SettingsScreen));
      expect(colors, contains(TidemarkColors.dark.tideSoft));
      expect(colors, isNot(contains(TidemarkColors.light.surface)));
      expect(colors, isNot(contains(TidemarkColors.light.ink)));
      expect(colors, isNot(contains(TidemarkColors.light.tideSoft)));
    });

    testWidgets('CA26 : le bandeau d\'erreur utilise la couleur `danger` du '
        'thème sombre', (tester) async {
      usePhoneScreen(tester);
      useDarkSystem(tester);
      final settings = FakeSettingsRepository()
        ..writeError = StateError('écriture impossible');
      await showSettings(tester, settings);

      await tester.tap(find.text(highLabel));
      await settle(tester);

      final title = tester.renderObject<RenderParagraph>(
        find.text(settingsSaveFailedTitle),
      );
      expect(title.text.style?.color, TidemarkColors.dark.danger);
    });
  });
}
