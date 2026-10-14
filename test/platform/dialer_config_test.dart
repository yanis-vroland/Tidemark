// Configuration native du composeur (spec 002, « Données », point « Appel ») : sans
// elle, un vrai téléphone pourrait afficher à tort « L'appel n'a pas pu être lancé ».
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CA11 : Android déclare l\'intent DIAL sur le schéma tel '
      '(Android 11 et plus)', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final queries = RegExp(r'<queries>([\s\S]*?)</queries>')
        .firstMatch(manifest)
        ?.group(1);

    expect(queries, isNotNull);
    expect(
      RegExp(
        r'<intent>\s*(<!--[\s\S]*?-->\s*)?'
        r'<action android:name="android\.intent\.action\.DIAL"\s*/>\s*'
        r'<data android:scheme="tel"\s*/>\s*</intent>',
      ).hasMatch(queries!),
      isTrue,
    );
  });

  test('CA11 : iOS déclare le schéma tel dans LSApplicationQueriesSchemes', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(
      RegExp(
        r'<key>LSApplicationQueriesSchemes</key>\s*<array>[\s\S]*?'
        r'<string>tel</string>[\s\S]*?</array>',
      ).hasMatch(plist),
      isTrue,
    );
  });
}
