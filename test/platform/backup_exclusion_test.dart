import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CA25 : Android désactive la sauvegarde automatique '
      '(android:allowBackup="false")', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();

    final application = RegExp(r'<application\b[^>]*>').firstMatch(manifest);

    expect(application, isNotNull);
    expect(
      application!.group(0),
      contains('android:allowBackup="false"'),
      reason: 'la base ne doit pas partir dans la sauvegarde du téléphone',
    );
  });

  test('CA25 : Android coupe aussi la sauvegarde complète et renvoie vers les '
      'règles d\'extraction (Android 12 et plus)', () {
    final application = RegExp(r'<application\b[^>]*>')
        .firstMatch(
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
        )!
        .group(0)!;

    expect(application, contains('android:fullBackupContent="false"'));
    expect(
      application,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
  });

  test('CA25 : les règles d\'extraction excluent tout, sauvegarde et transfert '
      'd\'appareil, stockage chiffré par l\'appareil compris', () {
    final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml')
        .readAsStringSync()
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

    for (final section in ['cloud-backup', 'device-transfer']) {
      final body = RegExp('<$section>([\\s\\S]*?)</$section>')
          .firstMatch(rules)
          ?.group(1);
      expect(body, isNotNull, reason: section);
      for (final domain in [
        'root',
        'file',
        'database',
        'sharedpref',
        'external',
        'device_root',
        'device_file',
        'device_database',
        'device_sharedpref',
      ]) {
        expect(
          body,
          contains('<exclude domain="$domain" path="." />'),
          reason: '$section : $domain',
        );
      }
    }
  });
}
