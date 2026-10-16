// Abonnements du détail d'une entrée (issue #32, refactor sans changement de
// comportement) : reconstruire l'écran ne doit pas réabonner les flux du dépôt
// (`watchEntries()`) ni du modèle (`watch()`) tant que la section reste sur « En
// attente d'analyse ». Les faux comptent les abonnements ; aucun modèle, aucun
// réseau.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/ui/analysis_scope.dart';
import 'package:tidemark/ui/screens/entry_detail_screen.dart';

import '../support/analysis_harness.dart';
import '../support/fake_entry_repository.dart';
import '../support/fake_model_downloader.dart';
import '../support/ui_harness.dart';

const queuedText = "En attente d'analyse sur ton téléphone.";

/// Dépôt qui compte les observations du journal.
class WatchCountingRepository extends FakeEntryRepository {
  WatchCountingRepository({super.clock});

  int watchCalls = 0;

  @override
  Stream<List<Entry>> watchEntries() {
    watchCalls++;
    return super.watchEntries();
  }
}

void main() {
  testWidgets('issue #32 : le détail d\'une entrée en attente, modèle prêt, '
      'reconstruit plusieurs fois, ne s\'abonne qu\'une fois au journal et '
      'une fois au modèle', (tester) async {
    usePhoneScreen(tester);
    final repo = WatchCountingRepository(clock: () => fixedNow);
    final downloader = WatchCountingDownloader(readyModel);
    final queue = StubAnalysisQueue();
    final entry = repo.seed(
      mood: 3,
      text: 'Texte de l\'entrée affichée',
      createdAt: DateTime(2026, 10, 14, 21, 40),
    );
    final other = repo.seed(
      mood: 4,
      text: 'Texte d\'une autre entrée',
      createdAt: DateTime(2026, 10, 14, 18),
    );

    // Même arbre, mêmes paramètres : une nouvelle instance de l'écran à chaque appel.
    Widget app() => AnalysisScope(
      queue: queue,
      child: testApp(
        EntryDetailScreen(
          entry: entry,
          repository: repo,
          downloader: downloader,
          clock: () => fixedNow,
        ),
      ),
    );

    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.text(queuedText), findsOneWidget);

    // La file notifie : l'écran se reconstruit, la section reste « en attente ».
    for (var i = 0; i < 3; i++) {
      queue.setCurrent(other.id);
      await settle(tester);
      queue.setCurrent(null);
      await settle(tester);
    }
    expect(find.text(queuedText), findsOneWidget);

    // Nouvelle instance de l'écran, mêmes paramètres.
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.text(queuedText), findsOneWidget);

    expect(
      repo.watchCalls,
      1,
      reason: 'watchEntries() ne doit pas être rappelé à chaque reconstruction',
    );
    expect(
      downloader.watchCalls,
      1,
      reason: 'watch() ne doit pas être rappelé à chaque reconstruction',
    );
  });
}
