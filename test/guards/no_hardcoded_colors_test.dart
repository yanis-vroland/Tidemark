// Garde-fou : aucune couleur écrite en dur hors de lib/ui/theme/. Le reste de l'app
// prend ses couleurs dans le thème (plan, « Exigence de finition »).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Formes d'une couleur littérale en Dart, y compris sur plusieurs lignes
/// (`\s` couvre le retour à la ligne que `dart format` insère).
final hardcodedColor = RegExp(
  r'\bColor\(\s*(0x|\d)|\bColor\.from(ARGB|RGBO)?\s*\(|\bColors\.[a-z]|\bCupertinoColors\.[a-z]',
);

/// Remplace les commentaires par des espaces, en gardant les retours à la ligne pour
/// que les numéros de ligne restent justes.
String withoutComments(String source) => source.replaceAllMapped(
  RegExp(r'/\*[\s\S]*?\*/|//[^\n]*'),
  (m) => m[0]!.replaceAll(RegExp(r'[^\n]'), ' '),
);

/// Lignes de [source] où commence une couleur littérale.
List<int> offendingLines(String source) {
  final code = withoutComments(source);
  return [
    for (final match in hardcodedColor.allMatches(code))
      '\n'.allMatches(code.substring(0, match.start)).length + 1,
  ];
}

void main() {
  group('détection', () {
    test('repère chaque forme de couleur littérale', () {
      expect(offendingLines('final a = Color(0xFF123456);'), [1]);
      expect(offendingLines('final a = Color(4294901760);'), [1]);
      expect(offendingLines('final a = Color.fromARGB(255, 1, 2, 3);'), [1]);
      expect(offendingLines('final a = Color.fromRGBO(1, 2, 3, 1);'), [1]);
      expect(
        offendingLines(
          'final a = Color.from(alpha: 1, red: 1, green: 0, blue: 0);',
        ),
        [1],
      );
      expect(offendingLines('final a = Colors.red;'), [1]);
      expect(offendingLines('final a = CupertinoColors.systemRed;'), [1]);
    });

    test('repère un appel coupé sur deux lignes, à la bonne ligne', () {
      expect(
        offendingLines('final b = 1;\nfinal a = Color(\n  0xFF123456,\n);'),
        [2],
      );
    });

    test('accepte les couleurs du thème et les commentaires', () {
      expect(offendingLines('final a = context.colors.tide;'), isEmpty);
      expect(offendingLines('// Colors.red est interdit ici'), isEmpty);
      expect(offendingLines('/* Color(0xFF000000) */ final a = 1;'), isEmpty);
      expect(
        offendingLines('final a = Theme.of(context).colorScheme.primary;'),
        isEmpty,
      );
    });
  });

  test('aucune couleur en dur dans lib/ hors de lib/ui/theme/', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where(
          (f) => !f.path.replaceAll(r'\', '/').startsWith('lib/ui/theme/'),
        );
    for (final file in files) {
      for (final line in offendingLines(file.readAsStringSync())) {
        offenders.add('${file.path}:$line');
      }
    }
    expect(offenders, isEmpty, reason: 'couleurs à prendre dans le thème');
  });
}
