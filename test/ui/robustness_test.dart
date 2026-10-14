// Comportements ajoutés après la revue de la spec 001 (PR #12) : retour système
// pendant un enregistrement, échec de suppression, chargement et erreur de la liste,
// annonce des cartes au lecteur d'écran.
import 'dart:async';

import '../support/fake_settings_repository.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/main.dart';
import 'package:tidemark/ui/screens/entry_detail_screen.dart';

import '../support/fake_entry_repository.dart';
import '../support/ui_harness.dart';

Entry _entry() => Entry(
  id: 1,
  mood: 4,
  text: 'Balade au bord de l\'eau.',
  createdAt: DateTime.utc(2026, 10, 14, 19, 40),
  utcOffset: const Duration(hours: 2),
  analysisStatus: AnalysisStatus.pending,
);

void main() {
  testWidgets(
    'CA34 : pendant l\'enregistrement, un retour système n\'ouvre pas '
    'la confirmation et l\'écran se ferme une fois l\'entrée enregistrée',
    (tester) async {
      usePhoneScreen(tester);
      final gate = Completer<void>();
      final repo = FakeEntryRepository(beforeAdd: () => gate.future);
      await tester.pumpWidget(
        TidemarkApp(
          repository: repo,
          settings: FakeSettingsRepository(),
          clock: () => fixedNow,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Nouvelle entrée'));
      await tester.pumpAndSettle();
      await pickMood(tester, 4);
      await tester.enterText(textInput, 'Un texte écrit.');
      await tester.tap(find.text('Enregistrer'));
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Abandonner cette entrée ?'), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Comment ça va ?'), findsNothing);
      expect(find.text('Ton journal'), findsOneWidget);
      expect(repo.entries, hasLength(1));
    },
  );

  testWidgets('CA34 : sans texte, un retour système pendant l\'enregistrement '
      'ne ferme pas non plus l\'écran', (tester) async {
    usePhoneScreen(tester);
    final gate = Completer<void>();
    final repo = FakeEntryRepository(beforeAdd: () => gate.future);
    await tester.pumpWidget(
      TidemarkApp(
        repository: repo,
        settings: FakeSettingsRepository(),
        clock: () => fixedNow,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Nouvelle entrée'));
    await tester.pumpAndSettle();
    await pickMood(tester, 3);
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    await tester.binding.handlePopRoute();
    // Laisse finir une éventuelle animation de retour (plus de 500 ms).
    await tester.pumpAndSettle();
    expect(find.text('Comment ça va ?'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Comment ça va ?'), findsNothing);
    expect(repo.entries, hasLength(1));
  });

  testWidgets('CA36 : l\'annonce d\'une carte ne lit que le début d\'un long '
      'texte', (tester) async {
    usePhoneScreen(tester);
    final repo = FakeEntryRepository();
    await repo.addEntry(mood: 2, text: 'Très long texte. ' * 100);
    await tester.pumpWidget(
      TidemarkApp(
        repository: repo,
        settings: FakeSettingsRepository(),
        clock: () => fixedNow,
      ),
    );
    await tester.pump();
    await tester.pump();

    final label = tester
        .getSemantics(find.bySemanticsLabel(RegExp(r'^Bas, humeur 2 sur 5')))
        .label;
    expect(label.length, lessThan(200));
    expect(label, endsWith('…'));
  });

  testWidgets('CA33 : une suppression qui échoue garde l\'entrée et le détail, '
      'et le dit', (tester) async {
    usePhoneScreen(tester);
    final repo = FakeEntryRepository(
      beforeDelete: () async => throw StateError('base indisponible'),
    );
    await tester.pumpWidget(
      testApp(EntryDetailScreen(entry: _entry(), repository: repo)),
    );
    await tester.pump();

    await tester.tap(find.text('Supprimer cette entrée'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(
      find.text("L'entrée n'a pas été supprimée. Réessaie."),
      findsOneWidget,
    );
    expect(find.text('Supprimer cette entrée'), findsOneWidget);
  });

  testWidgets('CA31 : pendant le chargement, le titre est affiché', (
    tester,
  ) async {
    usePhoneScreen(tester);
    final repo = FakeEntryRepository()..neverEmit = true;
    await tester.pumpWidget(
      TidemarkApp(
        repository: repo,
        settings: FakeSettingsRepository(),
        clock: () => fixedNow,
      ),
    );
    await tester.pump();

    expect(find.text('Ton journal'), findsOneWidget);
    expect(find.text('Ta première entrée apparaîtra ici'), findsNothing);
  });

  testWidgets('CA32 : une erreur de lecture est annoncée, sans état vide', (
    tester,
  ) async {
    usePhoneScreen(tester);
    final repo = FakeEntryRepository(watchError: StateError('base illisible'));
    await tester.pumpWidget(
      TidemarkApp(
        repository: repo,
        settings: FakeSettingsRepository(),
        clock: () => fixedNow,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text("Ton journal n'a pas pu être lu"), findsOneWidget);
    expect(find.text('Ta première entrée apparaîtra ici'), findsNothing);
  });

  testWidgets('CA36 : une carte s\'annonce avec son humeur, son chiffre et '
      'son heure', (tester) async {
    usePhoneScreen(tester);
    final repo = FakeEntryRepository();
    await repo.addEntry(mood: 4, text: 'Balade au bord de l\'eau.');
    await tester.pumpWidget(
      TidemarkApp(
        repository: repo,
        settings: FakeSettingsRepository(),
        clock: () => fixedNow,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.bySemanticsLabel(
        RegExp(r"^Bien, humeur 4 sur 5, 21:40, Balade au bord de l'eau\.$"),
      ),
      findsOneWidget,
    );
  });

  testWidgets('CA35 : clé introuvable, le message le dit et rassure', (
    tester,
  ) async {
    await tester.pumpWidget(const StartupErrorApp(keyMissing: true));

    expect(find.text("Ton journal n'a pas pu être ouvert"), findsOneWidget);
    expect(
      find.textContaining('la clé qui les protège est introuvable'),
      findsOneWidget,
    );
    expect(find.textContaining("Rien n'a été effacé"), findsOneWidget);
  });

  testWidgets('CA35 : autre cause, un message neutre', (tester) async {
    await tester.pumpWidget(const StartupErrorApp(keyMissing: false));

    expect(find.text("Ton journal n'a pas pu être ouvert"), findsOneWidget);
    expect(find.textContaining('clé'), findsNothing);
    expect(
      find.text("Rien n'a été effacé. Ferme l'app, puis rouvre-la."),
      findsOneWidget,
    );
  });
}
