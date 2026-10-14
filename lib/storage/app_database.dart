import 'dart:io';

import 'package:characters/characters.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../entries/entry.dart';
import '../distress/distress_detector.dart';
import '../entries/entry_repository.dart';
import '../settings/settings_repository.dart';

part 'app_database.g.dart';

/// Table des entrées (spec 001, « Données »).
@DataClassName('EntryRow')
class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Forme documentée par drift pour une contrainte CHECK sur la colonne elle-même.
  // ignore: recursive_getters
  IntColumn get mood => integer().check(mood.isBetweenValues(1, 5))();
  TextColumn get body => text().named('text').nullable()();

  /// Instant de la saisie, en UTC.
  DateTimeColumn get createdAt => dateTime()();

  /// Décalage horaire local au moment de la saisie, en minutes.
  IntColumn get utcOffsetMinutes => integer()();
  TextColumn get analysisStatus => textEnum<AnalysisStatus>()();
}

/// Erreur levée quand le moteur SQLite n'a pas le chiffrement.
class CipherUnavailableError extends StateError {
  CipherUnavailableError()
    : super('SQLite sans chiffrement : base non ouverte.');
}

/// Refuse d'ouvrir une base qui serait écrite en clair (RM2) : sans
/// SQLite3MultipleCiphers, `PRAGMA cipher` ne rend aucune ligne. [rowCount] exécute
/// une requête et rend son nombre de lignes.
void ensureCipherAvailable(int Function(String sql) rowCount) {
  if (rowCount('PRAGMA cipher') == 0) throw CipherUnavailableError();
}

/// Base locale des entrées, chiffrée par SQLite3MultipleCiphers (ADR-002).
@DriftDatabase(tables: [Entries])
class AppDatabase extends _$AppDatabase {
  AppDatabase._(super.executor);

  /// Base en mémoire, non chiffrée, pour les tests.
  factory AppDatabase.memory() => AppDatabase._(NativeDatabase.memory());

  /// Ouvre (ou crée) la base chiffrée [file] avec la clé [key] (64 caractères
  /// hexadécimaux). Échoue au premier accès si la clé n'est pas celle de la base,
  /// ou si le moteur SQLite n'a pas le chiffrement.
  static Future<AppDatabase> openEncrypted(File file, String key) async {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(key)) {
      throw ArgumentError.value('…', 'key', '64 caractères hexadécimaux');
    }
    final executor = NativeDatabase.createInBackground(
      file,
      setup: (db) {
        ensureCipherAvailable((sql) => db.select(sql).length);
        db.execute("PRAGMA hexkey = '$key'");
        // Vérifie la clé tout de suite : une mauvaise clé fait échouer cette lecture.
        db.select('SELECT count(*) FROM sqlite_master');
        // Une entrée supprimée est écrasée, pas seulement libérée (RM15).
        db.execute('PRAGMA secure_delete = ON');
      },
    );
    return AppDatabase._(executor);
  }

  @override
  int get schemaVersion => 1;

  /// Nombre d'entrées, pour vérifier l'ouverture.
  Future<int> countEntries() async {
    final count = entries.id.count();
    final row = await (selectOnly(entries)..addColumns([count])).getSingle();
    return row.read(count)!;
  }
}

/// [EntryRepository] sur [AppDatabase]. [clock] donne l'heure locale de la saisie.
class DriftEntryRepository implements EntryRepository {
  DriftEntryRepository(this.db, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() clock;

  static Entry _toEntry(EntryRow row) => Entry(
    id: row.id,
    mood: row.mood,
    text: row.body,
    createdAt: row.createdAt.toUtc(),
    utcOffset: Duration(minutes: row.utcOffsetMinutes),
    analysisStatus: row.analysisStatus,
  );

  @override
  Stream<List<Entry>> watchEntries() {
    final query = db.select(db.entries)
      ..orderBy([
        (e) => OrderingTerm.desc(e.createdAt),
        (e) => OrderingTerm.desc(e.id),
      ]);
    return query.watch().map((rows) => rows.map(_toEntry).toList());
  }

  @override
  Future<Entry> addEntry({
    required int mood,
    String? text,
    AnalysisStatus status = AnalysisStatus.pending,
  }) async {
    if (mood < 1 || mood > 5) {
      throw ArgumentError.value(mood, 'mood', 'de 1 à 5');
    }
    final body = (text == null || text.trim().isEmpty) ? null : text;
    if (body != null && body.characters.length > maxTextLength) {
      throw ArgumentError.value(
        body.characters.length,
        'text',
        '$maxTextLength caractères au plus',
      );
    }
    final now = clock();
    // À la seconde : c'est la précision de la base, l'entrée rendue est donc
    // identique à l'entrée relue.
    final utc = now.toUtc();
    final createdAt = DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
      utc.second,
    );
    final status = body == null
        ? AnalysisStatus.skipped
        : AnalysisStatus.pending;
    final id = await db
        .into(db.entries)
        .insert(
          EntriesCompanion.insert(
            mood: mood,
            body: Value(body),
            createdAt: createdAt,
            utcOffsetMinutes: now.timeZoneOffset.inMinutes,
            analysisStatus: status,
          ),
        );
    return Entry(
      id: id,
      mood: mood,
      text: body,
      createdAt: createdAt,
      utcOffset: now.timeZoneOffset,
      analysisStatus: status,
    );
  }

  @override
  Future<void> deleteEntry(int id) =>
      (db.delete(db.entries)..where((e) => e.id.equals(id))).go();

  @override
  Future<List<Entry>> latestEntries(int count) => throw UnimplementedError();

  @override
  Future<List<Entry>> pendingEntriesWithText() => throw UnimplementedError();

  @override
  Future<void> markSkipped(Iterable<int> ids) => throw UnimplementedError();
}

/// [SettingsRepository] sur [AppDatabase] (spec 002) : table `settings`, une ligne.
class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this.db);

  final AppDatabase db;

  @override
  Stream<LowMoodSensitivity> watchLowMoodSensitivity() =>
      throw UnimplementedError();

  @override
  Future<LowMoodSensitivity> readLowMoodSensitivity() =>
      throw UnimplementedError();

  @override
  Future<void> setLowMoodSensitivity(LowMoodSensitivity sensitivity) =>
      throw UnimplementedError();
}
