// Stockage de la spec 004 : table `tags`, `saveAnalysis` transactionnel, ordre des
// étiquettes, cascade, clés étrangères actives sur la base chiffrée, migration du
// schéma 3 vers le 4 (CA8, CA16, CA17, CA18).
import 'dart:io';

import 'package:drift/drift.dart' show QueryRow;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:tidemark/analysis/mood_analyzer.dart';
import 'package:tidemark/distress/distress_detector.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/storage/app_database.dart';

import '../support/analysis_harness.dart';

const validKey =
    '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

Future<int> countTags(AppDatabase db, {int? entryId}) async {
  final row = await db
      .customSelect(
        entryId == null
            ? 'SELECT count(*) AS n FROM tags'
            : 'SELECT count(*) AS n FROM tags WHERE entry_id = $entryId',
      )
      .getSingle();
  return row.read<int>('n');
}

Future<int> foreignKeys(AppDatabase db) async {
  final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
  return row.read<int>('foreign_keys');
}

Future<void> insertRawTag(
  AppDatabase db,
  int entryId,
  String label, {
  int position = 0,
}) => db.customStatement(
  'INSERT INTO tags (entry_id, label, kind, position) VALUES (?, ?, ?, ?)',
  [entryId, label, 'emotion', position],
);

Future<Entry> single(DriftEntryRepository repo, int id) async =>
    (await repo.watchEntries().first).firstWhere((e) => e.id == id);

/// Tables `entries` et `settings` du schéma 3, écrites sans passer par le code de
/// l'app.
void writeSchema3(File file) {
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
    "analysis_status) VALUES (2, 'Avant la migration.', 1791000000, 120, 'pending')",
  );
  raw.execute(
    "INSERT INTO entries (mood, text, created_at, utc_offset_minutes, "
    "analysis_status) VALUES (4, 'Déjà vue.', 1791003600, 120, 'untagged')",
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
  raw.execute('PRAGMA user_version = 3');
  raw.close();
}

