// Ajouté après la revue IA de la PR #22 (spec 003, CA14) : une annulation confirmée
// une fois la vérification commencée ne jette pas le fichier complet.
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/model/model_state.dart';

import '../support/fake_model_downloader.dart';
import '../support/model_texts.dart';
import '../support/ui_harness.dart';

void main() {
  testWidgets('CA14 : confirmer l\'annulation pendant la vérification ne '
      'l\'annule pas', (tester) async {
    usePhoneScreen(tester);
    final downloader = FakeModelDownloader(
      const ModelDownloading(receivedBytes: 500, totalBytes: 1000),
    );
    await showModelScreen(tester, downloader);
    await tester.tap(find.text(cancelButton));
    await settle(tester);
    downloader.emit(
      const ModelDownloading(
        receivedBytes: 1000,
        totalBytes: 1000,
        verifying: true,
      ),
    );
    await tester.pump();

    await tester.tap(find.text(cancelButton).last);
    await settle(tester);

    expect(downloader.cancelCalls, 0);
  });

  testWidgets('CA13 : confirmer l\'annulation pendant le transfert l\'annule '
      '(témoin du test précédent)', (tester) async {
    usePhoneScreen(tester);
    final downloader = FakeModelDownloader(
      const ModelDownloading(receivedBytes: 500, totalBytes: 1000),
    );
    await showModelScreen(tester, downloader);
    await tester.tap(find.text(cancelButton));
    await settle(tester);

    await tester.tap(find.text(cancelButton).last);
    await settle(tester);

    expect(downloader.cancelCalls, 1);
  });
}
