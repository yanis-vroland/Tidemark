import 'dart:io';

import '../entries/entry.dart';
import '../entries/entry_repository.dart';

/// Base locale des entrées, chiffrée par SQLite3MultipleCiphers (ADR-002).
class AppDatabase {
  /// Base en mémoire, non chiffrée, pour les tests.
  factory AppDatabase.memory() =>
      throw UnimplementedError('AppDatabase.memory');

  /// Ouvre (ou crée) la base chiffrée [file] avec la clé [key]. Échoue si la clé
  /// n'est pas celle de la base.
  static Future<AppDatabase> openEncrypted(File file, String key) =>
      throw UnimplementedError('AppDatabase.openEncrypted');

  /// Nombre d'entrées, pour vérifier l'ouverture.
  Future<int> countEntries() => throw UnimplementedError('countEntries');

  Future<void> close() => throw UnimplementedError('close');
}

/// [EntryRepository] sur [AppDatabase]. [clock] donne l'heure locale de la saisie.
class DriftEntryRepository implements EntryRepository {
  DriftEntryRepository(this.db, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() clock;

  @override
  Stream<List<Entry>> watchEntries() =>
      throw UnimplementedError('watchEntries');

  @override
  Future<Entry> addEntry({required int mood, String? text}) =>
      throw UnimplementedError('addEntry');

  @override
  Future<void> deleteEntry(int id) => throw UnimplementedError('deleteEntry');
}
