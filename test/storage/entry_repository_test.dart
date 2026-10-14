import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/storage/app_database.dart';

const validKey =
    '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

void main() {
  group('dépôt sur base en mémoire', () {
    AppDatabase? opened;
    late AppDatabase db;
    late DateTime now;
    late DriftEntryRepository repo;

    setUp(() {
      db = AppDatabase.memory();
      opened = db;
      now = DateTime(2026, 10, 14, 21, 40);
      repo = DriftEntryRepository(db, clock: () => now);
    });

    tearDown(() async => await opened?.close());

    test('CA1 : sans entrée, la liste observée est vide', () async {
      expect(await repo.watchEntries().first, isEmpty);
    });

    test('CA9 : une humeur sans texte est enregistrée sans texte, avec la date '
        'et l\'heure de la saisie', () async {
      final saved = await repo.addEntry(mood: 4);

      expect(saved.mood, 4);
      expect(saved.text, isNull);
      expect(saved.createdAt.isUtc, isTrue);
      expect(saved.createdAt, now.toUtc());
      expect(saved.localCreatedAt.year, 2026);
      expect(saved.localCreatedAt.month, 10);
      expect(saved.localCreatedAt.day, 14);
      expect(saved.localCreatedAt.hour, 21);
      expect(saved.localCreatedAt.minute, 40);

      final listed = await repo.watchEntries().first;
      expect(listed, hasLength(1));
      expect(listed.single.id, saved.id);
      expect(listed.single.text, isNull);
    });

    test('CA10 : un texte est enregistré tel quel, accents et émoji '
        'compris', () async {
      const text = 'Balade au bord de l\'eau, le ciel était dégagé 🌊';

      final saved = await repo.addEntry(mood: 5, text: text);

      expect(saved.text, text);
      expect((await repo.watchEntries().first).single.text, text);
    });

    for (final blank in ['   ', '\n\n', ' \n \t ', '']) {
      test('CA11 : le texte ${blank.codeUnits} fait d\'espaces ou vide est '
          'enregistré sans texte', () async {
        final saved = await repo.addEntry(mood: 3, text: blank);

        expect(saved.text, isNull);
        expect((await repo.watchEntries().first).single.text, isNull);
      });
    }

    test('CA24 : une entrée avec texte a le statut « en attente »', () async {
      final saved = await repo.addEntry(mood: 3, text: 'Journée calme.');

      expect(saved.analysisStatus, AnalysisStatus.pending);
      expect(
        (await repo.watchEntries().first).single.analysisStatus,
        AnalysisStatus.pending,
      );
    });

    test('CA24 : une entrée sans texte a le statut « non analysée »', () async {
      final saved = await repo.addEntry(mood: 3);

      expect(saved.analysisStatus, AnalysisStatus.skipped);
      expect(
        (await repo.watchEntries().first).single.analysisStatus,
        AnalysisStatus.skipped,
      );
    });

    test(
      'CA24 : un texte fait d\'espaces donne aussi « non analysée »',
      () async {
        final saved = await repo.addEntry(mood: 3, text: '  \n ');

        expect(saved.analysisStatus, AnalysisStatus.skipped);
      },
    );

    test('RM27 : un texte de 2 000 caractères est accepté', () async {
      final text = 'é' * maxTextLength;

      final saved = await repo.addEntry(mood: 3, text: text);

      expect(saved.text, text);
    });

    test('RM27 : un texte de 2 001 caractères est refusé par une '
        'ArgumentError, et rien n\'est enregistré', () async {
      final text = 'é' * (maxTextLength + 1);

      await expectLater(
        repo.addEntry(mood: 3, text: text),
        throwsA(isA<ArgumentError>()),
      );
      expect(await db.countEntries(), 0);
    });

    test('RM27 : 2 000 émoji comptent 2 000 caractères visibles, donc '
        'acceptés', () async {
      final text = '😀' * maxTextLength;

      final saved = await repo.addEntry(mood: 5, text: text);

      expect(saved.text!.runes.length, maxTextLength);
    });

    test('RM27 : 2 001 émoji sont refusés', () async {
      final text = '😀' * (maxTextLength + 1);

      await expectLater(
        repo.addEntry(mood: 5, text: text),
        throwsA(isA<ArgumentError>()),
      );
      expect(await db.countEntries(), 0);
    });

    test('CA2 : la plus récente est en tête, quel que soit l\'ordre '
        'd\'enregistrement', () async {
      now = DateTime(2026, 10, 14, 8, 15);
      final morning = await repo.addEntry(mood: 3);
      now = DateTime(2026, 10, 12, 19, 30);
      final monday = await repo.addEntry(mood: 5);
      now = DateTime(2026, 10, 14, 21, 40);
      final evening = await repo.addEntry(mood: 4);

      final listed = await repo.watchEntries().first;

      expect(listed.map((e) => e.id), [evening.id, morning.id, monday.id]);
    });

    test('CA9 : watchEntries émet à chaque ajout et à chaque '
        'suppression', () async {
      final emissions = <int>[];
      final subscription = repo.watchEntries().listen(
        (list) => emissions.add(list.length),
      );
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      final saved = await repo.addEntry(mood: 4);
      await pumpEventQueue();
      await repo.deleteEntry(saved.id);
      await pumpEventQueue();

      expect(emissions, [0, 1, 0]);
    });

    test('CA19 : supprimer une entrée l\'efface de la base et de la '
        'liste, sans toucher aux autres', () async {
      final kept = await repo.addEntry(mood: 2, text: 'À garder.');
      final removed = await repo.addEntry(mood: 4, text: 'À supprimer.');
      expect(await db.countEntries(), 2);

      await repo.deleteEntry(removed.id);

      expect(await db.countEntries(), 1);
      final listed = await repo.watchEntries().first;
      expect(listed.map((e) => e.id), [kept.id]);
    });
  });

  group('persistance sur une base fichier', () {
    late Directory dir;
    late File file;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('tidemark_persistence_');
      file = File('${dir.path}/tidemark.db');
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('CA21 : après fermeture puis réouverture, la liste montre les mêmes '
        'entrées', () async {
      var db = await AppDatabase.openEncrypted(file, validKey);
      var repo = DriftEntryRepository(
        db,
        clock: () => DateTime(2026, 10, 14, 21, 40),
      );
      await repo.addEntry(mood: 4, text: 'Longue journée, belle soirée.');
      await repo.addEntry(mood: 3);
      final before = await repo.watchEntries().first;
      await db.close();

      db = await AppDatabase.openEncrypted(file, validKey);
      repo = DriftEntryRepository(db);
      final after = await repo.watchEntries().first;
      await db.close();

      expect(after, hasLength(2));
      for (var i = 0; i < before.length; i++) {
        expect(after[i].id, before[i].id);
        expect(after[i].mood, before[i].mood);
        expect(after[i].text, before[i].text);
        expect(after[i].createdAt, before[i].createdAt);
        expect(after[i].utcOffset, before[i].utcOffset);
        expect(after[i].analysisStatus, before[i].analysisStatus);
      }
    });

    test('CA21 : une suppression est elle aussi conservée à la '
        'réouverture', () async {
      var db = await AppDatabase.openEncrypted(file, validKey);
      final repo = DriftEntryRepository(db);
      final saved = await repo.addEntry(mood: 1, text: 'À effacer.');
      await repo.deleteEntry(saved.id);
      await db.close();

      db = await AppDatabase.openEncrypted(file, validKey);
      final count = await db.countEntries();
      await db.close();

      expect(count, 0);
    });
  });
}
