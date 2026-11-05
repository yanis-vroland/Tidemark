// Stockage de la spec 010 : schéma en version 5, table `entry_topics`, réglage
// `welcome_shown` (spec 009), sujets rendus par chaque lecture du dépôt, cascade à la
// suppression, migration de la version 4 à la version 5 sans perte (CA4, CA9, CA10).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:tidemark/analysis/mood_analyzer.dart';
import 'package:tidemark/distress/distress_detector.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/entries/topic.dart';
import 'package:tidemark/export/journal_exporter.dart';
import 'package:tidemark/storage/app_database.dart';
import 'package:tidemark/wipe/journal_wiper.dart';

import '../support/wipe_harness.dart' show WipeEnv;

const validKey =
    '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
const otherKey =
    'ffeeddccbbaa99887766554433221100ffeeddccbbaa99887766554433221100';

Future<int> count(AppDatabase db, String table, {int? entryId}) async {
  final row = await db
      .customSelect(
        entryId == null
            ? 'SELECT count(*) AS n FROM $table'
            : 'SELECT count(*) AS n FROM $table WHERE entry_id = $entryId',
      )
      .getSingle();
  return row.read<int>('n');
}

/// Sujets d'une entrée tels qu'écrits en base, dans l'ordre de `position`.
Future<List<String>> storedTopics(AppDatabase db, int entryId) async {
  final rows = await db
      .customSelect(
        'SELECT topic FROM entry_topics WHERE entry_id = $entryId '
        'ORDER BY position',
      )
      .get();
  return [for (final row in rows) row.read<String>('topic')];
}

Future<Entry> single(DriftEntryRepository repo, int id) async =>
    (await repo.watchEntries().first).firstWhere((e) => e.id == id);

/// Base du schéma 4 (spec 004), écrite sans passer par le code de l'app : trois
/// tables, des entrées dont une étiquetée, des réglages.
void writeSchema4(File file) {
  final raw = sqlite.sqlite3.open(file.path);
  raw.execute("PRAGMA hexkey = '$validKey'");
  raw.execute(
    'CREATE TABLE entries ('
    'id INTEGER PRIMARY KEY AUTOINCREMENT, '
    'mood INTEGER NOT NULL CHECK (mood BETWEEN 1 AND 5), '
    'text TEXT NULL, '
    'created_at INTEGER NOT NULL, '
    'utc_offset_minutes INTEGER NOT NULL, '
    'analysis_status TEXT NOT NULL)',
  );
  raw.execute(
    "INSERT INTO entries (mood, text, created_at, utc_offset_minutes, "
    "analysis_status) VALUES (2, 'Avant la migration.', 1791000000, 120, 'tagged')",
  );
  raw.execute(
    "INSERT INTO entries (mood, text, created_at, utc_offset_minutes, "
    "analysis_status) VALUES (4, NULL, 1791003600, -60, 'skipped')",
  );
  raw.execute(
    'CREATE TABLE settings ('
    'id INTEGER NOT NULL CHECK (id = 1), '
    'low_mood_sensitivity TEXT NOT NULL, '
    'model_offer_shown INTEGER NOT NULL DEFAULT 0, '
    'PRIMARY KEY (id))',
  );
  raw.execute(
    "INSERT INTO settings (id, low_mood_sensitivity, model_offer_shown) "
    "VALUES (1, 'high', 1)",
  );
  raw.execute(
    'CREATE TABLE tags ('
    'id INTEGER PRIMARY KEY AUTOINCREMENT, '
    'entry_id INTEGER NOT NULL REFERENCES entries (id) ON DELETE CASCADE, '
    'label TEXT NOT NULL, '
    'kind TEXT NOT NULL, '
    'position INTEGER NOT NULL, '
    'UNIQUE (entry_id, label))',
  );
  raw.execute(
    "INSERT INTO tags (entry_id, label, kind, position) VALUES "
    "(1, 'fatigue', 'emotion', 0), (1, 'sommeil', 'theme', 1)",
  );
  raw.execute('PRAGMA user_version = 4');
  raw.close();
}

