// Spec 004, CA36, au niveau du critère : trois entrées analysées dans le même
// lancement, avec une libération du modèle entre deux, ne font qu'un seul calcul
// de l'empreinte. File réelle sur le vrai `HttpModelDownloader` (dossier
// temporaire, faux transport, calcul compté) et un analyseur factice. Ajouté après
// la revue IA de la branche : jusque-là, le critère n'était prouvé qu'en
// combinant le test de la file et le CA35 du téléchargeur.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/analysis/analysis_queue.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/model/model_downloader.dart';

import '../support/fake_entry_repository.dart';
import '../support/fake_model_transport.dart';
import '../support/fake_mood_analyzer.dart';
import '../support/model_fixtures.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('tidemark_queue_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('spec 004 CA36 : trois entrées, modèle libéré entre chacune, une seule '
      'vérification de l\'empreinte', () async {
    final models = Directory('${tmp.path}/models')..createSync();
    File('${models.path}/${testSource.fileName}').writeAsBytesSync(modelBytes);
    var hashes = 0;
    final downloader = HttpModelDownloader(
      transport: FakeModelTransport(),
      folder: models,
      source: testSource,
      hashFile: (path) {
        hashes++;
        return sha256OfFile(path);
      },
    );
    await downloader.checkAtStartup();
    final repo = FakeEntryRepository();
    final analyzer = FakeMoodAnalyzer();
    final queue = AnalysisQueue(
      repository: repo,
      analyzer: analyzer,
      downloader: downloader,
    );
    addTearDown(queue.stop);

    Future<void> analyzed(int id) => eventually(
      () =>
          repo.entries.firstWhere((e) => e.id == id).analysisStatus !=
          AnalysisStatus.pending,
      reason: 'entrée $id analysée',
    );

    final first = repo.seed(
      mood: 3,
      text: 'Journée tranquille au jardin.',
      createdAt: DateTime(2026, 10, 10, 9),
    );
    queue.start();
    await analyzed(first.id);
    await queue.whenIdle;
    for (final text in ['Réunion longue.', 'Soirée calme.']) {
      final added = await repo.addEntry(mood: 3, text: text);
      await analyzed(added.id);
      await queue.whenIdle;
    }

    expect(analyzer.prepareCalls, 3, reason: 'modèle libéré entre chaque');
    expect(hashes, 1);
  });
}
