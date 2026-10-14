// Composeur (spec 002, « Données », point « Appel ») : `launchUrl` ouvre `tel:` sans
// déclaration native. `canLaunchUrl` en exigerait une (`<queries>` sur Android,
// `LSApplicationQueriesSchemes` sur iOS) et rendrait d'autres apps visibles à
// Tidemark sans besoin : il n'est pas utilisé.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CA11 : le code n\'appelle pas canLaunchUrl', () {
    final uses = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('canLaunch'))
        .map((f) => f.path);

    expect(uses, isEmpty);
  });

  test(
    'CA11 : aucune déclaration du schéma tel, ni sur Android ni sur iOS',
    () {
      expect(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
        isNot(contains('android:scheme="tel"')),
      );
      expect(
        File('ios/Runner/Info.plist').readAsStringSync(),
        isNot(contains('LSApplicationQueriesSchemes')),
      );
    },
  );
}
