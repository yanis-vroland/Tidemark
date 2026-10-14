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
}
