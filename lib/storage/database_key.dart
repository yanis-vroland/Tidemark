import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lieu où la clé de la base est gardée : trousseau iOS ou Keystore Android en
/// production, mémoire dans les tests.
abstract interface class KeyStore {
  Future<String?> read();
  Future<void> write(String key);

  /// Efface toute clé de l'app (suppression totale et nouvelle installation,
  /// spec 005). Sans effet si aucune clé n'est gardée.
  Future<void> deleteAll();
}

/// La base existe, mais sa clé est introuvable : ne jamais en créer une autre, qui
/// rendrait la base illisible pour toujours (spec 001, cas limites).
class DatabaseKeyMissingError extends StateError {
  DatabaseKeyMissingError() : super('Clé de la base introuvable.');
}

/// Clé de la base : lue dans [store], ou créée au premier lancement (256 bits
/// aléatoires, en hexadécimal) puis écrite dans [store]. Si [databaseExists] et
/// qu'aucune clé n'est lue, lève [DatabaseKeyMissingError] sans rien écrire.
Future<String> obtainDatabaseKey(
  KeyStore store, {
  Random? random,
  bool databaseExists = false,
}) async {
  final existing = await store.read();
  if (existing != null) return existing;
  if (databaseExists) throw DatabaseKeyMissingError();
  final source = random ?? Random.secure();
  final key = [
    for (var i = 0; i < 32; i++)
      source.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
  await store.write(key);
  return key;
}

/// [KeyStore] du téléphone : trousseau iOS (accessible après le premier
/// déverrouillage, jamais synchronisé avec iCloud) ou Keystore Android (ADR-002).
/// `resetOnError: false` : sur une erreur de déchiffrement, Android ne vide pas le
/// stockage, et la clé n'est pas perdue en silence.
class SecureKeyStore implements KeyStore {
  SecureKeyStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: false),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  static const _name = 'tidemark.database_key';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _name);

  @override
  Future<void> write(String key) => _storage.write(key: _name, value: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}
