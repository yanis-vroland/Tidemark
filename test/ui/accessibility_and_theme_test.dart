import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/ui/screens/entry_detail_screen.dart';
import 'package:tidemark/ui/screens/entry_form_screen.dart';
import 'package:tidemark/ui/screens/entry_list_screen.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';

import '../support/fake_entry_repository.dart';
import '../support/ui_harness.dart';

const maxScale = 2.0;

/// Aucune exception de débordement (RenderFlex overflow) n'a été signalée.
void expectNoOverflow(WidgetTester tester, String where) {
  final exception = tester.takeException();
  expect(exception, isNull, reason: '$where : $exception');
}

Entry longEntry() => Entry(
  id: 1,
  mood: 4,
  text: longText,
  createdAt: DateTime.utc(2026, 10, 14, 21, 40),
  utcOffset: Duration.zero,
  analysisStatus: AnalysisStatus.pending,
);

void main() {
  group('CA27 : texte du système à 200 %', () {
    dbTestWidgets('CA27 : la liste, avec entrées, ne déborde pas', (
      tester,
      env,
    ) async {
      await env.seedJournal(tester);
      await tester.pumpWidget(
        testApp(
          EntryListScreen(repository: env.repo, clock: () => env.now),
          textScale: maxScale,
        ),
      );
      await settle(tester);

      expect(find.text('Nouvelle entrée'), findsOneWidget);
      expectNoOverflow(tester, 'liste');
    });

    dbTestWidgets('CA27 : la liste vide ne déborde pas', (tester, env) async {
      await tester.pumpWidget(
        testApp(
          EntryListScreen(repository: env.repo, clock: () => env.now),
          textScale: maxScale,
        ),
      );
      await settle(tester);

      expect(find.text('Ta première entrée apparaîtra ici'), findsOneWidget);
      expectNoOverflow(tester, 'liste vide');
    });

    dbTestWidgets('CA27 : la saisie ne déborde pas', (tester, env) async {
      await tester.pumpWidget(
        testApp(EntryFormScreen(repository: env.repo), textScale: maxScale),
      );
      await settle(tester);

      expect(find.text('Comment ça va ?'), findsOneWidget);
      expectNoOverflow(tester, 'saisie vide');
    });

    dbTestWidgets('CA27 : la saisie remplie, avec compteur, ne déborde pas', (
      tester,
      env,
    ) async {
      await tester.pumpWidget(
        testApp(EntryFormScreen(repository: env.repo), textScale: maxScale),
      );
      await settle(tester);

      await pickMood(tester, 4);
      await tester.enterText(textInput, 'a' * 1850);
      await tester.pump();

      expectNoOverflow(tester, 'saisie remplie');
    });

    testWidgets('CA27 : la saisie en erreur ne déborde pas', (tester) async {
      usePhoneScreen(tester);
      final repo = FakeEntryRepository(
        beforeAdd: () async => throw StateError('stockage plein'),
      );
      await tester.pumpWidget(
        testApp(EntryFormScreen(repository: repo), textScale: maxScale),
      );
      await tester.pump();
      await tester.tap(find.bySemanticsLabel(moodSemantics(4)));
      await tester.pump();

      await tester.tap(find.text('Enregistrer'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("L'entrée n'a pas été enregistrée"), findsOneWidget);
      expectNoOverflow(tester, 'saisie en erreur');
    });

    testWidgets('CA27 : le détail et sa confirmation ne débordent pas', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(
        testApp(
          EntryDetailScreen(
            entry: longEntry(),
            repository: FakeEntryRepository(),
          ),
          textScale: maxScale,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expectNoOverflow(tester, 'détail');

      await tester.tap(find.text('Supprimer cette entrée'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Supprimer cette entrée ?'), findsOneWidget);
      expectNoOverflow(tester, 'confirmation de suppression');
    });
  });

  group('CA28 : thème sombre du système', () {
    void useDarkSystem(WidgetTester tester) {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    }

    void expectDarkCharter(WidgetTester tester, String where) {
      final context = tester.element(find.byType(Scaffold).first);
      final theme = Theme.of(context);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(
        scaffold.backgroundColor ?? theme.scaffoldBackgroundColor,
        TidemarkColors.dark.surface,
        reason: '$where : fond',
      );
      expect(
        theme.extension<TidemarkColors>()?.surface,
        TidemarkColors.dark.surface,
        reason: '$where : couleurs de la charte sombre',
      );
    }

    dbTestWidgets('CA28 : la liste utilise les couleurs sombres de la '
        'charte', (tester, env) async {
      useDarkSystem(tester);
      await env.seedJournal(tester);
      await tester.pumpWidget(env.app());
      await settle(tester);

      expect(find.text('Ton journal'), findsOneWidget);
      expectDarkCharter(tester, 'liste');
    });

    dbTestWidgets('CA28 : la saisie utilise les couleurs sombres de la '
        'charte', (tester, env) async {
      useDarkSystem(tester);
      await tester.pumpWidget(env.app());
      await settle(tester);
      await openForm(tester);

      expect(find.text('Comment ça va ?'), findsOneWidget);
      expectDarkCharter(tester, 'saisie');
    });

    dbTestWidgets('CA28 : le détail utilise les couleurs sombres de la '
        'charte', (tester, env) async {
      useDarkSystem(tester);
      await env.seedJournal(tester);
      await tester.pumpWidget(env.app());
      await settle(tester);
      await tester.tap(find.text('Neutre'));
      await settle(tester);

      expect(find.text('Supprimer cette entrée'), findsOneWidget);
      expectDarkCharter(tester, 'détail');
    });
  });
}
