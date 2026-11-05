// Stockage de la spec 003 : « proposition du modèle déjà affichée » dans les réglages
// (RM31), colonne ajoutée par la migration du schéma 2 vers le 3.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:tidemark/distress/distress_detector.dart';
import 'package:tidemark/storage/app_database.dart';

import '../support/schema_v5_checks.dart';

const validKey =
    '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

void main() {
  group('proposition déjà affichée, sur base en mémoire', () {
    late AppDatabase db;
    late DriftSettingsRepository settings;

    setUp(() {
      db = AppDatabase.memory();
      settings = DriftSettingsRepository(db);
    });

    tearDown(() async => await db.close());

    // Version 3 introduite par la spec 003 ; la spec 004 passe à la version 4.
    test('le schéma est au moins en version 3', () {
      expect(db.schemaVersion, greaterThanOrEqualTo(3));
    });

    test('la proposition n\'est pas affichée par défaut, en lecture comme en '
        'observation', () async {
      expect(await settings.readModelOfferShown(), isFalse);
      expect(await settings.watchModelOfferShown().first, isFalse);
    });

    test('setModelOfferShown la marque comme affichée', () async {
      await settings.setModelOfferShown();

      expect(await settings.readModelOfferShown(), isTrue);
      expect(await settings.watchModelOfferShown().first, isTrue);
    });

    test('l\'observation émet la nouvelle valeur sans être relancée', () async {
      final values = <bool>[];
      final subscription = settings.watchModelOfferShown().listen(values.add);
      addTearDown(subscription.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await settings.setModelOfferShown();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(values.first, isFalse);
      expect(values.last, isTrue);
    });

    test('la marquer deux fois est sans effet de plus', () async {
      await settings.setModelOfferShown();
      await settings.setModelOfferShown();

      expect(await settings.readModelOfferShown(), isTrue);
    });

    test(
      'marquer la proposition ne change pas le degré de sensibilité',
      () async {
        await settings.setLowMoodSensitivity(LowMoodSensitivity.low);

        await settings.setModelOfferShown();

        expect(await settings.readLowMoodSensitivity(), LowMoodSensitivity.low);
      },
    );

    test(
      'marquer la proposition sur une base sans degré choisi laisse le degré '
      'à « Normale »',
      () async {
        await settings.setModelOfferShown();

        expect(
          await settings.readLowMoodSensitivity(),
          LowMoodSensitivity.normal,
        );
      },
    );

    test('choisir un degré après coup ne remet pas la proposition à « jamais '
        'affichée »', () async {
      await settings.setModelOfferShown();

      await settings.setLowMoodSensitivity(LowMoodSensitivity.high);

      expect(await settings.readModelOfferShown(), isTrue);
      expect(await settings.readLowMoodSensitivity(), LowMoodSensitivity.high);
    });

    test('choisir un degré seul ne marque pas la proposition', () async {
      await settings.setLowMoodSensitivity(LowMoodSensitivity.high);

      expect(await settings.readModelOfferShown(), isFalse);
    });
  });

  group('sur base chiffrée', () {
    late Directory dir;
    late File file;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('tidemark_offer_');
      file = File('${dir.path}/journal.db');
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test(
      'la proposition affichée est conservée après un redémarrage',
      () async {
        final first = await AppDatabase.openEncrypted(file, validKey);
        await DriftSettingsRepository(first).setModelOfferShown();
        await first.close();

        final second = await AppDatabase.openEncrypted(file, validKey);
        addTearDown(second.close);

        expect(
          await DriftSettingsRepository(second).readModelOfferShown(),
          isTrue,
        );
      },
    );

    /// Base du schéma 2 (specs 001 et 002), écrite sans passer par le code de l'app.
    void writeSchema2({String sensitivity = 'high'}) {
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
        'CREATE TABLE settings ('
        'id INTEGER NOT NULL CHECK (id = 1), '
        'low_mood_sensitivity TEXT NOT NULL, '
        'PRIMARY KEY (id))',
      );
      raw.execute(
        "INSERT INTO settings (id, low_mood_sensitivity) VALUES (1, '$sensitivity')",
      );
      raw.execute('PRAGMA user_version = 2');
      raw.close();
    }

    test('migration : une base en version 2 est ouverte en version 3, ses '
        'entrées et son degré sont intacts, la proposition est « jamais '
        'affichée »', () async {
      writeSchema2();

      final db = await AppDatabase.openEncrypted(file, validKey);
      addTearDown(db.close);

      final entries = await DriftEntryRepository(db).watchEntries().first;
      expect(entries.single.text, 'Avant la migration.');
      expect(entries.single.mood, 2);
      final settings = DriftSettingsRepository(db);
      expect(await settings.readLowMoodSensitivity(), LowMoodSensitivity.high);
      expect(await settings.readModelOfferShown(), isFalse);
      expect(db.schemaVersion, greaterThanOrEqualTo(3));
      await expectSchema5Additions(db);
    });

    test('migration : après le passage en version 3, la proposition se marque '
        'sans toucher au degré', () async {
      writeSchema2(sensitivity: 'low');
      final db = await AppDatabase.openEncrypted(file, validKey);
      addTearDown(db.close);
      final settings = DriftSettingsRepository(db);

      await settings.setModelOfferShown();

      expect(await settings.readModelOfferShown(), isTrue);
      expect(await settings.readLowMoodSensitivity(), LowMoodSensitivity.low);
    });

    test('migration : une base en version 2 sans ligne de réglages donne '
        '« jamais affichée » et « Normale »', () async {
      writeSchema2();
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute("PRAGMA hexkey = '$validKey'");
      raw.execute('DELETE FROM settings');
      raw.close();

      final db = await AppDatabase.openEncrypted(file, validKey);
      addTearDown(db.close);
      final settings = DriftSettingsRepository(db);

      expect(await settings.readModelOfferShown(), isFalse);
      expect(
        await settings.readLowMoodSensitivity(),
        LowMoodSensitivity.normal,
      );
      await expectSchema5Additions(db);
      await settings.setModelOfferShown();
      expect(await settings.readModelOfferShown(), isTrue);
    });

    test('migration : une base en version 1 est ouverte en version 3 : les '
        'réglages, proposition comprise, fonctionnent', () async {
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
      final settings = DriftSettingsRepository(db);

      expect(
        (await DriftEntryRepository(db).watchEntries().first).single.text,
        'Très ancienne.',
      );
      expect(await settings.readModelOfferShown(), isFalse);
      await expectSchema5Additions(db);
      await settings.setModelOfferShown();
      await settings.setLowMoodSensitivity(LowMoodSensitivity.low);
      expect(await settings.readModelOfferShown(), isTrue);
      expect(await settings.readLowMoodSensitivity(), LowMoodSensitivity.low);
    });
  });
}
