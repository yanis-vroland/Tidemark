// CA4 (spec 008) : charte.md décrit la charte v2.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final charter = File('docs/maquettes/000-charte/charte.md')
      .readAsStringSync()
      .toLowerCase();

  for (final (label, needles) in <(String, List<String>)>[
    ('le principe de la marée', ['marée de ton humeur']),
    ('la bulle', ['bulle']),
    ('les autocollants', ['autocollant']),
    ('les animations d\'ambiance', ['ambiance']),
    (
      'sa coupure (AmbientMotion, réduire les animations)',
      ['ambientmotion', 'réduire les animations'],
    ),
    ('la version 2', ['v2']),
  ]) {
    test('CA4 : charte.md décrit $label', () {
      expect(
        needles.every(charter.contains),
        isTrue,
        reason: 'terme attendu : ${needles.join(', ')}',
      );
    });
  }

  test('CA4 : charte.md dit que l\'écran d\'aide fait exception (calme)', () {
    final lines = charter.split('\n');
    final exception = lines.where(
      (l) => l.contains('aide') && l.contains('exception'),
    );
    expect(exception, isNotEmpty);
  });
}
