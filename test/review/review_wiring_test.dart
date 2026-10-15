// Branchement du bilan au démarrage de l'app (spec 006, « Données », `Journal.
// reviewWriter`) : `startApp` donne le rédacteur du journal au bilan de l'app
// démarrée. Journal de faux : aucun modèle, aucune base, aucun réseau.
//
// Non testé ici, faute d'être observable sans moteur réel : le partage d'un même
// `ModelGate` entre l'analyseur et le rédacteur réels (`openJournal`). Les deux
// moitiés sont couvertes à part dans test/model/model_gate_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/main.dart';
import 'package:tidemark/review/review_writer.dart';

import '../support/fake_entry_repository.dart';
import '../support/fake_model_downloader.dart';
import '../support/fake_review_writer.dart';
import '../support/fake_settings_repository.dart';
import '../support/review_harness.dart';
import '../support/ui_harness.dart';

Journal journalOf(
  FakeEntryRepository repo, {
  ReviewWriter? reviewWriter,
  FakeModelDownloader? downloader,
}) => Journal(
  entries: repo,
  settings: FakeSettingsRepository(),
  downloader: downloader ?? FakeModelDownloader(readyModel),
  reviewWriter: reviewWriter,
);

/// Trois entrées de la semaine en cours (l'app démarrée lit l'horloge réelle).
FakeEntryRepository threeEntriesThisWeek() {
  final now = DateTime.now();
  return FakeEntryRepository()
    ..seed(mood: 3, createdAt: now)
    ..seed(mood: 4, createdAt: now.subtract(const Duration(minutes: 5)))
    ..seed(mood: 3, createdAt: now.subtract(const Duration(minutes: 10)));
}

Future<void> openReviewOf(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await settle(tester);
  await tester.tap(find.text(reviewCardTitle));
  await settle(tester);
}

void main() {
  group('startApp et le bilan de la semaine', () {
    testWidgets('le journal donne un rédacteur : le bilan de l\'app démarrée '
        'met en mots avec lui', (tester) async {
      usePhoneScreen(tester);
      final writer = FakeReviewWriter();
      final repo = threeEntriesThisWeek();

      final app = await tester.runAsync(
        () => startApp(open: () async => journalOf(repo, reviewWriter: writer)),
      );
      await openReviewOf(tester, app!);

      expect(find.text('Ta semaine'), findsOneWidget);
      expect(writer.writeCalls, 1);
      expect(find.text(validReviewText), findsOneWidget);
      expect(find.text(writtenMention), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 40));
    });

    testWidgets('le texte du rédacteur du journal passe la validation de '
        'l\'app : une sortie à chiffre n\'est pas montrée', (tester) async {
      usePhoneScreen(tester);
      final writer = FakeReviewWriter(
        output: jsonText('Une semaine notée 3 jours.'),
      );
      final repo = threeEntriesThisWeek();

      final app = await tester.runAsync(
        () => startApp(open: () async => journalOf(repo, reviewWriter: writer)),
      );
      await openReviewOf(tester, app!);

      expect(writer.writeCalls, 1);
      expect(find.text(withheldText), findsOneWidget);
      expect(find.textContaining('3 jours'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 40));
    });

    testWidgets('le journal donne un rédacteur et le modèle est absent : '
        'rédacteur non appelé, message du modèle absent', (tester) async {
      usePhoneScreen(tester);
      final writer = FakeReviewWriter();
      final repo = threeEntriesThisWeek();

      final app = await tester.runAsync(
        () => startApp(
          open: () async => journalOf(
            repo,
            reviewWriter: writer,
            downloader: FakeModelDownloader(absentModel),
          ),
        ),
      );
      await openReviewOf(tester, app!);

      expect(writer.writeCalls, 0);
      expect(find.text(noModelText), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 40));
    });

    testWidgets('sans rédacteur dans le journal : le bilan s\'affiche avec '
        'ses chiffres, sans texte, sans plantage', (tester) async {
      usePhoneScreen(tester);
      final repo = threeEntriesThisWeek();

      final app = await tester.runAsync(
        () => startApp(open: () async => journalOf(repo)),
      );
      await openReviewOf(tester, app!);

      expect(find.text('Ta semaine'), findsOneWidget);
      expect(find.text('Entrées'), findsOneWidget);
      // « 3 » est aussi le chiffre de la pastille « Neutre » de la répartition
      // (charte : une pastille porte toujours son chiffre) : au moins un.
      expect(find.text('3'), findsWidgets);
      expect(find.text('Humeur moyenne'), findsOneWidget);
      expect(find.text(validReviewText), findsNothing);
      expect(find.text(writingText), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 40));
    });
  });
}
