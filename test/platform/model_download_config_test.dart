// Configuration du téléchargement du modèle (spec 003) : emplacement du dossier
// `models/` et exclusion des sauvegardes (CA26), permission réseau Android,
// aucune exception ATS sur iOS (section « Données »).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/main.dart';
import 'package:tidemark/model/model_downloader.dart';
import 'package:tidemark/storage/app_database.dart';
import 'package:tidemark/storage/database_key.dart';

class _MemoryKeyStore implements KeyStore {
  String? stored;

  @override
  Future<String?> read() async => stored;

  @override
  Future<void> write(String key) async => stored = key;
}

String _withoutXmlComments(String xml) =>
    xml.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

void main() {
  group('dossier du modèle (CA26)', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('tidemark_cfg_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test(
      'CA26 : le dossier du modèle est `models/`, sous le dossier de la base '
      '(Application Support/tidemark)',
      () async {
        final journal = await openJournal(
          folder: dir,
          keyStore: _MemoryKeyStore(),
        );
        addTearDown(() => (journal.entries as DriftEntryRepository).db.close());

        final downloader = journal.downloader;

        expect(downloader, isA<HttpModelDownloader>());
        expect(
          (downloader as HttpModelDownloader).folder.path,
          '${dir.path}/models',
        );
      },
    );

    test(
      'CA26 : iOS exclut des sauvegardes le dossier `tidemark` d\'Application '
      'Support, qui contient `models/`',
      () {
        final delegate = File('ios/Runner/AppDelegate.swift')
            .readAsStringSync();

        expect(delegate, contains('.applicationSupportDirectory'));
        expect(delegate, contains('appendingPathComponent("tidemark"'));
        expect(delegate, contains('isExcludedFromBackup = true'));
      },
    );

    test(
      'CA26 : Android exclut le domaine `file` entier (là où vit Application '
      'Support), de la sauvegarde et du transfert d\'appareil',
      () {
        final rules = _withoutXmlComments(
          File('android/app/src/main/res/xml/data_extraction_rules.xml')
              .readAsStringSync(),
        );

        for (final section in ['cloud-backup', 'device-transfer']) {
          final body = RegExp('<$section>([\\s\\S]*?)</$section>')
              .firstMatch(rules)
              ?.group(1);
          expect(
            body,
            contains('<exclude domain="file" path="." />'),
            reason: section,
          );
        }
      },
    );
  });

  group('permissions', () {
    test('la permission INTERNET est dans le manifeste principal, hors des '
        'commentaires', () {
      final manifest = _withoutXmlComments(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      );

      expect(
        manifest,
        contains(
          RegExp(
            r'<uses-permission\s+android:name="android\.permission\.INTERNET"\s*/>',
          ),
        ),
      );
    });

    test('la permission INTERNET est déclarée au niveau de <manifest>, pas '
        'dans <application>', () {
      final manifest = _withoutXmlComments(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      );
      final application = RegExp(r'<application\b[\s\S]*?</application>')
          .firstMatch(manifest)!
          .group(0)!;

      expect(application, isNot(contains('android.permission.INTERNET')));
      expect(manifest, contains('android.permission.INTERNET'));
    });

    test('INTERNET est la seule permission du manifeste principal', () {
      final manifest = _withoutXmlComments(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      );
      final permissions = RegExp(r'<uses-permission[^>]*android:name="([^"]+)"')
          .allMatches(manifest)
          .map((m) => m.group(1))
          .toList();

      expect(permissions, ['android.permission.INTERNET']);
    });

    test('iOS : aucune exception ATS, tout est en HTTPS', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();

      expect(plist, isNot(contains('NSAppTransportSecurity')));
      expect(plist, isNot(contains('NSAllowsArbitraryLoads')));
      expect(plist, isNot(contains('NSExceptionDomains')));
    });
  });
}
