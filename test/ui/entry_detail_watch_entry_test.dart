// Détail d'une entrée observée seule (issue #39, refactor sans changement de
// comportement) : l'écran s'abonne à `watchEntry(id)` de l'entrée affichée, une
// fois, et suit l'entrée qu'on lui donne, même si l'écran est réutilisé pour une
// autre entrée. Faux seulement : aucun modèle, aucune base.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/analysis/mood_analyzer.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/ui/analysis_scope.dart';
import 'package:tidemark/ui/screens/entry_detail_screen.dart';

import '../support/analysis_harness.dart';
import '../support/fake_entry_repository.dart';
import '../support/fake_model_downloader.dart';
import '../support/ui_harness.dart';

/// Dépôt qui note les identifiants observés par `watchEntry`.
class WatchEntryCountingRepository extends FakeEntryRepository {
  WatchEntryCountingRepository({super.clock});

  final List<int> watchedIds = [];

  @override
  Stream<Entry?> watchEntry(int id) {
    watchedIds.add(id);
    return super.watchEntry(id);
  }
}

void main() {
  late WatchEntryCountingRepository repo;
  late FakeModelDownloader downloader;
  late StubAnalysisQueue queue;

  setUp(() {
    repo = WatchEntryCountingRepository(clock: () => fixedNow);
    downloader = FakeModelDownloader(readyModel);
    queue = StubAnalysisQueue();
  });

  Widget detail(Entry entry) => AnalysisScope(
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

  testWidgets('issue #39 : le détail observe sa seule entrée, une fois, même '
      'reconstruit', (tester) async {
    usePhoneScreen(tester);
    final entry = repo.seed(
      mood: 3,
      text: 'Texte de l\'entrée affichée',
      createdAt: DateTime(2026, 10, 14, 21, 40),
    );
    repo.seed(
      mood: 4,
      text: 'Texte d\'une autre entrée',
      createdAt: DateTime(2026, 10, 14, 18),
    );

    await tester.pumpWidget(detail(entry));
    await settle(tester);
    await tester.pumpWidget(detail(entry));
    await settle(tester);

    expect(repo.watchedIds, [entry.id]);

    // L'entrée observée change : le détail la suit, sans nouvel abonnement.
    await repo.saveAnalysis(entry.id, Tagged(fatigueCalmeTravail));
    await settle(tester);
    expect(find.text('fatigue'), findsOneWidget);
    expect(repo.watchedIds, [entry.id]);
  });

  testWidgets('issue #32 et #39 : reconstruit par la file, le détail ne '
      'se réabonne pas à son entrée', (tester) async {
    usePhoneScreen(tester);
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

    await tester.pumpWidget(detail(entry));
    await settle(tester);
    for (var i = 0; i < 3; i++) {
      queue.setCurrent(other.id);
      await settle(tester);
      queue.setCurrent(null);
      await settle(tester);
    }

    expect(repo.watchedIds, [entry.id]);
  });

  testWidgets('issue #39 : réutilisé pour une autre entrée, l\'écran '
      'n\'affiche jamais les étiquettes de la précédente, même avant la '
      'première émission', (tester) async {
    usePhoneScreen(tester);
    final first = repo.seed(
      mood: 3,
      text: 'Première entrée',
      createdAt: DateTime(2026, 10, 14, 18),
    );
    await repo.saveAnalysis(first.id, Tagged([emotion('joie')]));
    final second = repo.seed(
      mood: 4,
      text: 'Seconde entrée',
      createdAt: DateTime(2026, 10, 14, 21, 40),
    );

    await tester.pumpWidget(detail(first));
    await settle(tester);
    expect(find.text('joie'), findsOneWidget);

    // Une seule image : le nouveau flux n'a encore rien émis.
    await tester.pumpWidget(detail(second));
    expect(find.text('Seconde entrée'), findsOneWidget);
    expect(find.text('joie'), findsNothing);

    await settle(tester);
    expect(find.text('joie'), findsNothing);
  });

  testWidgets('issue #39 : le même écran réutilisé pour une autre entrée '
      'observe la nouvelle', (tester) async {
    usePhoneScreen(tester);
    final first = repo.seed(
      mood: 3,
      text: 'Première entrée',
      createdAt: DateTime(2026, 10, 14, 18),
    );
    // Passée à l'écran telle qu'elle était à l'ouverture (« en attente ») ;
    // étiquetée depuis.
    final second = repo.seed(
      mood: 4,
      text: 'Seconde entrée',
      createdAt: DateTime(2026, 10, 14, 21, 40),
    );
    await repo.saveAnalysis(second.id, Tagged(fatigueCalmeTravail));

    await tester.pumpWidget(detail(first));
    await settle(tester);
    expect(find.text('fatigue'), findsNothing);

    await tester.pumpWidget(detail(second));
    await settle(tester);

    expect(find.text('Seconde entrée'), findsOneWidget);
    expect(find.text('fatigue'), findsOneWidget);
    expect(repo.watchedIds, [first.id, second.id]);
  });
}
