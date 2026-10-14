// Garde-fou : aucune couleur écrite en dur hors de lib/ui/theme/. Le reste de l'app
// prend ses couleurs dans le thème (plan, « Exigence de finition »).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Formes d'une couleur littérale en Dart.
final hardcodedColor = RegExp(
  r'\bColor\(\s*0x|\bColor\.from(ARGB|RGBO)\(|\bColors\.[a-z]|\bCupertinoColors\.[a-z]',
);

/// Lignes de [source] qui contiennent une couleur littérale (commentaires ignorés).
List<int> offendingLines(String source) => [
  for (final (index, line) in source.split('\n').indexed)
    if (!line.trimLeft().startsWith('//') && hardcodedColor.hasMatch(line))
      index + 1,
];

void main() {
  group('détection', () {
    test('repère chaque forme de couleur littérale', () {
      expect(offendingLines('final a = Color(0xFF123456);'), [1]);
      expect(offendingLines('final a = Color.fromARGB(255, 1, 2, 3);'), [1]);
      expect(offendingLines('final a = Color.fromRGBO(1, 2, 3, 1);'), [1]);
      expect(offendingLines('final a = Colors.red;'), [1]);
      expect(offendingLines('final a = CupertinoColors.systemRed;'), [1]);
    });

    test('accepte les couleurs du thème et les commentaires', () {
      expect(offendingLines('final a = context.colors.tide;'), isEmpty);
      expect(offendingLines('// Colors.red est interdit ici'), isEmpty);
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
