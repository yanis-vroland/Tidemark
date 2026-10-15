import 'package:characters/characters.dart';

import '../support/fake_settings_repository.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/main.dart';
import 'package:tidemark/ui/screens/entry_form_screen.dart';

import '../support/fake_entry_repository.dart';
import '../support/fake_model_downloader.dart';
import '../support/ui_harness.dart';

const emptyListTitle = 'Ta première entrée apparaîtra ici';

/// Texte de [length] caractères, tous différents d'un voisin à l'autre, pour vérifier
/// que ce sont bien les premiers caractères qui sont gardés.
String sampleText(int length) =>
    String.fromCharCodes(List.generate(length, (i) => 97 + i % 26));

Future<void> enter(WidgetTester tester, String text) async {
  await tester.enterText(textInput, text);
  await tester.pump();
}

Future<void> expectBackOnList(WidgetTester tester) async {
  expect(find.text('Ton journal'), findsOneWidget);
  expect(find.text('Nouvelle entrée'), findsOneWidget);
  expect(find.text('Comment ça va ?'), findsNothing);
}

void main() {
  group('écran de saisie seul', () {
    dbTestWidgets('CA7 : sans humeur, « Enregistrer » est désactivé et l\'aide '
        's\'affiche', (tester, env) async {
      await tester.pumpWidget(
        testApp(
          EntryFormScreen(
            repository: env.repo,
            settings: FakeSettingsRepository(),
            downloader: FakeModelDownloader(readyModel),
          ),
        ),
      );
      await settle(tester);

      expect(find.text('Comment ça va ?'), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
      expect(isEnabled(tester, 'Enregistrer'), isFalse);
      expect(find.text('Choisis une humeur pour enregistrer.'), findsOneWidget);
    });

    dbTestWidgets('CA7 : toucher « Enregistrer » sans humeur n\'enregistre '
        'rien', (tester, env) async {
      await tester.pumpWidget(
        testApp(
          EntryFormScreen(
            repository: env.repo,
            settings: FakeSettingsRepository(),
            downloader: FakeModelDownloader(readyModel),
          ),
        ),
      );
      await settle(tester);
      await enter(tester, 'Un texte, mais pas d\'humeur.');

      await tester.tap(find.text('Enregistrer'), warnIfMissed: false);
      await settle(tester);

      expect(await tester.runAsync(env.db.countEntries), 0);
    });

    dbTestWidgets('CA8 : toucher une pastille choisit cette humeur, affiche '
        'son libellé et active « Enregistrer »', (tester, env) async {
      await tester.pumpWidget(
        testApp(
          EntryFormScreen(
            repository: env.repo,
            settings: FakeSettingsRepository(),
            downloader: FakeModelDownloader(readyModel),
          ),
        ),
      );
      await settle(tester);

      await pickMood(tester, 4);

      expect(isChosen(tester, 4), isTrue);
      expect(find.text('Bien'), findsOneWidget);
      expect(isEnabled(tester, 'Enregistrer'), isTrue);
      expect(find.text('Choisis une humeur pour enregistrer.'), findsNothing);
    });

    dbTestWidgets('CA8 : une seule humeur à la fois', (tester, env) async {
      await tester.pumpWidget(
        testApp(
          EntryFormScreen(
            repository: env.repo,
            settings: FakeSettingsRepository(),
            downloader: FakeModelDownloader(readyModel),
          ),
        ),
      );
      await settle(tester);

      await pickMood(tester, 4);
      await pickMood(tester, 2);

      expect(isChosen(tester, 2), isTrue);
      expect(isChosen(tester, 4), isFalse);
      for (final other in [1, 3, 5]) {
        expect(isChosen(tester, other), isFalse);
      }
      expect(find.text('Bas'), findsOneWidget);
      expect(find.text('Bien'), findsNothing);
    });

    dbTestWidgets('CA8 : les cinq pastilles portent leur chiffre', (
      tester,
      env,
    ) async {
      await tester.pumpWidget(
        testApp(
          EntryFormScreen(
            repository: env.repo,
            settings: FakeSettingsRepository(),
            downloader: FakeModelDownloader(readyModel),
          ),
        ),
      );
      await settle(tester);

      for (var mood = 1; mood <= 5; mood++) {
        expect(find.text('$mood'), findsOneWidget);
      }
    });

    dbTestWidgets('CA12 : le champ garde 2 000 caractères quand on en tape un '
        'de plus', (tester, env) async {
      await tester.pumpWidget(
        testApp(
          EntryFormScreen(
            repository: env.repo,
            settings: FakeSettingsRepository(),
            downloader: FakeModelDownloader(readyModel),
          ),
        ),
      );
      await settle(tester);
      final full = sampleText(maxTextLength);
      await enter(tester, full);
      expect(inputText(tester), full);

      await enter(tester, '${full}Z');

      expect(inputText(tester), full);
    });

    dbTestWidgets(
      'CA12 : un texte collé plus long est coupé aux 2 000 premiers '
      'caractères',
      (tester, env) async {
        await tester.pumpWidget(
          testApp(
            EntryFormScreen(
              repository: env.repo,
              settings: FakeSettingsRepository(),
              downloader: FakeModelDownloader(readyModel),
            ),
          ),
        );
        await settle(tester);
        final pasted = sampleText(2600);

        await enter(tester, pasted);

        expect(inputText(tester), pasted.substring(0, maxTextLength));
      },
    );

    dbTestWidgets('CA12 : les émoji comptent comme des caractères visibles', (
      tester,
      env,
    ) async {
      await tester.pumpWidget(
        testApp(
          EntryFormScreen(
            repository: env.repo,
            settings: FakeSettingsRepository(),
            downloader: FakeModelDownloader(readyModel),
          ),
        ),
      );
      await settle(tester);

      await enter(tester, '😀' * (maxTextLength + 5));

      expect(inputText(tester).runes.length, maxTextLength);
    });

    dbTestWidgets('CA12 : un drapeau compte pour un caractère, dans le champ '
        'comme dans le compteur', (tester, env) async {
      await tester.pumpWidget(
        testApp(
          EntryFormScreen(
            repository: env.repo,
            settings: FakeSettingsRepository(),
            downloader: FakeModelDownloader(readyModel),
          ),
        ),
      );
      await settle(tester);

      await enter(tester, '🇫🇷' * (maxTextLength + 100));

      expect(inputText(tester).characters.length, maxTextLength);
      expect(find.text('2 000 / 2 000'), findsOneWidget);
    });

    dbTestWidgets('CA12 : à 1 850 caractères, le compteur « 1 850 / 2 000 » '
        's\'affiche', (tester, env) async {
      await tester.pumpWidget(
        testApp(
          EntryFormScreen(
            repository: env.repo,
            settings: FakeSettingsRepository(),
            downloader: FakeModelDownloader(readyModel),
          ),
        ),
      );
      await settle(tester);

      await enter(tester, sampleText(1850));

      expect(find.text('1 850 / 2 000'), findsOneWidget);
    });

    dbTestWidgets('CA12 : le compteur apparaît à 1 800 caractères et pas '
        'avant', (tester, env) async {
      await tester.pumpWidget(
        testApp(
          EntryFormScreen(
            repository: env.repo,
            settings: FakeSettingsRepository(),
            downloader: FakeModelDownloader(readyModel),
          ),
        ),
      );
      await settle(tester);

      await enter(tester, sampleText(1799));
      expect(find.textContaining('/ 2 000'), findsNothing);

      await enter(tester, sampleText(1800));
      expect(find.text('1 800 / 2 000'), findsOneWidget);
    });

    dbTestWidgets('CA12 : sans texte, aucun compteur', (tester, env) async {
      await tester.pumpWidget(
        testApp(
          EntryFormScreen(
            repository: env.repo,
            settings: FakeSettingsRepository(),
            downloader: FakeModelDownloader(readyModel),
          ),
        ),
      );
      await settle(tester);

      expect(find.textContaining('/ 2 000'), findsNothing);
    });

    dbTestWidgets('CA12 : à 2 000 caractères, le compteur affiche '
        '« 2 000 / 2 000 »', (tester, env) async {
      await tester.pumpWidget(
        testApp(
          EntryFormScreen(
            repository: env.repo,
            settings: FakeSettingsRepository(),
            downloader: FakeModelDownloader(readyModel),
          ),
        ),
      );
      await settle(tester);

      await enter(tester, sampleText(maxTextLength));

      expect(find.text('2 000 / 2 000'), findsOneWidget);
    });

    dbTestWidgets('CA26 : chaque pastille s\'annonce « Humeur N sur 5 : '
        'libellé »', (tester, env) async {
      await tester.pumpWidget(
        testApp(
          EntryFormScreen(
            repository: env.repo,
            settings: FakeSettingsRepository(),
            downloader: FakeModelDownloader(readyModel),
          ),
        ),
      );
      await settle(tester);

      expect(find.bySemanticsLabel('Humeur 4 sur 5 : Bien'), findsOneWidget);
      for (var mood = 1; mood <= 5; mood++) {
        expect(
          find.bySemanticsLabel(moodSemantics(mood)),
          findsOneWidget,
          reason: moodSemantics(mood),
        );
      }
    });

    dbTestWidgets('CA26 : la pastille choisie s\'annonce comme choisie, les '
        'autres non', (tester, env) async {
      await tester.pumpWidget(
        testApp(
          EntryFormScreen(
            repository: env.repo,
            settings: FakeSettingsRepository(),
            downloader: FakeModelDownloader(readyModel),
          ),
        ),
      );
      await settle(tester);
      for (var mood = 1; mood <= 5; mood++) {
        expect(isChosen(tester, mood), isFalse, reason: 'avant le choix');
      }

      await pickMood(tester, 4);

      expect(isChosen(tester, 4), isTrue);
      expect(isChosen(tester, 3), isFalse);
    });
  });

  group('parcours depuis la liste', () {
    dbTestWidgets('CA9 : une humeur sans texte est enregistrée, la liste '
        'réapparaît avec l\'entrée en tête sous « Aujourd\'hui »', (
      tester,
      env,
    ) async {
      await tester.pumpWidget(env.app());
      await settle(tester);
      await openForm(tester);
      expect(find.text('Comment ça va ?'), findsOneWidget);

      await pickMood(tester, 4);
      await tester.tap(find.text('Enregistrer'));
      await settle(tester);

      await expectBackOnList(tester);
      expect(find.text("Aujourd'hui"), findsOneWidget);
      expect(find.text('Bien'), findsOneWidget);
      expect(find.text('21:40'), findsOneWidget);
      final saved = await env.entries(tester);
      expect(saved, hasLength(1));
      expect(saved.single.mood, 4);
      expect(saved.single.text, isNull);
      expect(saved.single.createdAt, fixedNow.toUtc());
      expect(saved.single.analysisStatus, AnalysisStatus.skipped);
    });

    dbTestWidgets('CA9 : la nouvelle entrée passe devant les plus '
        'anciennes', (tester, env) async {
      await env.add(tester, DateTime(2026, 10, 14, 8, 15), 3);
      await tester.pumpWidget(env.app());
      await settle(tester);
      await openForm(tester);

      await pickMood(tester, 5);
      await tester.tap(find.text('Enregistrer'));
      await settle(tester);

      expect(find.text("Aujourd'hui"), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('21:40')).dy,
        lessThan(tester.getTopLeft(find.text('08:15')).dy),
      );
    });

    dbTestWidgets('CA9 : passage de minuit, l\'heure retenue est celle de '
        'l\'appui sur « Enregistrer »', (tester, env) async {
      env.now = DateTime(2026, 10, 14, 23, 58);
      await tester.pumpWidget(env.app());
      await settle(tester);
      await openForm(tester);
      await pickMood(tester, 3);

      env.now = DateTime(2026, 10, 15, 0, 2);
      await tester.tap(find.text('Enregistrer'));
      await settle(tester);

      final saved = await env.entries(tester);
      expect(saved.single.createdAt, DateTime(2026, 10, 15, 0, 2).toUtc());
      expect(find.text("Aujourd'hui"), findsOneWidget);
      expect(find.text('00:02'), findsOneWidget);
    });

    dbTestWidgets('CA10 : une humeur et un texte sont enregistrés, la carte '
        'montre le début du texte', (tester, env) async {
      await tester.pumpWidget(env.app());
      await settle(tester);
      await openForm(tester);

      await pickMood(tester, 5);
      await enter(tester, "Balade au bord de l'eau, le vent était tombé.");
      await tester.tap(find.text('Enregistrer'));
      await settle(tester);

      await expectBackOnList(tester);
      expect(find.textContaining('Balade au bord de l'), findsOneWidget);
      final saved = await env.entries(tester);
      expect(
        saved.single.text,
        "Balade au bord de l'eau, le vent était tombé.",
      );
      expect(saved.single.analysisStatus, AnalysisStatus.pending);
    });

    dbTestWidgets('CA11 : un texte d\'espaces et de retours à la ligne est '
        'enregistré sans texte', (tester, env) async {
      await tester.pumpWidget(env.app());
      await settle(tester);
      await openForm(tester);

      await pickMood(tester, 2);
      await enter(tester, '  \n \n   ');
      await tester.tap(find.text('Enregistrer'));
      await settle(tester);

      await expectBackOnList(tester);
      final saved = await env.entries(tester);
      expect(saved.single.text, isNull);
      expect(saved.single.analysisStatus, AnalysisStatus.skipped);
      expect(emptyText, findsNothing);
    });

    dbTestWidgets('CA13 : « Annuler » sans texte et sans humeur ramène à la '
        'liste, sans rien enregistrer', (tester, env) async {
      await tester.pumpWidget(env.app());
      await settle(tester);
      await openForm(tester);

      await tester.tap(find.text('Annuler'));
      await settle(tester);

      await expectBackOnList(tester);
      expect(find.text('Abandonner cette entrée ?'), findsNothing);
      expect(find.text(emptyListTitle), findsOneWidget);
      expect(await tester.runAsync(env.db.countEntries), 0);
    });

    dbTestWidgets('CA13 : « Annuler » avec une humeur choisie mais sans '
        'texte ramène à la liste, sans confirmation ni enregistrement', (
      tester,
      env,
    ) async {
      await tester.pumpWidget(env.app());
      await settle(tester);
      await openForm(tester);
      await pickMood(tester, 4);

      await tester.tap(find.text('Annuler'));
      await settle(tester);

      await expectBackOnList(tester);
      expect(find.text('Abandonner cette entrée ?'), findsNothing);
      expect(await tester.runAsync(env.db.countEntries), 0);
    });

    dbTestWidgets('CA30 : « Annuler » avec un texte demande confirmation', (
      tester,
      env,
    ) async {
      await tester.pumpWidget(env.app());
      await settle(tester);
      await openForm(tester);
      await pickMood(tester, 3);
      await enter(tester, 'Quelques mots déjà écrits.');

      await tester.tap(find.text('Annuler'));
      await settle(tester);

      expect(find.text('Abandonner cette entrée ?'), findsOneWidget);
      expect(find.text('Abandonner'), findsOneWidget);
      expect(find.text('Continuer'), findsOneWidget);
    });

    dbTestWidgets('CA30 : « Abandonner » ramène à la liste sans rien '
        'enregistrer', (tester, env) async {
      await tester.pumpWidget(env.app());
      await settle(tester);
      await openForm(tester);
      await pickMood(tester, 3);
      await enter(tester, 'Quelques mots déjà écrits.');
      await tester.tap(find.text('Annuler'));
      await settle(tester);

      await tester.tap(find.text('Abandonner'));
      await settle(tester);

      await expectBackOnList(tester);
      expect(find.text('Abandonner cette entrée ?'), findsNothing);
      expect(find.text(emptyListTitle), findsOneWidget);
      expect(await tester.runAsync(env.db.countEntries), 0);
    });

    dbTestWidgets('CA30 : « Continuer » laisse la saisie intacte', (
      tester,
      env,
    ) async {
      await tester.pumpWidget(env.app());
      await settle(tester);
      await openForm(tester);
      await pickMood(tester, 3);
      await enter(tester, 'Quelques mots déjà écrits.');
      await tester.tap(find.text('Annuler'));
      await settle(tester);

      await tester.tap(find.text('Continuer'));
      await settle(tester);

      expect(find.text('Abandonner cette entrée ?'), findsNothing);
      expect(find.text('Comment ça va ?'), findsOneWidget);
      expect(inputText(tester), 'Quelques mots déjà écrits.');
      expect(isChosen(tester, 3), isTrue);
      expect(await tester.runAsync(env.db.countEntries), 0);
    });
  });

  group('erreur et enregistrement en cours', () {
    testWidgets('CA14 : l\'échec affiche le bandeau, garde la saisie et '
        'propose « Réessayer »', (tester) async {
      usePhoneScreen(tester);
      // Pas d'ensureSemantics ici : testWidgets active déjà la sémantique, et un
      // addTearDown passerait après la vérification de fin de test de Flutter.
      final repo = FakeEntryRepository(
        beforeAdd: () async => throw StateError('stockage plein'),
      );
      await tester.pumpWidget(
        testApp(
          EntryFormScreen(
            repository: repo,
            settings: FakeSettingsRepository(),
            downloader: FakeModelDownloader(readyModel),
          ),
        ),
      );
      await tester.pump();
      await pickMood(tester, 4);
      await enter(tester, 'Un texte à ne pas perdre.');

      await tester.tap(find.text('Enregistrer'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("L'entrée n'a pas été enregistrée"), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Enregistrer'), findsNothing);
      expect(isEnabled(tester, 'Réessayer'), isTrue);
      expect(isChosen(tester, 4), isTrue);
      expect(inputText(tester), 'Un texte à ne pas perdre.');
      expect(find.text('Comment ça va ?'), findsOneWidget);
    });

    testWidgets('CA14 : « Réessayer » enregistre quand la cause a disparu', (
      tester,
    ) async {
      usePhoneScreen(tester);
      // Pas d'ensureSemantics ici : testWidgets active déjà la sémantique, et un
      // addTearDown passerait après la vérification de fin de test de Flutter.
      final repo = FakeEntryRepository(
        beforeAdd: () async => throw StateError('stockage plein'),
      );
      await tester.pumpWidget(
        TidemarkApp(
          repository: repo,
          settings: FakeSettingsRepository(),
          clock: () => fixedNow,
          downloader: FakeModelDownloader(readyModel),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Nouvelle entrée'));
      await tester.pumpAndSettle();
      await pickMood(tester, 4);
      await enter(tester, 'Un texte à ne pas perdre.');
      await tester.tap(find.text('Enregistrer'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Réessayer'), findsOneWidget);

      repo.beforeAdd = null;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(repo.addCalls, hasLength(2));
      expect(repo.addCalls.last.mood, 4);
      expect(repo.addCalls.last.text, 'Un texte à ne pas perdre.');
      expect(repo.entries, hasLength(1));
      expect(find.text('Comment ça va ?'), findsNothing);
      expect(find.text("L'entrée n'a pas été enregistrée"), findsNothing);
    });

    testWidgets('CA15 : pendant l\'enregistrement, le bouton affiche '
        '« Enregistrement… », désactivé, et un second appui n\'enregistre '
        'pas deux fois', (tester) async {
      usePhoneScreen(tester);
      // Pas d'ensureSemantics ici : testWidgets active déjà la sémantique, et un
      // addTearDown passerait après la vérification de fin de test de Flutter.
      final gate = Completer<void>();
      final repo = FakeEntryRepository(beforeAdd: () => gate.future);
      await tester.pumpWidget(
        TidemarkApp(
          repository: repo,
          settings: FakeSettingsRepository(),
          clock: () => fixedNow,
          downloader: FakeModelDownloader(readyModel),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Nouvelle entrée'));
      await tester.pumpAndSettle();
      await pickMood(tester, 4);

      // Deux appuis sans rafraîchir l'écran entre les deux.
      await tester.tap(find.text('Enregistrer'));
      await tester.tap(find.text('Enregistrer'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Enregistrement…'), findsOneWidget);
      expect(find.text('Enregistrer'), findsNothing);
      expect(isEnabled(tester, 'Enregistrement…'), isFalse);

      await tester.tap(find.text('Enregistrement…'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.addCalls, hasLength(1));

      gate.complete();
      await tester.pumpAndSettle();
      expect(repo.addCalls, hasLength(1));
      expect(repo.entries, hasLength(1));
      expect(find.text('Comment ça va ?'), findsNothing);
    });
  });
}
