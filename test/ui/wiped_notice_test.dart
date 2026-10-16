// Message de fin de la suppression totale (spec 005, CA18, CA19) : il disparaît
// dès la première entrée, et ne revient pas si cette entrée est supprimée ensuite.
// Revue IA de la PR.
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/main.dart';

import '../support/fake_entry_repository.dart';
import '../support/fake_model_downloader.dart';
import '../support/fake_settings_repository.dart';
import '../support/ui_harness.dart';

const doneTitle = 'Toutes tes données ont été supprimées';

void main() {
  testWidgets('CA19 : le message de fin ne revient pas après la suppression '
      'de la première entrée', (tester) async {
    usePhoneScreen(tester);
    final repo = FakeEntryRepository();
    await tester.pumpWidget(
      TidemarkApp(
        repository: repo,
        settings: FakeSettingsRepository(),
        downloader: FakeModelDownloader(readyModel),
        clock: () => fixedNow,
        wiped: true,
      ),
    );
    await settle(tester);
    expect(find.text(doneTitle), findsOneWidget);

    final entry = await repo.addEntry(mood: 3);
    await settle(tester);
    expect(find.text(doneTitle), findsNothing);

    await repo.deleteEntry(entry.id);
    await settle(tester);

    expect(find.text('Ta première entrée apparaîtra ici'), findsOneWidget);
    expect(find.text(doneTitle), findsNothing);
  });
}
