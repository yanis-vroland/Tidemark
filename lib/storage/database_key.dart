import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lieu où la clé de la base est gardée : trousseau iOS ou Keystore Android en
/// production, mémoire dans les tests.
abstract interface class KeyStore {
  Future<String?> read();
  Future<void> write(String key);
}

/// Clé de la base : lue dans [store], ou créée au premier lancement (256 bits
/// aléatoires, en hexadécimal) puis écrite dans [store].
Future<String> obtainDatabaseKey(KeyStore store, {Random? random}) async {
  final existing = await store.read();
  if (existing != null) return existing;
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
class SecureKeyStore implements KeyStore {
  SecureKeyStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
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
}