void main() {
  group('étiquettes sur base en mémoire', () {
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

    test(
      'le schéma est en version 5 (spec 010, CA9 ; version 4 jusque-là)',
      () {
        expect(db.schemaVersion, 5);
      },
    );

    test('une entrée neuve n\'a aucune étiquette', () async {
      final saved = await repo.addEntry(mood: 3, text: 'Texte.');

      expect(saved.tags, isEmpty);
      expect((await single(repo, saved.id)).tags, isEmpty);
    });

    group('saveAnalysis, résultat Tagged', () {
      test('CA8 : les étiquettes et le statut « étiquetée » sont enregistrés, '
          'avec leur type', () async {
        final saved = await repo.addEntry(mood: 3, text: 'Texte.');

        await repo.saveAnalysis(saved.id, Tagged(fatigueCalmeTravail));

        final entry = await single(repo, saved.id);
        expect(entry.analysisStatus, AnalysisStatus.tagged);
        expect(entry.tags, fatigueCalmeTravail);
        expect(entry.text, 'Texte.');
        expect(entry.mood, 3);
      });

      test('CA18 : l\'ordre enregistré est celui du résultat, pas l\'ordre '
          'alphabétique', () async {
        final saved = await repo.addEntry(mood: 3, text: 'Texte.');
        final tags = [
          emotion('tristesse'),
          emotion('anxiété'),
          emotion('colère'),
          theme('sport'),
          theme('argent'),
        ];

        await repo.saveAnalysis(saved.id, Tagged(tags));

        expect((await single(repo, saved.id)).tags, tags);
      });

      test('les étiquettes d\'une entrée ne touchent pas celles d\'une '
          'autre', () async {
        final a = await repo.addEntry(mood: 3, text: 'A.');
        final b = await repo.addEntry(mood: 3, text: 'B.');

        await repo.saveAnalysis(a.id, Tagged([emotion('joie')]));
        await repo.saveAnalysis(
          b.id,
          Tagged([emotion('joie'), theme('sport')]),
        );

        expect((await single(repo, a.id)).tags, [emotion('joie')]);
        expect((await single(repo, b.id)).tags, [
          emotion('joie'),
          theme('sport'),
        ]);
      });

      test(
        'CA8 : la transaction est tout ou rien : une étiquette refusée en '
        'cours de route ne laisse ni étiquette partielle ni statut changé',
        () async {
          final saved = await repo.addEntry(mood: 3, text: 'Texte.');
          // Deux fois la même étiquette : la seconde viole l'unicité de
          // (entry_id, label), après l'écriture de la première.
          final broken = Tagged([
            emotion('joie'),
            emotion('calme'),
            emotion('joie'),
          ]);

          try {
            await repo.saveAnalysis(saved.id, broken);
          } catch (_) {}

          expect(await countTags(db), 0);
          final entry = await single(repo, saved.id);
          expect(entry.analysisStatus, AnalysisStatus.pending);
          expect(entry.tags, isEmpty);
        },
      );

      test('CA8 : après un échec, une écriture correcte aboutit', () async {
        final saved = await repo.addEntry(mood: 3, text: 'Texte.');
        try {
          await repo.saveAnalysis(
            saved.id,
            Tagged([emotion('joie'), emotion('joie')]),
          );
        } catch (_) {}

        await repo.saveAnalysis(saved.id, Tagged([emotion('joie')]));

        final entry = await single(repo, saved.id);
        expect(entry.analysisStatus, AnalysisStatus.tagged);
        expect(entry.tags, [emotion('joie')]);
      });

      test('CA18 : la liste observée ne montre jamais une entrée « étiquetée » '
          'sans ses étiquettes, et se met à jour toute seule', () async {
        final saved = await repo.addEntry(mood: 3, text: 'Texte.');
        final emissions = <List<Entry>>[];
        final sub = repo.watchEntries().listen(emissions.add);
        addTearDown(sub.cancel);
        await pumpEventQueue();

        await repo.saveAnalysis(saved.id, Tagged(fatigueCalmeTravail));
        await pumpEventQueue();

        expect(emissions.first.single.analysisStatus, AnalysisStatus.pending);
        for (final list in emissions) {
          for (final e in list) {
            if (e.analysisStatus == AnalysisStatus.tagged) {
              expect(e.tags, fatigueCalmeTravail);
            }
          }
        }
        expect(emissions.last.single.analysisStatus, AnalysisStatus.tagged);
        expect(emissions.last.single.tags, fatigueCalmeTravail);
      });
    });

    group('saveAnalysis, résultat Untagged', () {
      test(
        'le statut « sans étiquette » est enregistré, sans étiquette',
        () async {
          final saved = await repo.addEntry(mood: 3, text: 'Texte.');

          await repo.saveAnalysis(saved.id, const Untagged());

          final entry = await single(repo, saved.id);
          expect(entry.analysisStatus, AnalysisStatus.untagged);
          expect(entry.tags, isEmpty);
          expect(await countTags(db), 0);
        },
      );
    });

    group('CA16 : entrée qui n\'existe plus', () {
      test('saveAnalysis Tagged est sans effet et sans erreur, aucune '
          'étiquette ne reste', () async {
        await expectLater(
          repo.saveAnalysis(9999, Tagged(fatigueCalmeTravail)),
          completes,
        );

        expect(await countTags(db), 0);
        expect(await repo.watchEntries().first, isEmpty);
      });

      test('saveAnalysis Untagged est sans effet et sans erreur', () async {
        await expectLater(repo.saveAnalysis(9999, const Untagged()), completes);

        expect(await repo.watchEntries().first, isEmpty);
      });

      test('une entrée supprimée après coup n\'a plus d\'étiquette et ne '
          'revient pas', () async {
        final saved = await repo.addEntry(mood: 3, text: 'Texte.');
        await repo.deleteEntry(saved.id);

        await repo.saveAnalysis(saved.id, Tagged([emotion('joie')]));

        expect(await repo.watchEntries().first, isEmpty);
        expect(await countTags(db), 0);
      });
    });

    group('CA11 : seule une entrée « en attente » reçoit un résultat', () {
      test('une entrée « non analysée » (détresse) reste sans étiquette et '
          'garde son statut', () async {
        final saved = await repo.addEntry(mood: 3, text: 'Texte.');
        await repo.markSkipped([saved.id]);

        await repo.saveAnalysis(saved.id, Tagged(fatigueCalmeTravail));

        final entry = await single(repo, saved.id);
        expect(entry.analysisStatus, AnalysisStatus.skipped);
        expect(entry.tags, isEmpty);
        expect(await countTags(db), 0);
      });

      test('une entrée déjà « étiquetée » garde ses étiquettes', () async {
        final saved = await repo.addEntry(mood: 3, text: 'Texte.');
        await repo.saveAnalysis(saved.id, Tagged([emotion('joie')]));

        await repo.saveAnalysis(saved.id, Tagged(fatigueCalmeTravail));

        final entry = await single(repo, saved.id);
        expect(entry.analysisStatus, AnalysisStatus.tagged);
        expect(entry.tags, [emotion('joie')]);
      });

      test(
        'une entrée « sans étiquette » ne devient pas « étiquetée »',
        () async {
          final saved = await repo.addEntry(mood: 3, text: 'Texte.');
          await repo.saveAnalysis(saved.id, const Untagged());

          await repo.saveAnalysis(saved.id, Tagged(fatigueCalmeTravail));

          final entry = await single(repo, saved.id);
          expect(entry.analysisStatus, AnalysisStatus.untagged);
          expect(entry.tags, isEmpty);
        },
      );
    });

    group('CA17 : cascade et clés étrangères', () {
      test('CA17 : supprimer une entrée supprime ses étiquettes, pas celles '
          'des autres', () async {
        final a = await repo.addEntry(mood: 3, text: 'A.');
        final b = await repo.addEntry(mood: 3, text: 'B.');
        await repo.saveAnalysis(a.id, Tagged(fatigueCalmeTravail));
        await repo.saveAnalysis(b.id, Tagged([emotion('joie')]));

        await repo.deleteEntry(a.id);

        expect(await countTags(db, entryId: a.id), 0);
        expect(await countTags(db), 1);
        expect((await single(repo, b.id)).tags, [emotion('joie')]);
      });

      test(
        'CA17 : les clés étrangères sont actives, y compris en mémoire',
        () async {
          expect(await foreignKeys(db), 1);
        },
      );

      test(
        'CA17 : une étiquette ne peut pas viser une entrée inexistante',
        () async {
          final saved = await repo.addEntry(mood: 3, text: 'Texte.');
          // Garde-fou : visant une entrée qui existe, l'insertion aboutit.
          await expectLater(insertRawTag(db, saved.id, 'joie'), completes);

          await expectLater(insertRawTag(db, 4242, 'joie'), throwsA(anything));
        },
      );

      test('CA17 : la clé étrangère est déclarée ON DELETE CASCADE vers '
          'entries', () async {
        final rows = await db
            .customSelect('PRAGMA foreign_key_list(tags)')
            .get();

        expect(rows, hasLength(1));
        expect(rows.single.read<String>('table'), 'entries');
        expect(rows.single.read<String>('from'), 'entry_id');
        expect(rows.single.read<String>('on_delete'), 'CASCADE');
      });

      test('une même étiquette ne peut pas figurer deux fois pour une entrée, '
          'mais peut figurer pour deux entrées', () async {
        final a = await repo.addEntry(mood: 3, text: 'A.');
        final b = await repo.addEntry(mood: 3, text: 'B.');
        await insertRawTag(db, a.id, 'joie');

        await expectLater(
          insertRawTag(db, a.id, 'joie', position: 1),
          throwsA(anything),
        );
        await expectLater(insertRawTag(db, b.id, 'joie'), completes);
      });

      test('les colonnes de la table sont celles de la spec', () async {
        final rows = await db.customSelect('PRAGMA table_info(tags)').get();
        final names = rows.map((QueryRow r) => r.read<String>('name'));

        expect(
          names,
          containsAll(['id', 'entry_id', 'label', 'kind', 'position']),
        );
      });
    });
  });

  group('sur base chiffrée', () {
    late Directory dir;
    late File file;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('tidemark_tags_');
      file = File('${dir.path}/journal.db');
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('CA17 : PRAGMA foreign_keys vaut 1 sur la base chiffrée, à chaque '
        'ouverture', () async {
      final first = await AppDatabase.openEncrypted(file, validKey);
      expect(await foreignKeys(first), 1);
      await first.close();

      final second = await AppDatabase.openEncrypted(file, validKey);
      addTearDown(second.close);

      expect(await foreignKeys(second), 1);
    });

    test('CA17 : la cascade fonctionne sur la base chiffrée', () async {
      final db = await AppDatabase.openEncrypted(file, validKey);
      addTearDown(db.close);
      final repo = DriftEntryRepository(db);
      final saved = await repo.addEntry(mood: 3, text: 'Texte.');
      await repo.saveAnalysis(saved.id, Tagged(fatigueCalmeTravail));
      expect(await countTags(db), 3);

      await repo.deleteEntry(saved.id);

      expect(await countTags(db), 0);
    });

    test('CA18 : après fermeture et réouverture, chaque entrée a les mêmes '
        'étiquettes, dans le même ordre', () async {
      final first = await AppDatabase.openEncrypted(file, validKey);
      final repo = DriftEntryRepository(first);
      final a = await repo.addEntry(mood: 3, text: 'A.');
      final b = await repo.addEntry(mood: 4, text: 'B.');
      final c = await repo.addEntry(mood: 2, text: 'C.');
      final tagsA = [emotion('tristesse'), emotion('calme'), theme('sport')];
      final tagsB = [theme('maison')];
      await repo.saveAnalysis(a.id, Tagged(tagsA));
      await repo.saveAnalysis(b.id, Tagged(tagsB));
      await repo.saveAnalysis(c.id, const Untagged());
      await first.close();

      final second = await AppDatabase.openEncrypted(file, validKey);
      addTearDown(second.close);
      final reopened = DriftEntryRepository(second);

      expect((await single(reopened, a.id)).tags, tagsA);
      expect((await single(reopened, b.id)).tags, tagsB);
      expect((await single(reopened, c.id)).tags, isEmpty);
      expect(
        (await single(reopened, c.id)).analysisStatus,
        AnalysisStatus.untagged,
      );
    });

    test(
      'les étiquettes ne sont pas lisibles en clair dans le fichier',
      () async {
        final db = await AppDatabase.openEncrypted(file, validKey);
        final repo = DriftEntryRepository(db);
        final saved = await repo.addEntry(mood: 3, text: 'Texte.');
        await repo.saveAnalysis(saved.id, Tagged([emotion('frustration')]));
        await db.close();

        final bytes = file.readAsBytesSync();
        final content = String.fromCharCodes(bytes);

        expect(content.contains('frustration'), isFalse);
      },
    );

    group('migration du schéma 3 vers le 4', () {
      test('une base en version 3 est ouverte en version 4 : entrées et '
          'réglages intacts, sans étiquette', () async {
        writeSchema3(file);

        final db = await AppDatabase.openEncrypted(file, validKey);
        addTearDown(db.close);

        expect(db.schemaVersion, 5);
        final entries = await DriftEntryRepository(db).watchEntries().first;
        expect(
          entries.map((e) => e.text),
          unorderedEquals(['Avant la migration.', 'Déjà vue.']),
        );
        expect(entries.expand((e) => e.tags), isEmpty);
        expect(
          entries
              .firstWhere((e) => e.text == 'Avant la migration.')
              .analysisStatus,
          AnalysisStatus.pending,
        );
        final settings = DriftSettingsRepository(db);
        expect(
          await settings.readLowMoodSensitivity(),
          LowMoodSensitivity.high,
        );
        expect(await settings.readModelOfferShown(), isTrue);
        expect(await countTags(db), 0);
      });

      test('après la migration, une entrée ancienne peut être étiquetée, et '
          'la cascade et les clés étrangères fonctionnent', () async {
        writeSchema3(file);
        final db = await AppDatabase.openEncrypted(file, validKey);
        addTearDown(db.close);
        final repo = DriftEntryRepository(db);
        final old = (await repo.pendingEntriesWithText()).single;

        await repo.saveAnalysis(old.id, Tagged(fatigueCalmeTravail));

        expect(await foreignKeys(db), 1);
        expect((await single(repo, old.id)).tags, fatigueCalmeTravail);
        await repo.deleteEntry(old.id);
        expect(await countTags(db), 0);
      });

      test('une base en version 2 passe aussi en version 4 : réglages et '
          'étiquettes fonctionnent', () async {
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
          "analysis_status) VALUES (2, 'Version 2.', 1791000000, 120, 'pending')",
        );
        raw.execute(
          'CREATE TABLE settings ('
          'id INTEGER NOT NULL CHECK (id = 1), '
          'low_mood_sensitivity TEXT NOT NULL, '
          'PRIMARY KEY (id))',
        );
        raw.execute(
          "INSERT INTO settings (id, low_mood_sensitivity) VALUES (1, 'low')",
        );
        raw.execute('PRAGMA user_version = 2');
        raw.close();

        final db = await AppDatabase.openEncrypted(file, validKey);
        addTearDown(db.close);
        final repo = DriftEntryRepository(db);
        final entry = (await repo.watchEntries().first).single;
        await repo.saveAnalysis(entry.id, Tagged([emotion('joie')]));

        expect(db.schemaVersion, 5);
        expect((await single(repo, entry.id)).tags, [emotion('joie')]);
        final settings = DriftSettingsRepository(db);
        expect(await settings.readLowMoodSensitivity(), LowMoodSensitivity.low);
        expect(await settings.readModelOfferShown(), isFalse);
      });

      test(
        'une base en version 1 passe en version 4 : étiquettes comprises',
        () async {
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
            "analysis_status) VALUES (4, 'Très ancienne.', 1791000000, 60, 'pending')",
          );
          raw.execute('PRAGMA user_version = 1');
          raw.close();

          final db = await AppDatabase.openEncrypted(file, validKey);
          addTearDown(db.close);
          final repo = DriftEntryRepository(db);
          final entry = (await repo.watchEntries().first).single;
          await repo.saveAnalysis(entry.id, Tagged([theme('maison')]));

          expect(db.schemaVersion, 5);
          expect((await single(repo, entry.id)).tags, [theme('maison')]);
        },
      );
    });
  });
}
