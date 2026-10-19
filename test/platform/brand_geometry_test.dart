// Spec 007, « Le logo » : une seule géométrie. Les constantes de tool/generate_brand.py
// (SVG, icônes, écran de lancement) doivent valoir celles de TidemarkLogo (widget).
import 'dart:io';
import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/ui/widgets/tidemark_logo.dart';

/// Nombres affectés à la constante Python [name] : « MARK_WAVE = (10, 16, 7, 3.2, 4) ».
List<double> pythonConstant(String name) {
  final file = File('tool/generate_brand.py');
  expect(
    file.existsSync(),
    isTrue,
    reason: 'tool/generate_brand.py est absent',
  );
  final match = RegExp(
    '^$name\\s*=\\s*([^\\n#]+)',
    multiLine: true,
  ).firstMatch(file.readAsStringSync());
  expect(match, isNotNull, reason: '$name n\'est pas défini dans le script');
  return RegExp(r'-?\d+(?:\.\d+)?')
      .allMatches(match!.group(1)!)
      .map((m) => double.parse(m.group(0)!))
      .toList();
}

List<double> xy(Offset o) => [o.dx, o.dy];

void main() {
  test('CA2 : MARK_TILE_RADIUS = TidemarkLogo.tileRadius', () {
    expect(pythonConstant('MARK_TILE_RADIUS'), [TidemarkLogo.tileRadius]);
  });

  test('CA2 : MARK_STROKE = TidemarkLogo.stroke', () {
    expect(pythonConstant('MARK_STROKE'), [TidemarkLogo.stroke]);
  });

  test(
    'CA2 : MARK_WAVE = départ, demi-largeur, creux, nombre de demi-ondes',
    () {
      expect(pythonConstant('MARK_WAVE'), [
        ...xy(TidemarkLogo.waveStart),
        TidemarkLogo.waveHalfWidth,
        TidemarkLogo.waveDepth,
        TidemarkLogo.waveHalves.toDouble(),
      ]);
    },
  );

  test('CA2 : MARK_STEM = jambage de stemTop à stemBottom', () {
    expect(pythonConstant('MARK_STEM'), [
      ...xy(TidemarkLogo.stemTop),
      ...xy(TidemarkLogo.stemBottom),
    ]);
  });

  test('CA2 : MARK_DOT = centre et rayon du point', () {
    expect(pythonConstant('MARK_DOT'), [
      ...xy(TidemarkLogo.dotCenter),
      TidemarkLogo.dotRadius,
    ]);
  });
}
