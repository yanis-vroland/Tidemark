import 'dart:math';

/// Lieu où la clé de la base est gardée : trousseau iOS ou Keystore Android en
/// production, mémoire dans les tests.
abstract interface class KeyStore {
  Future<String?> read();
  Future<void> write(String key);
}

/// Clé de la base : lue dans [store], ou créée au premier lancement (256 bits
/// aléatoires, en hexadécimal) puis écrite dans [store].
Future<String> obtainDatabaseKey(KeyStore store, {Random? random}) =>
    throw UnimplementedError('obtainDatabaseKey');
