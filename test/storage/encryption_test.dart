import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/storage/app_database.dart';

const keyA = 'a0a1a2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3b4b5b6b7b8b9babbbcbdbebf';
const keyB = 'f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff0f1f2f3f4f5f6f7f8f9fafbfcfdfeff0';

/// Mot distinctif, en ASCII pour le chercher tel quel dans les octets du fichier.
const secretText = 'Rendez-vous Zanzibar-ordonnance chez le docteur Martin';

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('tidemark_encryption_');
    file = File('${dir.path}/tidemark.db');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> createWithKeyA() async {
    final db = await AppDatabase.openEncrypted(file, keyA);
    await DriftEntryRepository(db).addEntry(mood: 2, text: secretText);
    await db.close();
  }

  test('CA22 : la bonne clé rouvre la base, une autre clé échoue', () async {
    await createWithKeyA();

    // Garde-fou du test : sans cette réouverture, « échoue avec une autre clé »
    // pourrait venir de n'importe quelle autre erreur.
    final good = await AppDatabase.openEncrypted(file, keyA);
    expect(await good.countEntries(), 1);
    await good.close();

    Future<void> openWithKeyB() async {
      final db = await AppDatabase.openEncrypted(file, keyB);
      try {
        await db.countEntries();
      } finally {
        try {
          await db.close();
        } catch (_) {}
      }
    }

    await expectLater(openWithKeyB(), throwsA(anything));
  });

  test(
    'CA22 : le texte saisi n\'apparaît pas en clair dans le fichier',
    () async {
      await createWithKeyA();

      final files = [
        file,
        File('${file.path}-wal'),
        File('${file.path}-journal'),
      ].where((f) => f.existsSync());
      expect(files, isNotEmpty);
      for (final f in files) {
        final content = latin1.decode(f.readAsBytesSync());
        expect(content.contains('Zanzibar'), isFalse, reason: f.path);
        expect(content.contains('docteur'), isFalse, reason: f.path);
      }
    },
  );

  test(
    'CA22 : le fichier n\'a pas l\'en-tête d\'une base SQLite en clair',
    () async {
      await createWithKeyA();

      final header = latin1.decode(file.readAsBytesSync().take(16).toList());

      expect(header.startsWith('SQLite format 3'), isFalse);
    },
  );
}
