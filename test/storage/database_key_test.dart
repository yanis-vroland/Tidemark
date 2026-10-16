import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/storage/database_key.dart';

/// Trousseau en mémoire, qui note chaque écriture.
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

  // Ajouté par la spec 005 : le contrat KeyStore gagne deleteAll.
  @override
  Future<void> deleteAll() async => stored = null;
}

final sixtyFourHex = RegExp(r'^[0-9a-fA-F]{64}$');

void main() {
  test('CA23 : au premier lancement, une clé de 64 caractères hexadécimaux '
      '(256 bits) est créée et écrite', () async {
    final store = InMemoryKeyStore();

    final key = await obtainDatabaseKey(store, random: Random(42));

    expect(key, matches(sixtyFourHex));
    expect(store.writes, 1);
    expect(store.stored, key);
  });

  test('CA23 : aux lancements suivants, la même clé est relue, sans '
      'être recréée', () async {
    final store = InMemoryKeyStore();
    final first = await obtainDatabaseKey(store, random: Random(42));

    final second = await obtainDatabaseKey(store, random: Random(7));
    final third = await obtainDatabaseKey(store);

    expect(second, first);
    expect(third, first);
    expect(store.writes, 1);
  });

  test(
    'CA23 : une clé déjà dans le trousseau est rendue telle quelle',
    () async {
      final store = InMemoryKeyStore()..stored = 'ab' * 32;

      final key = await obtainDatabaseKey(store, random: Random(1));

      expect(key, 'ab' * 32);
      expect(store.writes, 0);
    },
  );

  test('CA23 : la clé vient bien du générateur aléatoire fourni', () async {
    final keyFromSeed1 = await obtainDatabaseKey(
      InMemoryKeyStore(),
      random: Random(1),
    );
    final keyFromSeed1Again = await obtainDatabaseKey(
      InMemoryKeyStore(),
      random: Random(1),
    );
    final keyFromSeed2 = await obtainDatabaseKey(
      InMemoryKeyStore(),
      random: Random(2),
    );

    expect(keyFromSeed1Again, keyFromSeed1);
    expect(keyFromSeed2, isNot(keyFromSeed1));
  });

  test(
    'CA23 : sans générateur fourni, la clé est tout de même valide',
    () async {
      final key = await obtainDatabaseKey(InMemoryKeyStore());

      expect(key, matches(sixtyFourHex));
    },
  );

  test('CA23 : la clé n\'est pas faite d\'un seul caractère répété', () async {
    final key = await obtainDatabaseKey(InMemoryKeyStore(), random: Random(3));

    expect(key.split('').toSet().length, greaterThan(4));
  });

  test('Cas limite : clé absente alors que la base existe, aucune clé n\'est '
      'créée ni écrite', () async {
    final store = InMemoryKeyStore();

    await expectLater(
      obtainDatabaseKey(store, random: Random(1), databaseExists: true),
      throwsA(isA<DatabaseKeyMissingError>()),
    );
    expect(store.writes, 0);
    expect(store.stored, isNull);
  });

  test(
    'Cas limite : clé présente et base existante, la clé est rendue',
    () async {
      final store = InMemoryKeyStore()..stored = 'cd' * 32;

      final key = await obtainDatabaseKey(store, databaseExists: true);

      expect(key, 'cd' * 32);
      expect(store.writes, 0);
    },
  );
}
