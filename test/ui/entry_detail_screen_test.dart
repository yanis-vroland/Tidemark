import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/ui/screens/entry_detail_screen.dart';
import 'package:tidemark/ui/widgets/mood_bubble.dart';

import '../support/fake_entry_repository.dart';
import '../support/ui_harness.dart';
import '../support/wipe_harness.dart' show useTallScreen;

Entry entryOf({String? text, int mood = 4}) => Entry(
  id: 1,
  mood: mood,
  text: text,
  createdAt: DateTime.utc(2026, 10, 14, 21, 40),
  utcOffset: Duration.zero,
  analysisStatus: text == null
      ? AnalysisStatus.skipped
      : AnalysisStatus.pending,
);

const firstLine =
    "Longue journée au travail, mais la balade du soir au bord de l'eau m'a "
    'fait du bien.';
const secondLine =
    "Le vent était tombé, la lumière était belle. J'ai pensé à rien pendant une "
    'heure.';

Future<void> openDetail(
  WidgetTester tester,
  Entry entry,
  FakeEntryRepository repo,
) async {
  await tester.pumpWidget(
    testApp(EntryDetailScreen(entry: entry, repository: repo)),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('affichage', () {
    dbTestWidgets('CA16 : toucher une carte ouvre le détail avec la date '
        'complète, l\'heure, la bulle, le libellé et le texte entier', (
      tester,
      env,
    ) async {
      await env.add(tester, DateTime(2026, 10, 14, 21, 40), 4, longText);
      await tester.pumpWidget(env.app());
      await settle(tester);

      await tester.tap(find.textContaining('Longue journée au travail'));
      await settle(tester);

      expect(find.textContaining('Mercredi 14 octobre'), findsOneWidget);
      expect(find.text('21:40'), findsOneWidget);
      // Spec 008, CA13 : la bulle de 120 remplace la pastille chiffrée.
      expect(find.text('4'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is MoodBubble && w.mood == 4 && w.size == 120,
        ),
        findsOneWidget,
      );
      expect(find.text('Bien'), findsOneWidget);
      expect(find.text('Humeur 4 sur 5'), findsOneWidget);
      expect(find.textContaining(firstLine), findsOneWidget);
      expect(
        find.textContaining('nos vacances de l\'été prochain'),
        findsOneWidget,
      );
      expect(find.text('Supprimer cette entrée'), findsOneWidget);
    });

    dbTestWidgets('CA16 : le texte entier est affiché, sans coupure à deux '
        'lignes', (tester, env) async {
      await env.add(tester, DateTime(2026, 10, 14, 21, 40), 4, longText);
      await tester.pumpWidget(env.app());
      await settle(tester);
      await tester.tap(find.textContaining('Longue journée au travail'));
      await settle(tester);

      final shown = paragraphOf(tester, 'Longue journée au travail');

      expect(shown.truncated, isFalse);
      expect(shown.lines, greaterThan(2));
    });

    dbTestWidgets('CA16 : sans texte, le détail montre le reste et aucune '
        'ligne vide', (tester, env) async {
      await env.add(tester, DateTime(2026, 10, 14, 8, 15), 3);
      await tester.pumpWidget(env.app());
      await settle(tester);

      // Spec 009 : « Neutre » est aussi sous la bulle du check-in, plus haut.
      await tester.tap(find.text('Neutre').last);
      await settle(tester);

      expect(find.textContaining('Mercredi 14 octobre'), findsOneWidget);
      expect(find.text('08:15'), findsOneWidget);
      expect(find.text('3'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is MoodBubble && w.mood == 3 && w.size == 120,
        ),
        findsOneWidget,
      );
      expect(find.text('Neutre'), findsOneWidget);
      expect(find.text('Humeur 3 sur 5'), findsOneWidget);
      expect(emptyText, findsNothing);
    });

    testWidgets('CA16 : l\'écran de détail seul affiche l\'entrée reçue', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await openDetail(
        tester,
        entryOf(text: '$firstLine\n$secondLine'),
        FakeEntryRepository(),
      );

      expect(find.textContaining('Mercredi 14 octobre'), findsOneWidget);
      expect(find.text('21:40'), findsOneWidget);
      expect(find.textContaining(firstLine), findsOneWidget);
      expect(find.textContaining(secondLine), findsOneWidget);
    });

    testWidgets('CA17 : le détail n\'offre aucun moyen de modifier '
        'l\'entrée', (tester) async {
      usePhoneScreen(tester);
      await openDetail(tester, entryOf(text: firstLine), FakeEntryRepository());

      expect(find.byType(EditableText), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.textContaining('Modifier'), findsNothing);
      expect(find.textContaining('Éditer'), findsNothing);
      expect(find.textContaining('Editer'), findsNothing);
    });

    testWidgets('CA17 : sans texte non plus, aucun champ pour en '
        'ajouter', (tester) async {
      usePhoneScreen(tester);
      await openDetail(tester, entryOf(), FakeEntryRepository());

      expect(find.byType(EditableText), findsNothing);
      expect(find.textContaining('Modifier'), findsNothing);
    });
  });

  group('suppression', () {
    testWidgets('CA18 : « Supprimer cette entrée » demande confirmation et '
        'précise que c\'est définitif', (tester) async {
      usePhoneScreen(tester);
      final repo = FakeEntryRepository();
      await openDetail(tester, entryOf(text: firstLine), repo);

      await tester.tap(find.text('Supprimer cette entrée'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Supprimer cette entrée ?'), findsOneWidget);
      expect(
        find.text(
          "La suppression est définitive : l'entrée ne pourra pas être "
          'récupérée.',
        ),
        findsOneWidget,
      );
      expect(find.text('Supprimer'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
    });

    testWidgets('CA18 : la confirmation seule ne supprime rien', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final repo = FakeEntryRepository();
      await repo.addEntry(mood: 4, text: firstLine);
      await openDetail(tester, repo.entries.single, repo);

      await tester.tap(find.text('Supprimer cette entrée'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(repo.entries, hasLength(1));
    });

    dbTestWidgets('CA19 : « Supprimer » efface l\'entrée de la base, la liste '
        'réapparaît sans elle', (tester, env) async {
      await env.add(tester, DateTime(2026, 10, 14, 21, 40), 4, longText);
      await env.add(tester, DateTime(2026, 10, 14, 8, 15), 3);
      await tester.pumpWidget(env.app());
      await settle(tester);
      await tester.tap(find.textContaining('Longue journée au travail'));
      await settle(tester);
      await tester.tap(find.text('Supprimer cette entrée'));
      await settle(tester);

      await tester.tap(find.text('Supprimer'));
      await settle(tester);

      expect(find.text('Ton journal'), findsOneWidget);
      expect(find.text('Supprimer cette entrée'), findsNothing);
      expect(find.textContaining('Longue journée au travail'), findsNothing);
      expect(find.text('08:15'), findsOneWidget);
      expect(await tester.runAsync(env.db.countEntries), 1);
    });

    dbTestWidgets('CA19 : un intertitre de jour sans entrée disparaît', (
      tester,
      env,
    ) async {
      // L'accueil construit sa liste à la demande : sur un écran haut, toutes
      // les cartes sont construites, et « findsNothing » prouve l'absence.
      useTallScreen(tester);
      await env.seedJournal(tester);
      await tester.pumpWidget(env.app());
      await settle(tester);
      expect(find.text('Hier'), findsOneWidget);
      // L'accueil de la spec 009 (en-tête, check-in, plage) pousse ceci sous la
      // ligne de flottaison : on fait défiler, comme le ferait la personne.
      await tester.ensureVisible(
        find.textContaining('Encore une nuit trop courte'),
      );
      await tester.pump();
      await tester.tap(find.textContaining('Encore une nuit trop courte'));
      await settle(tester);
      await tester.tap(find.text('Supprimer cette entrée'));
      await settle(tester);

      await tester.tap(find.text('Supprimer'));
      await settle(tester);

      expect(find.text('Hier'), findsNothing);
      expect(find.textContaining('Encore une nuit trop courte'), findsNothing);
      expect(find.text("Aujourd'hui"), findsOneWidget);
      expect(find.text('Lundi 12 octobre'), findsOneWidget);
    });

    dbTestWidgets('CA19 : la dernière entrée supprimée ramène l\'état '
        'vide', (tester, env) async {
      await env.add(tester, DateTime(2026, 10, 14, 8, 15), 3);
      await tester.pumpWidget(env.app());
      await settle(tester);
      // Spec 009 : « Neutre » est aussi sous la bulle du check-in, plus haut.
      await tester.tap(find.text('Neutre').last);
      await settle(tester);
      await tester.tap(find.text('Supprimer cette entrée'));
      await settle(tester);

      await tester.tap(find.text('Supprimer'));
      await settle(tester);

      expect(find.text('Ta première entrée apparaîtra ici'), findsOneWidget);
      expect(await tester.runAsync(env.db.countEntries), 0);
    });

    dbTestWidgets('CA20 : « Annuler » dans la confirmation ne supprime rien et '
        'le détail reste affiché', (tester, env) async {
      await env.add(tester, DateTime(2026, 10, 14, 21, 40), 4, longText);
      await tester.pumpWidget(env.app());
      await settle(tester);
      await tester.tap(find.textContaining('Longue journée au travail'));
      await settle(tester);
      await tester.tap(find.text('Supprimer cette entrée'));
      await settle(tester);

      await tester.tap(find.text('Annuler'));
      await settle(tester);

      expect(find.text('Supprimer cette entrée ?'), findsNothing);
      expect(find.text('Supprimer cette entrée'), findsOneWidget);
      expect(find.text('Ton journal'), findsNothing);
      expect(find.textContaining(firstLine), findsOneWidget);
      expect(await tester.runAsync(env.db.countEntries), 1);
    });
  });
}
