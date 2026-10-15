import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/ui/screens/entry_list_screen.dart';

import '../support/fake_settings_repository.dart';

import '../support/fake_model_downloader.dart';
import '../support/ui_harness.dart';

Widget listScreen(DbEnv env) => testApp(
  EntryListScreen(
    repository: env.repo,
    settings: FakeSettingsRepository(),
    clock: () => env.now,
    downloader: FakeModelDownloader(readyModel),
  ),
);

double top(WidgetTester tester, Finder finder) =>
    tester.getTopLeft(finder.first).dy;

void main() {
  group('liste vide', () {
    dbTestWidgets('CA1 : sans entrée, l\'état vide et le bouton « Nouvelle '
        'entrée » s\'affichent', (tester, env) async {
      await tester.pumpWidget(listScreen(env));
      await settle(tester);

      expect(find.text('Ta première entrée apparaîtra ici'), findsOneWidget);
      expect(find.text('Nouvelle entrée'), findsOneWidget);
    });

    dbTestWidgets('CA1 : l\'état vide reprend le titre et le texte de la '
        'maquette', (tester, env) async {
      await tester.pumpWidget(listScreen(env));
      await settle(tester);

      expect(find.text('Ton journal'), findsOneWidget);
      expect(
        find.text(
          'Note ton humeur en quelques secondes. Tout reste sur ton téléphone.',
        ),
        findsOneWidget,
      );
    });

    dbTestWidgets('CA1 : avec des entrées, l\'état vide n\'est plus '
        'affiché', (tester, env) async {
      await env.seedJournal(tester);
      await tester.pumpWidget(listScreen(env));
      await settle(tester);

      expect(find.text('Ta première entrée apparaîtra ici'), findsNothing);
      expect(find.text('Nouvelle entrée'), findsOneWidget);
    });
  });

  group('liste avec entrées', () {
    dbTestWidgets('CA2 : les jours vont du plus récent au plus ancien, et les '
        'entrées d\'un jour de la plus récente à la plus ancienne', (
      tester,
      env,
    ) async {
      await env.seedJournal(tester);
      await tester.pumpWidget(listScreen(env));
      await settle(tester);

      final order = [
        top(tester, find.text("Aujourd'hui")),
        top(tester, find.text('21:40')),
        top(tester, find.text('08:15')),
        top(tester, find.text('Hier')),
        top(tester, find.text('22:05')),
        top(tester, find.text('Lundi 12 octobre')),
        top(tester, find.text('19:30')),
      ];
      expect(order, orderedEquals([...order]..sort()));
    });

    dbTestWidgets('CA3 : les intertitres sont « Aujourd\'hui », « Hier » et '
        'le jour de la semaine avec la date', (tester, env) async {
      await env.seedJournal(tester);
      await tester.pumpWidget(listScreen(env));
      await settle(tester);

      expect(find.text("Aujourd'hui"), findsOneWidget);
      expect(find.text('Hier'), findsOneWidget);
      expect(find.text('Lundi 12 octobre'), findsOneWidget);
    });

    dbTestWidgets('CA3 : une entrée d\'une autre année porte l\'année dans '
        'son intertitre', (tester, env) async {
      await env.add(tester, DateTime(2025, 10, 13, 18, 0), 3, 'Un an déjà.');
      await tester.pumpWidget(listScreen(env));
      await settle(tester);

      expect(find.text('Lundi 13 octobre 2025'), findsOneWidget);
    });

    dbTestWidgets('CA4 : la carte montre la pastille avec son chiffre, '
        'l\'heure, le libellé et le début du texte', (tester, env) async {
      await env.add(tester, DateTime(2026, 10, 14, 21, 40), 4, longText);
      await tester.pumpWidget(listScreen(env));
      await settle(tester);

      expect(find.text('4'), findsOneWidget);
      expect(find.text('21:40'), findsOneWidget);
      expect(find.text('Bien'), findsOneWidget);
      expect(find.textContaining('Longue journée au travail'), findsOneWidget);
    });

    dbTestWidgets('CA4 : le texte tient sur deux lignes au plus', (
      tester,
      env,
    ) async {
      await env.add(tester, DateTime(2026, 10, 14, 21, 40), 4, longText);
      await tester.pumpWidget(listScreen(env));
      await settle(tester);

      final shown = paragraphOf(tester, 'Longue journée au travail');

      expect(shown.lines, lessThanOrEqualTo(2));
      expect(shown.truncated, isTrue, reason: 'le texte est plus long');
    });

    dbTestWidgets('CA5 : sans texte, la carte montre la pastille, l\'heure et '
        'le libellé, sans ligne vide', (tester, env) async {
      await env.add(tester, DateTime(2026, 10, 14, 8, 15), 3);
      await tester.pumpWidget(listScreen(env));
      await settle(tester);

      expect(find.text('3'), findsOneWidget);
      expect(find.text('08:15'), findsOneWidget);
      expect(find.text('Neutre'), findsOneWidget);
      expect(emptyText, findsNothing);
    });

    dbTestWidgets('CA5 : un texte fait d\'espaces ne laisse pas non plus de '
        'ligne vide', (tester, env) async {
      await env.add(tester, DateTime(2026, 10, 14, 8, 15), 3, '  \n ');
      await tester.pumpWidget(listScreen(env));
      await settle(tester);

      expect(emptyText, findsNothing);
    });

    dbTestWidgets('CA6 : plusieurs entrées le même jour ont chacune leur carte '
        'sous l\'intertitre de ce jour', (tester, env) async {
      await env.add(tester, DateTime(2026, 10, 14, 7, 30), 2, 'Réveil lourd.');
      await env.add(tester, DateTime(2026, 10, 14, 13, 0), 3);
      await env.add(tester, DateTime(2026, 10, 14, 20, 45), 5, 'Belle fin.');
      await env.add(tester, DateTime(2026, 10, 13, 20, 0), 4);
      await tester.pumpWidget(listScreen(env));
      await settle(tester);

      expect(find.text("Aujourd'hui"), findsOneWidget);
      for (final time in ['07:30', '13:00', '20:45']) {
        expect(find.text(time), findsOneWidget);
        expect(
          top(tester, find.text(time)),
          greaterThan(top(tester, find.text("Aujourd'hui"))),
        );
        expect(
          top(tester, find.text(time)),
          lessThan(top(tester, find.text('Hier'))),
        );
      }
      expect(
        top(tester, find.text('20:00')),
        greaterThan(top(tester, find.text('Hier'))),
      );
    });

    dbTestWidgets('CA9 : la liste se met à jour quand une entrée est '
        'ajoutée', (tester, env) async {
      await tester.pumpWidget(listScreen(env));
      await settle(tester);
      expect(find.text('Ta première entrée apparaîtra ici'), findsOneWidget);

      await env.add(tester, DateTime(2026, 10, 14, 21, 40), 4);
      await settle(tester);

      expect(find.text('Ta première entrée apparaîtra ici'), findsNothing);
      expect(find.text("Aujourd'hui"), findsOneWidget);
      expect(find.text('Bien'), findsOneWidget);
    });
  });
}