void main() {
  group('schéma 5 sur base en mémoire', () {
    late AppDatabase db;
    late DriftEntryRepository repo;

    setUp(() {
      db = AppDatabase.memory();
      repo = DriftEntryRepository(
        db,
        clock: () => DateTime(2026, 10, 14, 21, 40),
      );
    });

    tearDown(() async => await db.close());

    test('CA9 : le schéma est en version 5', () {
      expect(db.schemaVersion, 5);
    });

    test('CA9 : la table entry_topics a ses quatre colonnes', () async {
      final rows = await db
          .customSelect('PRAGMA table_info(entry_topics)')
          .get();

      expect(
        [for (final r in rows) r.read<String>('name')],
        ['id', 'entry_id', 'topic', 'position'],
      );
    });

    test('CA10 : entry_id est une clé étrangère vers entries, supprimée en '
        'cascade', () async {
      final rows = await db
          .customSelect('PRAGMA foreign_key_list(entry_topics)')
          .get();

      expect(rows, hasLength(1));
      expect(rows.single.read<String>('table'), 'entries');
      expect(rows.single.read<String>('from'), 'entry_id');
      expect(rows.single.read<String>('on_delete'), 'CASCADE');
    });

    test('CA9 : le réglage « bienvenue vue » vaut faux par défaut', () async {
      await db.customStatement(
        "INSERT INTO settings (id, low_mood_sensitivity) VALUES (1, 'normal')",
      );

      final row = await db
          .customSelect('SELECT welcome_shown FROM settings WHERE id = 1')
          .getSingle();

      expect(row.read<int>('welcome_shown'), 0);
    });

    test('CA4 : une entrée enregistrée avec ses sujets les rend dans l\'ordre '
        'de la liste, quel que soit l\'ordre donné', () async {
      final saved = await repo.addEntry(
        mood: 4,
        text: 'Bonne journée.',
        topics: [Topic.nature, Topic.sleep, Topic.family],
      );

      expect(saved.topics, [Topic.sleep, Topic.family, Topic.nature]);
      expect(await storedTopics(db, saved.id), ['sleep', 'family', 'nature']);
    });

    test(
      'CA4 : sans sujet, l\'entrée n\'en a aucun et rien n\'est écrit',
      () async {
        final saved = await repo.addEntry(mood: 3, text: 'Texte.');

        expect(saved.topics, isEmpty);
        expect(await count(db, 'entry_topics'), 0);
      },
    );

    test('CA4 : les six sujets peuvent être choisis', () async {
      final saved = await repo.addEntry(
        mood: 5,
        topics: Topic.values.reversed.toList(),
      );

      expect(saved.topics, Topic.values);
      expect(await count(db, 'entry_topics', entryId: saved.id), 6);
    });

    test('CA4 : les sujets sont rendus par watchEntries, watchEntry, '
        'latestEntries et allEntriesWithTags', () async {
      final saved = await repo.addEntry(
        mood: 4,
        text: 'Balade.',
        topics: [Topic.sport, Topic.friends],
      );
      await repo.addEntry(mood: 3);
      final expected = [Topic.friends, Topic.sport];

      expect((await single(repo, saved.id)).topics, expected);
      expect((await repo.watchEntry(saved.id).first)!.topics, expected);
      expect(
        (await repo.latestEntries(5))
            .firstWhere((e) => e.id == saved.id)
            .topics,
        expected,
      );
      expect(
        (await repo.allEntriesWithTags())
            .firstWhere((e) => e.id == saved.id)
            .topics,
        expected,
      );
    });

    test('CA4 : les sujets d\'une entrée ne vont pas sur une autre', () async {
      final a = await repo.addEntry(mood: 4, topics: [Topic.work]);
      final b = await repo.addEntry(mood: 2, topics: [Topic.family]);
      final c = await repo.addEntry(mood: 3);

      expect((await single(repo, a.id)).topics, [Topic.work]);
      expect((await single(repo, b.id)).topics, [Topic.family]);
      expect((await single(repo, c.id)).topics, isEmpty);
    });

    test('CA4 : le statut d\'analyse ne dépend pas des sujets : sans texte, '
        '« non analysée » ; avec texte, « en attente »', () async {
      final bare = await repo.addEntry(mood: 4, topics: [Topic.nature]);
      final written = await repo.addEntry(
        mood: 4,
        text: 'Un texte.',
        topics: [Topic.nature],
      );

      expect(bare.analysisStatus, AnalysisStatus.skipped);
      expect(written.analysisStatus, AnalysisStatus.pending);
      expect(await repo.pendingEntriesWithText(), hasLength(1));
    });

    test('CA4 : une entrée en détresse (statut « non analysée » décidé par '
        'l\'appelant) garde ses sujets', () async {
      final saved = await repo.addEntry(
        mood: 1,
        text: 'Texte.',
        status: AnalysisStatus.skipped,
        topics: [Topic.work],
      );

      expect(saved.analysisStatus, AnalysisStatus.skipped);
      expect((await single(repo, saved.id)).topics, [Topic.work]);
    });

    test('CA4 : l\'analyse d\'une entrée garde ses sujets et ses étiquettes '
        'à part', () async {
      final saved = await repo.addEntry(
        mood: 4,
        text: 'Texte.',
        topics: [Topic.work],
      );

      await repo.saveAnalysis(
        saved.id,
        const Tagged([
          Tag('fatigue', TagKind.emotion),
          Tag('travail', TagKind.theme),
        ]),
      );

      final read = await single(repo, saved.id);
      expect(read.topics, [Topic.work]);
      expect(read.tags.map((t) => t.label), ['fatigue', 'travail']);
    });

    test('CA4 : markSkipped garde les sujets', () async {
      final saved = await repo.addEntry(
        mood: 4,
        text: 'Texte.',
        topics: [Topic.friends],
      );

      await repo.markSkipped([saved.id]);

      expect((await single(repo, saved.id)).topics, [Topic.friends]);
    });

    test(
      'CA9 : un sujet écrit en base est relu comme sujet de l\'entrée',
      () async {
        final saved = await repo.addEntry(mood: 4);
        await db.customStatement(
          'INSERT INTO entry_topics (entry_id, topic, position) '
          "VALUES (${saved.id}, 'sport', 0)",
        );

        expect((await single(repo, saved.id)).topics, [Topic.sport]);
      },
    );

    test('CA10 : supprimer une entrée efface ses sujets, pas ceux des '
        'autres', () async {
      final doomed = await repo.addEntry(
        mood: 4,
        topics: [Topic.friends, Topic.sport],
      );
      final kept = await repo.addEntry(mood: 3, topics: [Topic.nature]);

      await repo.deleteEntry(doomed.id);

      expect(await count(db, 'entry_topics', entryId: doomed.id), 0);
      expect(await count(db, 'entry_topics'), 1);
      expect((await single(repo, kept.id)).topics, [Topic.nature]);
    });

    test('CA10 : les clés étrangères sont actives (sans elles, la cascade '
        'serait ignorée)', () async {
      final row = await db.customSelect('PRAGMA foreign_keys').getSingle();

      expect(row.read<int>('foreign_keys'), 1);
    });

    test('A10 : un sujet inconnu en base (version plus récente puis retour '
        'arrière) est ignoré, sans empêcher la lecture du journal ni '
        'l\'export', () async {
      final mixed = await repo.addEntry(
        mood: 4,
        text: 'Avec un sujet connu.',
        topics: [Topic.friends],
      );
      final onlyUnknown = await repo.addEntry(mood: 3);
      await db.customStatement(
        'INSERT INTO entry_topics (entry_id, topic, position) VALUES '
        "(${mixed.id}, 'future_topic', 1), "
        "(${onlyUnknown.id}, 'future_topic', 0)",
      );

      final watched = await repo.watchEntries().first;
      expect(watched.firstWhere((e) => e.id == mixed.id).topics, [
        Topic.friends,
      ]);
      expect(watched.firstWhere((e) => e.id == onlyUnknown.id).topics, isEmpty);
      expect((await repo.watchEntry(mixed.id).first)!.topics, [Topic.friends]);
      expect((await repo.watchEntry(onlyUnknown.id).first)!.topics, isEmpty);
      expect((await repo.latestEntries(2)).map((e) => e.topics), [
        isEmpty,
        [Topic.friends],
      ]);

      final all = await repo.allEntriesWithTags();
      expect(all.map((e) => e.topics), [
        [Topic.friends],
        isEmpty,
      ]);
      final json = const JournalExporter().buildExport(
        entries: all,
        sensitivity: LowMoodSensitivity.normal,
        exportedAt: DateTime.utc(2026, 10, 14, 20),
      );
      final exported = ((jsonDecode(json) as Map)['entries'] as List)
          .cast<Map<String, dynamic>>();
      expect(exported.map((e) => e['topics']), [
        ['amis'],
        isEmpty,
      ]);
    });
  });

  group('base chiffrée sur fichier', () {
    late Directory dir;
    late File file;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('tidemark_v5_');
      file = File('${dir.path}/journal.db');
    });

    tearDown(() => dir.deleteSync(recursive: true));

    group('migration du schéma 4 vers le 5 (CA9)', () {
      test('CA9 : une base en version 4 est ouverte en version 5 : humeur, '
          'texte, date, statut et étiquettes intacts, aucun sujet', () async {
        writeSchema4(file);

        final db = await AppDatabase.openEncrypted(file, validKey);
        addTearDown(db.close);

        expect(db.schemaVersion, 5);
        final entries = await DriftEntryRepository(db).watchEntries().first;
        expect(entries, hasLength(2));
        final tagged = entries.firstWhere(
          (e) => e.text == 'Avant la migration.',
        );
        expect(tagged.mood, 2);
        expect(
          tagged.createdAt,
          DateTime.fromMillisecondsSinceEpoch(1791000000 * 1000, isUtc: true),
        );
        expect(tagged.utcOffset, const Duration(minutes: 120));
        expect(tagged.analysisStatus, AnalysisStatus.tagged);
        expect(tagged.tags.map((t) => (t.label, t.kind)), [
          ('fatigue', TagKind.emotion),
          ('sommeil', TagKind.theme),
        ]);
        final bare = entries.firstWhere((e) => e.text == null);
        expect(bare.mood, 4);
        expect(bare.utcOffset, const Duration(minutes: -60));
        expect(bare.analysisStatus, AnalysisStatus.skipped);
        expect(entries.expand((e) => e.topics), isEmpty);
        expect(await count(db, 'entry_topics'), 0);
      });

      test('CA9 : les réglages sont intacts et « bienvenue vue » est créé à '
          'faux', () async {
        writeSchema4(file);

        final db = await AppDatabase.openEncrypted(file, validKey);
        addTearDown(db.close);

        final settings = DriftSettingsRepository(db);
        expect(
          await settings.readLowMoodSensitivity(),
          LowMoodSensitivity.high,
        );
        expect(await settings.readModelOfferShown(), isTrue);
        final row = await db
            .customSelect('SELECT welcome_shown FROM settings WHERE id = 1')
            .getSingle();
        expect(row.read<int>('welcome_shown'), 0);
      });

      test('CA9 : après la migration, une entrée ancienne peut recevoir des '
          'sujets ; la cascade et les clés étrangères fonctionnent', () async {
        writeSchema4(file);
        final db = await AppDatabase.openEncrypted(file, validKey);
        addTearDown(db.close);
        final repo = DriftEntryRepository(db);

        final fresh = await repo.addEntry(
          mood: 5,
          text: 'Après la migration.',
          topics: [Topic.sport, Topic.sleep],
        );

        expect((await single(repo, fresh.id)).topics, [
          Topic.sleep,
          Topic.sport,
        ]);
        final foreignKeys = await db
            .customSelect('PRAGMA foreign_keys')
            .getSingle();
        expect(foreignKeys.read<int>('foreign_keys'), 1);
        await repo.deleteEntry(fresh.id);
        expect(await count(db, 'entry_topics'), 0);
        final old = (await repo.watchEntries().first).firstWhere(
          (e) => e.text == 'Avant la migration.',
        );
        expect(old.tags, hasLength(2));
      });

      test('CA9 : une base en version 4 sans ligne de réglages donne, à la '
          'première écriture, une bienvenue à faux', () async {
        writeSchema4(file);
        final raw = sqlite.sqlite3.open(file.path);
        raw.execute("PRAGMA hexkey = '$validKey'");
        raw.execute('DELETE FROM settings');
        raw.close();

        final db = await AppDatabase.openEncrypted(file, validKey);
        addTearDown(db.close);
        await DriftSettingsRepository(db)
            .setLowMoodSensitivity(LowMoodSensitivity.low);

        final row = await db
            .customSelect('SELECT welcome_shown FROM settings WHERE id = 1')
            .getSingle();
        expect(row.read<int>('welcome_shown'), 0);
      });

      test(
        'CA9 : l\'ouverture d\'une base déjà en version 5 ne perd rien',
        () async {
          var db = await AppDatabase.openEncrypted(file, validKey);
          final repo = DriftEntryRepository(db);
          final saved = await repo.addEntry(
            mood: 4,
            text: 'Je reste.',
            topics: [Topic.family],
          );
          await db.close();

          db = await AppDatabase.openEncrypted(file, validKey);
          addTearDown(db.close);

          expect(db.schemaVersion, 5);
          expect((await single(DriftEntryRepository(db), saved.id)).topics, [
            Topic.family,
          ]);
        },
      );
    });

    test('CA10 : sur la base chiffrée, supprimer une entrée efface ses '
        'sujets', () async {
      final db = await AppDatabase.openEncrypted(file, validKey);
      addTearDown(db.close);
      final repo = DriftEntryRepository(db);
      final saved = await repo.addEntry(
        mood: 4,
        topics: [Topic.work, Topic.nature],
      );
      expect(await count(db, 'entry_topics', entryId: saved.id), 2);

      await repo.deleteEntry(saved.id);

      expect(await count(db, 'entry_topics'), 0);
    });
  });

  group('suppression totale (CA10)', () {
    test('CA10 : après la suppression totale, la base neuve n\'a ni entrée ni '
        'sujet', () async {
      final env = WipeEnv();
      addTearDown(env.dispose);
      env.folder.createSync(recursive: true);
      final file = File('${env.folder.path}/journal.db');
      final db = await AppDatabase.openEncrypted(file, validKey);
      final repo = DriftEntryRepository(db);
      await repo.addEntry(mood: 4, text: 'Secret.', topics: Topic.values);
      await repo.addEntry(mood: 2, topics: [Topic.family]);
      expect(await count(db, 'entry_topics'), 7);
      env.keyStore.stored = validKey;
      final wiper = JournalWiper(
        folder: env.folder,
        cacheFolder: env.cache,
        keyStore: env.keyStore,
        closeJournal: db.close,
      );

      await wiper.wipe();

      expect(file.existsSync(), isFalse);
      final fresh = await AppDatabase.openEncrypted(file, otherKey);
      addTearDown(fresh.close);
      expect(await fresh.countEntries(), 0);
      expect(await count(fresh, 'entry_topics'), 0);
    });
  });
}
