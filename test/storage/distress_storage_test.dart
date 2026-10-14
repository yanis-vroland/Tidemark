// Stockage de la spec 002 : nouvelles opérations du dépôt des entrées et réglages sur
// la base (AppDatabase.memory() ou fichier chiffré).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:tidemark/distress/distress_detector.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/storage/app_database.dart';

const validKey =
    '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

void main() {
  group('dépôt des entrées sur base en mémoire', () {
    late AppDatabase db;
    late DateTime now;
    late DriftEntryRepository repo;

    setUp(() {
      db = AppDatabase.memory();
      now = DateTime(2026, 10, 14, 21, 40);
      repo = DriftEntryRepository(db, clock: () => now);
    });

    tearDown(() async => await db.close());

    Future<Entry> addAt(
      DateTime at,
      int mood, {
      String? text,
      AnalysisStatus status = AnalysisStatus.pending,
    }) {
      now = at;
      return repo.addEntry(mood: mood, text: text, status: status);
    }

    group('addEntry(status:)', () {
      test('CA1 : le statut « non analysée » décidé par l\'appelant est '
          'enregistré, texte compris', () async {
        final saved = await repo.addEntry(
          mood: 3,
          text: 'envie de mourir',
          status: AnalysisStatus.skipped,
        );

        expect(saved.analysisStatus, AnalysisStatus.skipped);
        expect(saved.text, 'envie de mourir');
        final listed = (await repo.watchEntries().first).single;
        expect(listed.analysisStatus, AnalysisStatus.skipped);
        expect(listed.text, 'envie de mourir');
      });

      test(
        'le statut « en attente » est celui par défaut d\'un texte',
        () async {
          final saved = await repo.addEntry(mood: 3, text: 'Journée calme.');

          expect(saved.analysisStatus, AnalysisStatus.pending);
          expect(
            (await repo.watchEntries().first).single.analysisStatus,
            AnalysisStatus.pending,
          );
        },
      );

      test('RM24 : une entrée sans texte reste « non analysée », même si '
          'l\'appelant demande « en attente »', () async {
        final saved = await repo.addEntry(
          mood: 3,
          status: AnalysisStatus.pending,
        );

        expect(saved.analysisStatus, AnalysisStatus.skipped);
        expect(
          (await repo.watchEntries().first).single.analysisStatus,
          AnalysisStatus.skipped,
        );
      });
    });

    group('latestEntries', () {
      test('rend les entrées les plus récentes, de la plus récente à la plus '
          'ancienne', () async {
        final a = await addAt(DateTime(2026, 10, 12, 19), 5);
        final c = await addAt(DateTime(2026, 10, 14, 21), 4);
        final b = await addAt(DateTime(2026, 10, 13, 8), 3);

        final latest = await repo.latestEntries(2);

        expect(latest.map((e) => e.id), [c.id, b.id]);
        expect(latest.map((e) => e.id), isNot(contains(a.id)));
      });

      test('rend toutes les entrées s\'il y en a moins que demandé', () async {
        await addAt(DateTime(2026, 10, 13, 8), 3);
        await addAt(DateTime(2026, 10, 14, 8), 2);

        expect(await repo.latestEntries(5), hasLength(2));
      });

      test('rend une liste vide sur un journal vide', () async {
        expect(await repo.latestEntries(3), isEmpty);
      });

      test('suit le même ordre que la liste, comme watchEntries', () async {
        await addAt(DateTime(2026, 10, 14, 8, 15), 3);
        await addAt(DateTime(2026, 10, 12, 19, 30), 5);
        await addAt(DateTime(2026, 10, 14, 21, 40), 4);

        final all = await repo.watchEntries().first;

        expect(
          (await repo.latestEntries(3)).map((e) => e.id),
          all.map((e) => e.id),
        );
      });

      test(
        'Cas limite : deux entrées de la même seconde, l\'ordre suit '
        'l\'identifiant, la plus récente (id le plus grand) en tête',
        () async {
          final first = await addAt(DateTime(2026, 10, 14, 21, 40, 5), 1);
          final second = await addAt(DateTime(2026, 10, 14, 21, 40, 5), 1);
          final third = await addAt(DateTime(2026, 10, 14, 21, 40, 5), 1);

          final latest = await repo.latestEntries(2);

          expect(latest.map((e) => e.id), [third.id, second.id]);
          expect(latest.map((e) => e.id), isNot(contains(first.id)));
        },
      );

      test('CA28 : une entrée supprimée n\'en fait pas partie', () async {
        await addAt(DateTime(2026, 10, 12, 8), 1);
        final removed = await addAt(DateTime(2026, 10, 13, 8), 1);
        await addAt(DateTime(2026, 10, 14, 8), 1);
        await repo.deleteEntry(removed.id);

        final latest = await repo.latestEntries(3);

        expect(latest, hasLength(2));
        expect(latest.map((e) => e.id), isNot(contains(removed.id)));
      });

      test(
        'rend les entrées avec leur humeur, leur texte et leur statut',
        () async {
          await addAt(
            DateTime(2026, 10, 14, 8),
            2,
            text: 'Un texte.',
            status: AnalysisStatus.skipped,
          );

          final entry = (await repo.latestEntries(1)).single;

          expect(entry.mood, 2);
          expect(entry.text, 'Un texte.');
          expect(entry.analysisStatus, AnalysisStatus.skipped);
          expect(entry.createdAt.isUtc, isTrue);
        },
      );
    });

    group('pendingEntriesWithText', () {
      test('CA15 : ne rend que les entrées « en attente » qui ont un '
          'texte', () async {
        final pendingA = await addAt(DateTime(2026, 10, 10, 8), 3, text: 'A.');
        await addAt(DateTime(2026, 10, 11, 8), 3);
        await addAt(
          DateTime(2026, 10, 12, 8),
          3,
          text: 'B.',
          status: AnalysisStatus.skipped,
        );
        final pendingB = await addAt(DateTime(2026, 10, 13, 8), 4, text: 'C.');

        final pending = await repo.pendingEntriesWithText();

        expect(
          pending.map((e) => e.id),
          unorderedEquals([pendingA.id, pendingB.id]),
        );
        expect(pending.every((e) => e.text != null), isTrue);
        expect(
          pending.every((e) => e.analysisStatus == AnalysisStatus.pending),
          isTrue,
        );
      });

      test('rend une liste vide sur un journal vide', () async {
        expect(await repo.pendingEntriesWithText(), isEmpty);
      });
    });

    group('markSkipped', () {
      test(
        'CA15 : passe les entrées désignées à « non analysée », sans toucher '
        'aux autres ni à leur contenu',
        () async {
          final a = await addAt(DateTime(2026, 10, 12, 8), 2, text: 'Texte A.');
          final b = await addAt(DateTime(2026, 10, 13, 8), 3, text: 'Texte B.');
          final c = await addAt(DateTime(2026, 10, 14, 8), 4, text: 'Texte C.');

          await repo.markSkipped([a.id, c.id]);

          final byId = {
            for (final e in await repo.watchEntries().first) e.id: e,
          };
          expect(byId[a.id]!.analysisStatus, AnalysisStatus.skipped);
          expect(byId[b.id]!.analysisStatus, AnalysisStatus.pending);
          expect(byId[c.id]!.analysisStatus, AnalysisStatus.skipped);
          expect(byId[a.id]!.text, 'Texte A.');
          expect(byId[a.id]!.mood, 2);
          expect(byId[a.id]!.createdAt, a.createdAt);
          expect(byId[c.id]!.text, 'Texte C.');
        },
      );

      test('les entrées passées en « non analysée » ne sont plus « en '
          'attente »', () async {
        final a = await addAt(DateTime(2026, 10, 12, 8), 2, text: 'Texte A.');
        await addAt(DateTime(2026, 10, 13, 8), 3, text: 'Texte B.');

        await repo.markSkipped([a.id]);

        final pending = await repo.pendingEntriesWithText();
        expect(pending.map((e) => e.id), isNot(contains(a.id)));
        expect(pending, hasLength(1));
      });

      test('une liste vide ne change rien', () async {
        await addAt(DateTime(2026, 10, 12, 8), 2, text: 'Texte A.');

        await repo.markSkipped(const []);

        expect(
          (await repo.watchEntries().first).single.analysisStatus,
          AnalysisStatus.pending,
        );
      });

      test('watchEntries émet le nouveau statut', () async {
        final a = await addAt(DateTime(2026, 10, 12, 8), 2, text: 'Texte A.');
        final statuses = <AnalysisStatus>[];
        final subscription = repo.watchEntries().listen(
          (list) => statuses.add(list.single.analysisStatus),
        );
        addTearDown(subscription.cancel);
        await pumpEventQueue();

        await repo.markSkipped([a.id]);
        await pumpEventQueue();

        expect(statuses, [AnalysisStatus.pending, AnalysisStatus.skipped]);
      });
    });
  });

  group('réglages sur base en mémoire', () {
    late AppDatabase db;
    late DriftSettingsRepository settings;

    setUp(() {
      db = AppDatabase.memory();
      settings = DriftSettingsRepository(db);
    });

    tearDown(() async => await db.close());

    test('le schéma est en version 2', () {
      expect(db.schemaVersion, 2);
    });

    test('CA18 : sans choix, le degré est « Normale », en lecture comme en '
        'observation', () async {
      expect(
        await settings.readLowMoodSensitivity(),
        LowMoodSensitivity.normal,
      );
      expect(
        await settings.watchLowMoodSensitivity().first,
        LowMoodSensitivity.normal,
      );
    });

    for (final sensitivity in LowMoodSensitivity.values) {
      test(
        'CA19 : le degré « ${sensitivity.name} » est enregistré puis relu',
        () async {
          await settings.setLowMoodSensitivity(sensitivity);

          expect(await settings.readLowMoodSensitivity(), sensitivity);
          expect(await settings.watchLowMoodSensitivity().first, sensitivity);
        },
      );
    }

    test(
      'CA19 : le degré change à chaque choix, la dernière valeur l\'emporte',
      () async {
        await settings.setLowMoodSensitivity(LowMoodSensitivity.high);
        await settings.setLowMoodSensitivity(LowMoodSensitivity.low);
        await settings.setLowMoodSensitivity(LowMoodSensitivity.normal);
        await settings.setLowMoodSensitivity(LowMoodSensitivity.high);

        expect(
          await settings.readLowMoodSensitivity(),
          LowMoodSensitivity.high,
        );
      },
    );

    test('CA19 : la table `settings` ne garde qu\'une ligne', () async {
      await settings.setLowMoodSensitivity(LowMoodSensitivity.high);
      await settings.setLowMoodSensitivity(LowMoodSensitivity.low);

      final rows = await db.customSelect('SELECT * FROM settings').get();

      expect(rows, hasLength(1));
    });

    test(
      'CA19 : watch émet la valeur courante puis chaque changement',
      () async {
        final seen = <LowMoodSensitivity>[];
        final subscription = settings.watchLowMoodSensitivity().listen(
          seen.add,
        );
        addTearDown(subscription.cancel);
        await pumpEventQueue();

        await settings.setLowMoodSensitivity(LowMoodSensitivity.high);
        await pumpEventQueue();
        await settings.setLowMoodSensitivity(LowMoodSensitivity.low);
        await pumpEventQueue();

        expect(seen, [
          LowMoodSensitivity.normal,
          LowMoodSensitivity.high,
          LowMoodSensitivity.low,
        ]);
      },
    );

    test('CA19 : le degré est stocké par son nom', () async {
      await settings.setLowMoodSensitivity(LowMoodSensitivity.low);

      final rows = await db.customSelect('SELECT * FROM settings').get();

      expect(rows.single.data.values, contains('low'));
    });

    test('CA21 : une valeur inconnue en base donne « Normale »', () async {
      await settings.setLowMoodSensitivity(LowMoodSensitivity.low);
      final row =
          (await db.customSelect('SELECT * FROM settings').get()).single;
      // La colonne du degré est celle qui porte « low » : le test ne suppose pas
      // son nom.
      final column = row.data.entries.firstWhere((e) => e.value == 'low').key;
      await db.customStatement("UPDATE settings SET $column = 'tres-haute'");

      expect(
        await settings.readLowMoodSensitivity(),
        LowMoodSensitivity.normal,
      );
      expect(
        await settings.watchLowMoodSensitivity().first,
        LowMoodSensitivity.normal,
      );
    });

    test('CA21 : une valeur vide en base donne « Normale »', () async {
      await settings.setLowMoodSensitivity(LowMoodSensitivity.high);
      final row =
          (await db.customSelect('SELECT * FROM settings').get()).single;
      final column = row.data.entries.firstWhere((e) => e.value == 'high').key;
      await db.customStatement("UPDATE settings SET $column = ''");

      expect(
        await settings.readLowMoodSensitivity(),
        LowMoodSensitivity.normal,
      );
    });

    test(
      'CA21 : une valeur inconnue ne désactive jamais le garde-fou : le degré '
      'rendu est un des trois degrés',
      () async {
        await settings.setLowMoodSensitivity(LowMoodSensitivity.high);
        final row =
            (await db.customSelect('SELECT * FROM settings').get()).single;
        final column = row.data.entries
            .firstWhere((e) => e.value == 'high')
            .key;
        await db.customStatement("UPDATE settings SET $column = 'off'");

        expect(
          LowMoodSensitivity.values,
          contains(await settings.readLowMoodSensitivity()),
        );
      },
    );
  });

  group('réglages sur base chiffrée', () {
    late Directory dir;
    late File file;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('tidemark_settings_');
      file = File('${dir.path}/journal.db');
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('CA19 : le degré est conservé après un redémarrage', () async {
      final first = await AppDatabase.openEncrypted(file, validKey);
      await DriftSettingsRepository(first)
          .setLowMoodSensitivity(LowMoodSensitivity.low);
      await first.close();

      final second = await AppDatabase.openEncrypted(file, validKey);
      addTearDown(second.close);

      expect(
        await DriftSettingsRepository(second).readLowMoodSensitivity(),
        LowMoodSensitivity.low,
      );
    });

    test(
      'migration : une base en version 1 est ouverte en version 2, ses entrées '
      'sont intactes et le degré est « Normale »',
      () async {
        // Base du schéma 1 (spec 001), écrite sans passer par le code de l'app.
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
        raw.execute('PRAGMA user_version = 1');
        raw.close();

        final db = await AppDatabase.openEncrypted(file, validKey);
        addTearDown(db.close);

        final entries = await DriftEntryRepository(db).watchEntries().first;
        expect(entries.single.text, 'Avant la migration.');
        expect(entries.single.mood, 2);
        final settings = DriftSettingsRepository(db);
        expect(
          await settings.readLowMoodSensitivity(),
          LowMoodSensitivity.normal,
        );
        await settings.setLowMoodSensitivity(LowMoodSensitivity.high);
        expect(
          await settings.readLowMoodSensitivity(),
          LowMoodSensitivity.high,
        );
      },
    );
  });
}
