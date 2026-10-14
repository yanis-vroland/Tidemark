// Démarrage réel du journal (spec 001, CA23, CA35 et cas limite « clé absente
// alors que la base existe ») : base fichier chiffrée, trousseau en mémoire.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/main.dart';
import 'package:tidemark/storage/app_database.dart';
import 'package:tidemark/storage/database_key.dart';

class InMemoryKeyStore implements KeyStore {
  String? stored;
  int writes = 0;

  @override
  Future<String?> read() async => stored;

  @override
  Future<void> write(String key) async {
    writes++;
    stored = key;
  }
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('tidemark_start_'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> closeRepository(Journal journal) =>
      (journal.entries as DriftEntryRepository).db.close();

  test(
    'CA23 : au premier lancement, la clé est créée et la base est ouverte',
    () async {
      final store = InMemoryKeyStore();

      final repository = await openJournal(folder: dir, keyStore: store);
      await repository.entries.addEntry(mood: 3);
      await closeRepository(repository);

      expect(store.writes, 1);
      expect(File('${dir.path}/journal.db').existsSync(), isTrue);
    },
  );

  test(
    'CA23 : au lancement suivant, la même clé rouvre la base et ses entrées',
    () async {
      final store = InMemoryKeyStore();
      final first = await openJournal(folder: dir, keyStore: store);
      await first.entries.addEntry(mood: 4, text: 'Première entrée.');
      await closeRepository(first);

      final second = await openJournal(folder: dir, keyStore: store);
      final entries = await second.entries.watchEntries().first;
      await closeRepository(second);

      expect(store.writes, 1);
      expect(entries.single.text, 'Première entrée.');
    },
  );

  test('Cas limite : base existante et clé absente, aucune clé n\'est créée et '
      'la base reste intacte', () async {
    final original = InMemoryKeyStore();
    final repository = await openJournal(folder: dir, keyStore: original);
    await repository.entries.addEntry(mood: 2, text: 'À ne pas perdre.');
    await closeRepository(repository);
    final file = File('${dir.path}/journal.db');
    final before = file.readAsBytesSync();

    final emptied = InMemoryKeyStore();
    await expectLater(
      openJournal(folder: dir, keyStore: emptied),
      throwsA(isA<DatabaseKeyMissingError>()),
    );

    expect(emptied.writes, 0);
    expect(emptied.stored, isNull);
    expect(file.readAsBytesSync(), before);
    // La clé d'origine ouvre toujours la base.
    final reopened = await openJournal(folder: dir, keyStore: original);
    expect(
      (await reopened.entries.watchEntries().first).single.text,
      'À ne pas perdre.',
    );
    await closeRepository(reopened);
  });

  group('CA35 : écran selon la cause', () {
    test('clé introuvable : écran d\'erreur « clé »', () async {
      final app = await startApp(
        open: () async => throw DatabaseKeyMissingError(),
      );

      expect(app, isA<StartupErrorApp>());
      expect((app as StartupErrorApp).keyMissing, isTrue);
    });

    test('autre cause : écran d\'erreur neutre', () async {
      final app = await startApp(
        open: () async => throw CipherUnavailableError(),
      );

      expect(app, isA<StartupErrorApp>());
      expect((app as StartupErrorApp).keyMissing, isFalse);
    });

    test('ouverture réussie : le journal', () async {
      final repository = await openJournal(
        folder: dir,
        keyStore: InMemoryKeyStore(),
      );
      final app = await startApp(open: () async => repository);
      await closeRepository(repository);

      expect(app, isA<TidemarkApp>());
    });
  });
}
