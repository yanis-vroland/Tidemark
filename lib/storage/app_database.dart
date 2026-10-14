import 'dart:io';

import 'package:characters/characters.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../distress/distress_detector.dart';
import '../entries/entry.dart';
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

/// Réglages de la personne (spec 002) : une seule ligne, d'identifiant 1.
@DataClassName('SettingsRow')
class Settings extends Table {
  // Forme documentée par drift pour une contrainte CHECK sur la colonne elle-même.
  // ignore: recursive_getters
  IntColumn get id => integer().check(id.equals(1))();

  /// Degré de sensibilité aux humeurs basses, par son nom (`LowMoodSensitivity`).
  TextColumn get lowMoodSensitivity => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
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
@DriftDatabase(tables: [Entries, Settings])
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Version 2 : table des réglages (spec 002).
      if (from < 2) await m.createTable(settings);
    },
  );

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
    // Sans texte, rien à analyser (RM24), quel que soit le statut demandé.
    final analysisStatus = body == null ? AnalysisStatus.skipped : status;
    final id = await db
        .into(db.entries)
        .insert(
          EntriesCompanion.insert(
            mood: mood,
            body: Value(body),
            createdAt: createdAt,
            utcOffsetMinutes: now.timeZoneOffset.inMinutes,
            analysisStatus: analysisStatus,
          ),
        );
    return Entry(
      id: id,
      mood: mood,
      text: body,
      createdAt: createdAt,
      utcOffset: now.timeZoneOffset,
      analysisStatus: analysisStatus,
    );
  }

  @override
  Future<void> deleteEntry(int id) =>
      (db.delete(db.entries)..where((e) => e.id.equals(id))).go();

  @override
  Future<List<Entry>> latestEntries(int count) async {
    if (count <= 0) return const [];
    final query = db.select(db.entries)
      ..orderBy([
        (e) => OrderingTerm.desc(e.createdAt),
        (e) => OrderingTerm.desc(e.id),
      ])
      ..limit(count);
    return (await query.get()).map(_toEntry).toList();
  }

  @override
  Future<List<Entry>> pendingEntriesWithText() async {
    final query = db.select(db.entries)
      ..where(
        (e) =>
            e.analysisStatus.equalsValue(AnalysisStatus.pending) &
            e.body.isNotNull(),
      );
    return (await query.get()).map(_toEntry).toList();
  }

  @override
  Future<void> markSkipped(Iterable<int> ids) =>
      (db.update(db.entries)..where((e) => e.id.isIn(ids))).write(
        const EntriesCompanion(analysisStatus: Value(AnalysisStatus.skipped)),
      );
}

/// [SettingsRepository] sur [AppDatabase] (spec 002) : table `settings`, une ligne.
class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this.db);

  final AppDatabase db;

  /// Degré lu en base ; `normal` si rien n'est choisi ou si la valeur est inconnue
  /// (CA21) : le garde-fou ne se désactive jamais.
  static LowMoodSensitivity _parse(SettingsRow? row) =>
      LowMoodSensitivity.values.asNameMap()[row?.lowMoodSensitivity] ??
      LowMoodSensitivity.normal;

  SimpleSelectStatement<$SettingsTable, SettingsRow> get _row =>
      db.select(db.settings)..where((s) => s.id.equals(1));

  @override
  Stream<LowMoodSensitivity> watchLowMoodSensitivity() =>
      _row.watchSingleOrNull().map(_parse);

  @override
  Future<LowMoodSensitivity> readLowMoodSensitivity() async =>
      _parse(await _row.getSingleOrNull());

  @override
  Future<void> setLowMoodSensitivity(LowMoodSensitivity sensitivity) => db
      .into(db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          id: const Value(1),
          lowMoodSensitivity: sensitivity.name,
        ),
      );
}
