// Saisie ouverte avec une humeur déjà choisie (spec 009, CA13) : `initialMood`. Le
// reste de la saisie est inchangé (spec 001, CA7, CA8). Dépôt factice.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/ui/screens/entry_form_screen.dart';

import '../support/fake_entry_repository.dart';
import '../support/fake_model_downloader.dart';
import '../support/fake_settings_repository.dart';
import '../support/ui_harness.dart';

Widget form(FakeEntryRepository repo, {int? initialMood}) => testApp(
  EntryFormScreen(
    repository: repo,
    settings: FakeSettingsRepository(),
    downloader: FakeModelDownloader(readyModel),
    initialMood: initialMood,
  ),
);

void main() {
  for (var mood = 1; mood <= 5; mood++) {
    testWidgets('CA13 : initialMood $mood, l\'humeur est choisie, son libellé '
        's\'affiche et « Enregistrer » est actif', (tester) async {
      usePhoneScreen(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(form(FakeEntryRepository(), initialMood: mood));
      await settle(tester);

      expect(isChosen(tester, mood), isTrue);
      for (final other in [1, 2, 3, 4, 5].where((m) => m != mood)) {
        expect(isChosen(tester, other), isFalse, reason: 'humeur $other');
      }
      // Les libellés « Très bas » et « Très bien » sont aussi les repères des bouts
      // de l'échelle (spec 001) : ils s'affichent deux fois une fois choisis.
      expect(
        find.text(moodLabel(mood)),
        mood == 1 || mood == 5 ? findsNWidgets(2) : findsOneWidget,
      );
      expect(isEnabled(tester, 'Enregistrer'), isTrue);
      expect(find.text('Choisis une humeur pour enregistrer.'), findsNothing);
      handle.dispose();
    });
  }

  testWidgets('CA13 : sans initialMood, rien n\'est choisi et « Enregistrer » '
      'est désactivé (spec 001, CA7)', (tester) async {
    usePhoneScreen(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(form(FakeEntryRepository()));
    await settle(tester);

    expect(isEnabled(tester, 'Enregistrer'), isFalse);
    expect(find.text('Choisis une humeur pour enregistrer.'), findsOneWidget);
    for (var mood = 1; mood <= 5; mood++) {
      expect(isChosen(tester, mood), isFalse);
    }
    handle.dispose();
  });

  testWidgets('CA13 : l\'humeur initiale peut être changée (spec 001, CA8)', (
    tester,
  ) async {
    usePhoneScreen(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(form(FakeEntryRepository(), initialMood: 4));
    await settle(tester);

    expect(isChosen(tester, 4), isTrue);
    await pickMood(tester, 2);

    expect(isChosen(tester, 2), isTrue);
    expect(isChosen(tester, 4), isFalse);
    expect(find.text('Bas'), findsOneWidget);
    expect(find.text('Bien'), findsNothing);
    handle.dispose();
  });

  testWidgets('CA13 : enregistrer avec l\'humeur initiale enregistre cette '
      'humeur, avec le texte saisi', (tester) async {
    usePhoneScreen(tester);
    final repo = FakeEntryRepository();
    await tester.pumpWidget(form(repo, initialMood: 5));
    await settle(tester);

    await tester.enterText(textInput, 'Belle journée au soleil.');
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await settle(tester);

    expect(repo.addCalls, hasLength(1));
    expect(repo.addCalls.single.mood, 5);
    expect(repo.addCalls.single.text, 'Belle journée au soleil.');
  });
}
