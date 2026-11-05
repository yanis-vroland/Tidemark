// Accueil à deux onglets et barre de navigation (spec 009, CA19 à CA23, CA26 à CA28) :
// `HomeShell`, branché par `TidemarkApp`. Dépôt, téléchargeur et rédacteur factices ;
// horloge : mercredi 14 octobre 2026 (semaine du 12 au 18).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/ui/screens/entry_detail_screen.dart';
import 'package:tidemark/ui/screens/entry_form_screen.dart';
import 'package:tidemark/ui/screens/entry_list_screen.dart';
import 'package:tidemark/ui/screens/home_shell.dart';
import 'package:tidemark/ui/screens/settings_screen.dart';
import 'package:tidemark/ui/screens/weekly_review_screen.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';

import '../support/distress_harness.dart' show helpTitle;
import '../support/fake_entry_repository.dart';
import '../support/fake_model_downloader.dart';
import '../support/fake_settings_repository.dart';
import '../support/home_harness.dart';
import '../support/playful_harness.dart';
import '../support/ui_harness.dart';

const light = TidemarkColors.light;
const dark = TidemarkColors.dark;

/// Les trois commandes de la barre sont à l'écran.
void expectBarShown(WidgetTester tester) {
  expect(tab('Journal'), findsOneWidget);
  expect(tab('Semaine'), findsOneWidget);
  expect(find.text('Nouvelle entrée'), findsOneWidget);
}

/// Aucune commande de la barre n'est à l'écran (écran ouvert par-dessus).
void expectBarHidden(WidgetTester tester) {
  expect(tab('Journal'), findsNothing);
  expect(tab('Semaine'), findsNothing);
  expect(find.text('Nouvelle entrée'), findsNothing);
}

Future<void> pop(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await settle(tester);
}

/// Journal d'exemple : quatre entrées de la semaine, midi.
FakeEntryRepository sample() => weekJournal({1: 4, 2: 3, 3: 2, 4: 5});

/// [sample], plus une entrée la semaine précédente : sans elle, « Semaine
/// précédente » reste désactivée (spec 006, CA5 ; RM55).
FakeEntryRepository sampleWithLastWeek() =>
    sample()..seed(mood: 3, createdAt: DateTime(2026, 10, 7, 12));

void main() {
  group('l\'accueil de l\'app (CA19)', () {
    homeTest(
      'CA19 : TidemarkApp affiche HomeShell, sur l\'onglet « Journal »',
      (tester) async {
        final env = HomeEnv(sample());
        await tester.pumpWidget(env.fullApp());
        await settle(tester);

        expect(find.byType(HomeShell), findsOneWidget);
        expect(find.byType(EntryListScreen), findsOneWidget);
        expect(find.text('Ton journal'), findsOneWidget);
        expect(find.text('Ta semaine'), findsNothing);
        expect(isSelectedTab(tester, 'Journal'), isTrue);
      },
    );
  });

  group('la barre (CA19)', () {
    homeTest(
      'CA19 : « Journal », « Nouvelle entrée » au centre et « Semaine », '
      'en bas de l\'écran',
      (tester) async {
        await showHome(tester, HomeEnv(sample()));

        expectBarShown(tester);
        final journal = tester.getCenter(tab('Journal'));
        final create = tester.getCenter(find.text('Nouvelle entrée'));
        final week = tester.getCenter(tab('Semaine'));
        expect(journal.dx, lessThan(create.dx));
        expect(create.dx, lessThan(week.dx));
        expect(create.dx, closeTo(393 / 2, 8), reason: 'au centre');
        for (final y in [journal.dy, create.dy, week.dy]) {
          expect(y, greaterThan(852 * 0.8), reason: 'en bas de l\'écran');
        }
      },
      tall: false,
    );

    homeTest(
      'CA19 : « Journal » et « Semaine » sont des boutons, la bulle « + » '
      'est un bouton « Nouvelle entrée »',
      (tester) async {
        await showHome(tester, HomeEnv(sample()));

        expect(isButtonNode(tester, tab('Journal')), isTrue);
        expect(isButtonNode(tester, tab('Semaine')), isTrue);
        expect(
          anyButtonNode(tester, find.bySemanticsLabel('Nouvelle entrée')),
          isTrue,
        );
        expect(
          find.byIcon(Icons.add).evaluate().isNotEmpty ||
              find.text('+').evaluate().isNotEmpty,
          isTrue,
          reason: 'la bulle porte un « + »',
        );
      },
    );

    homeTest('CA19 : l\'onglet ouvert est annoncé comme sélectionné, l\'autre '
        'non', (tester) async {
      await showHome(tester, HomeEnv(sample()));

      expect(isSelectedTab(tester, 'Journal'), isTrue);
      expect(isSelectedTab(tester, 'Semaine'), isFalse);

      await openTab(tester, 'Semaine');

      expect(isSelectedTab(tester, 'Semaine'), isTrue);
      expect(isSelectedTab(tester, 'Journal'), isFalse);
      expectBarShown(tester);
    });

    homeTest('CA19 : la barre est aussi là sur le journal vide, en lecture et '
        'en erreur', (tester) async {
      await showHome(tester, HomeEnv(FakeEntryRepository()));
      expectBarShown(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await showHome(tester, HomeEnv(sample()..neverEmit = true));
      expectBarShown(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await showHome(
        tester,
        HomeEnv(sample()..watchError = StateError('illisible')),
      );
      expectBarShown(tester);
    });

    homeTest('CA19 : la liste seule n\'a plus de bouton « Nouvelle entrée » '
        '(remplacé par la barre, spec 001, CA1)', (tester) async {
      await tester.pumpWidget(
        testApp(
          EntryListScreen(
            repository: sample(),
            settings: FakeSettingsRepository(),
            downloader: FakeModelDownloader(readyModel),
            clock: () => eveningNow,
          ),
        ),
      );
      await settle(tester);

      expect(find.text('Nouvelle entrée'), findsNothing);
      expect(find.text('Ton journal'), findsOneWidget);
    });
  });

  group('« Nouvelle entrée » (CA20)', () {
    homeTest('CA20 : depuis « Journal », la saisie s\'ouvre sans humeur '
        'choisie', (tester) async {
      await showHome(tester, HomeEnv(sample()));

      await tester.tap(find.text('Nouvelle entrée'));
      await settle(tester);

      expect(find.byType(EntryFormScreen), findsOneWidget);
      expect(find.text('Comment ça va ?'), findsOneWidget);
      expect(isEnabled(tester, 'Enregistrer'), isFalse);
      expect(find.text('Choisis une humeur pour enregistrer.'), findsOneWidget);
      for (var mood = 1; mood <= 5; mood++) {
        expect(isChosen(tester, mood), isFalse, reason: 'humeur $mood');
      }
    });

    homeTest('CA20 : depuis « Semaine », la saisie s\'ouvre aussi sans '
        'humeur choisie', (tester) async {
      await showHome(tester, HomeEnv(sample()));
      await openTab(tester, 'Semaine');

      await tester.tap(find.text('Nouvelle entrée'));
      await settle(tester);

      expect(find.byType(EntryFormScreen), findsOneWidget);
      expect(isEnabled(tester, 'Enregistrer'), isFalse);
    });

    homeTest('CA20 : une entrée enregistrée depuis la barre est celle de '
        'l\'humeur choisie dans la saisie', (tester) async {
      final repo = sample();
      await showHome(tester, HomeEnv(repo));
      await tester.tap(find.text('Nouvelle entrée'));
      await settle(tester);

      await pickMood(tester, 3);
      await tester.tap(find.text('Enregistrer'));
      await settle(tester);

      expect(repo.addCalls.single.mood, 3);
      expectBarShown(tester);
    });
  });

  group('chaque onglet garde son état (CA21)', () {
    homeTest('CA21 : le défilement de la liste est gardé en passant par '
        '« Semaine »', (tester) async {
      final repo = FakeEntryRepository(clock: () => eveningNow);
      for (var d = 1; d <= 14; d++) {
        repo.seed(mood: 1 + d % 5, createdAt: DateTime(2026, 10, d, 12));
      }
      await showHome(tester, HomeEnv(repo));
      final before = tester.getTopLeft(find.text("Aujourd'hui")).dy;
      await tester.drag(find.text("Aujourd'hui"), const Offset(0, -300));
      await settle(tester);
      final scrolled = tester.getTopLeft(find.text("Aujourd'hui")).dy;
      expect(scrolled, lessThan(before - 100), reason: 'la liste a défilé');

      await openTab(tester, 'Semaine');
      expect(find.text('Ta semaine'), findsOneWidget);
      await openTab(tester, 'Journal');

      expect(tester.getTopLeft(find.text("Aujourd'hui")).dy, scrolled);
    }, tall: false);

    homeTest('CA21 : la semaine affichée du bilan est gardée en passant par '
        '« Journal »', (tester) async {
      await showHome(tester, HomeEnv(sampleWithLastWeek()));
      await openTab(tester, 'Semaine');
      await tester.tap(find.bySemanticsLabel('Semaine précédente'));
      await settle(tester);
      expect(find.text('5 – 11 octobre'), findsOneWidget);
      expect(find.text('Semaine dernière'), findsOneWidget);

      await openTab(tester, 'Journal');
      expect(find.text('Ta semaine'), findsNothing);
      await openTab(tester, 'Semaine');

      expect(find.text('5 – 11 octobre'), findsOneWidget);
      expect(find.text('Semaine dernière'), findsOneWidget);
      expect(find.text('Semaine en cours'), findsNothing);
    });

    homeTest('CA21 : revenir deux fois sur le même onglet ne change rien', (
      tester,
    ) async {
      await showHome(tester, HomeEnv(sample()));

      await openTab(tester, 'Journal');
      expect(find.text('Ton journal'), findsOneWidget);
      await openTab(tester, 'Semaine');
      await openTab(tester, 'Semaine');

      expect(find.text('Ta semaine'), findsOneWidget);
      expect(isSelectedTab(tester, 'Semaine'), isTrue);
    });
  });

  group('écrans ouverts par-dessus (CA22)', () {
    homeTest('CA22 : la saisie n\'a pas la barre ; le retour ramène à '
        '« Journal »', (tester) async {
      await showHome(tester, HomeEnv(sample()));

      await tester.tap(find.text('Nouvelle entrée'));
      await settle(tester);
      expect(find.byType(EntryFormScreen), findsOneWidget);
      expectBarHidden(tester);

      await pop(tester);

      expectBarShown(tester);
      expect(isSelectedTab(tester, 'Journal'), isTrue);
      expect(find.text('Ton journal'), findsOneWidget);
    });

    homeTest('CA22 : ouverte depuis « Semaine », la saisie rend à '
        '« Semaine » au retour', (tester) async {
      await showHome(tester, HomeEnv(sample()));
      await openTab(tester, 'Semaine');

      await tester.tap(find.text('Nouvelle entrée'));
      await settle(tester);
      expectBarHidden(tester);
      await pop(tester);

      expect(isSelectedTab(tester, 'Semaine'), isTrue);
      expect(find.text('Ta semaine'), findsOneWidget);
      expect(find.text('Ton journal'), findsNothing);
    });

    homeTest('CA22 : la saisie ouverte par une bulle du check-in n\'a pas la '
        'barre non plus', (tester) async {
      await showHome(tester, HomeEnv(sample()));

      await tester.tap(find.bySemanticsLabel(checkInBubbleLabel(4)));
      await settle(tester);

      expect(find.byType(EntryFormScreen), findsOneWidget);
      expectBarHidden(tester);
    });

    homeTest('CA22 : le détail d\'une entrée n\'a pas la barre ; le retour '
        'ramène à la liste', (tester) async {
      await showHome(tester, HomeEnv(sample()));

      await tester.tap(
        find.bySemanticsLabel(RegExp(r'^Bien, humeur 4 sur 5, 12:00')),
      );
      await settle(tester);
      expect(find.byType(EntryDetailScreen), findsOneWidget);
      expectBarHidden(tester);

      await pop(tester);

      expectBarShown(tester);
      expect(isSelectedTab(tester, 'Journal'), isTrue);
    });

    homeTest('CA22 : les Réglages n\'ont pas la barre ; le retour ramène à '
        'la liste', (tester) async {
      await showHome(tester, HomeEnv(sample()));

      await tester.tap(find.bySemanticsLabel('Réglages').first);
      await settle(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expectBarHidden(tester);

      await pop(tester);

      expectBarShown(tester);
      expect(find.text('Ton journal'), findsOneWidget);
    });

    homeTest('CA22 : l\'écran d\'aide n\'a pas la barre ; « Revenir à mon '
        'journal » ramène à l\'accueil', (tester) async {
      final env = HomeEnv(sample());
      await tester.pumpWidget(env.fullApp());
      await settle(tester);

      await tester.tap(find.text('Nouvelle entrée'));
      await settle(tester);
      await pickMood(tester, 2);
      await tester.enterText(textInput, 'je veux disparaître');
      await tester.pump();
      await tester.tap(find.text('Enregistrer'));
      await settle(tester);

      expect(find.text(helpTitle), findsOneWidget);
      expectBarHidden(tester);

      await tester.tap(find.text('Revenir à mon journal'));
      await settle(tester);

      expectBarShown(tester);
      expect(isSelectedTab(tester, 'Journal'), isTrue);
    });
  });

  group('onglet « Semaine » (CA23)', () {
    homeTest(
      'CA23 : le bilan de la semaine en cours, sans retour « Journal »',
      (tester) async {
        await showHome(tester, HomeEnv(sample()));
        await openTab(tester, 'Semaine');

        expect(find.byType(WeeklyReviewScreen), findsOneWidget);
        expect(find.text('Ta semaine'), findsOneWidget);
        expect(find.text('12 – 18 octobre'), findsOneWidget);
        expect(find.text('Semaine en cours'), findsOneWidget);
        expect(find.bySemanticsLabel('Semaine précédente'), findsOneWidget);
        expect(find.bySemanticsLabel('Semaine suivante'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Journal'), findsNothing);
        expect(find.text('Journal'), findsOneWidget, reason: 'la barre seule');
      },
    );

    homeTest('CA23 : les flèches changent de semaine (spec 006, CA5)', (
      tester,
    ) async {
      await showHome(tester, HomeEnv(sampleWithLastWeek()));
      await openTab(tester, 'Semaine');

      await tester.tap(find.bySemanticsLabel('Semaine précédente'));
      await settle(tester);
      expect(find.text('5 – 11 octobre'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Semaine suivante'));
      await settle(tester);

      expect(find.text('12 – 18 octobre'), findsOneWidget);
    });
  });

  group('recalcul au retour sur l\'onglet (CA26)', () {
    homeTest('CA26 : une entrée ajoutée pendant qu\'on est sur « Journal » : '
        'la marée et les chiffres sont recalculés au retour', (tester) async {
      final repo = weekJournal({1: 4, 2: 3, 4: 5});
      await showHome(tester, HomeEnv(repo));
      await openTab(tester, 'Semaine');
      expect(
        find.bySemanticsLabel(tideLabel([4, 3, null, 5, null, null, null])),
        findsOneWidget,
      );
      expect(find.text('Entrées'), findsOneWidget);
      await openTab(tester, 'Journal');

      await tester.runAsync(() => repo.addEntry(mood: 1));
      await settle(tester);
      await openTab(tester, 'Semaine');

      expect(
        find.bySemanticsLabel(tideLabel([4, 3, 1, 5, null, null, null])),
        findsOneWidget,
      );
    });

    homeTest('CA26 : une entrée supprimée : la marée est recalculée', (
      tester,
    ) async {
      final repo = weekJournal({1: 4, 2: 3, 4: 5});
      await showHome(tester, HomeEnv(repo));
      await openTab(tester, 'Semaine');
      await openTab(tester, 'Journal');

      final last = repo.entries.firstWhere((e) => e.mood == 5);
      await tester.runAsync(() => repo.deleteEntry(last.id));
      await settle(tester);
      await openTab(tester, 'Semaine');

      expect(
        find.bySemanticsLabel(tideLabel([4, 3, null, null, null, null, null])),
        findsOneWidget,
      );
      expect(
        find.text('Pas encore de bilan pour cette semaine'),
        findsOneWidget,
        reason: 'deux entrées seulement : plus de bilan chiffré',
      );
    });

    homeTest('CA26 : les chiffres suivent : 3 entrées donnent un bilan, une '
        '4e change le nombre d\'entrées', (tester) async {
      final repo = weekJournal({1: 4, 2: 3, 4: 5});
      await showHome(tester, HomeEnv(repo));
      await openTab(tester, 'Semaine');
      expect(find.text('3'), findsWidgets);
      expect(find.text('4'), findsNothing);
      await openTab(tester, 'Journal');

      await tester.runAsync(() => repo.addEntry(mood: 3));
      await settle(tester);
      await openTab(tester, 'Semaine');

      expect(find.text('4'), findsWidgets);
    });
  });

  group('texte à 200 % (CA27)', () {
    homeTest('CA27 : la barre à 200 % garde des libellés lisibles, entiers et '
        'dans l\'écran', (tester) async {
      await showHome(tester, HomeEnv(sample()), textScale: 2.0);

      expect(tester.takeException(), isNull);
      for (final label in ['Journal', 'Semaine', 'Nouvelle entrée']) {
        final rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(0), reason: label);
        expect(rect.right, lessThanOrEqualTo(393), reason: label);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
        expect(paragraph.size.height, greaterThan(0));
      }
    }, tall: false);

    homeTest('CA27 : l\'onglet « Semaine » à 200 % ne déborde pas et défile', (
      tester,
    ) async {
      await showHome(tester, HomeEnv(sample()), textScale: 2.0);
      await openTab(tester, 'Semaine');

      expect(tester.takeException(), isNull);
      expect(find.text('Ta semaine'), findsOneWidget);
      final rect = tester.getRect(find.text('Ta semaine'));
      expect(rect.right, lessThanOrEqualTo(393));
      expectBarShown(tester);
    }, tall: false);
  });

  group('thème sombre (CA28)', () {
    homeTest('CA28 : thème sombre, la barre et l\'onglet « Semaine » prennent '
        'les valeurs sombres', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final key = GlobalKey();
      await showHome(tester, HomeEnv(sample()), boundary: key);
      await openTab(tester, 'Semaine');

      final pixels = await capture(tester, key);
      expect(countColor(pixels, dark.surface), greaterThan(2000));
      expect(countColor(pixels, light.surface), 0);
      expect(countColor(pixels, dark.sky), greaterThan(1000));
      expect(countColor(pixels, light.sky), 0);
    });
  });
}
