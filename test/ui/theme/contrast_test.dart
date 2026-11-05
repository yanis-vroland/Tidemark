// Contrastes de la charte v2 (spec 008, CA3) : chaque paire de la section
// « Contrastes », calculée depuis tokens.json avec la formule WCAG 2.x, dans les
// deux thèmes.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

final _tokens = jsonDecode(
  File('docs/maquettes/000-charte/tokens.json').readAsStringSync(),
) as Map<String, dynamic>;

/// Valeur hexadécimale du jeton [name] dans le thème [theme] (`light` ou `dark`).
String _hex(String name, String theme) {
  for (final token in (_tokens['color'] as Map)['tokens'] as List) {
    if (token['name'] == name) return (token['value'] as Map)[theme] as String;
  }
  throw TestFailure(
    'jeton « $name » absent de tokens.json (version ${_tokens['version']})',
  );
}

double _luminance(String hex) {
  double channel(int offset) {
    final v = int.parse(hex.substring(offset, offset + 2), radix: 16) / 255;
    return v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(1) + 0.7152 * channel(3) + 0.0722 * channel(5);
}

double contrast(String a, String b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

List<String> _range(String prefix, String suffix) => [
  for (var n = 1; n <= 5; n++) '$prefix$n$suffix',
];

/// (premiers plans, fonds, seuil) : tableau « Contrastes » de la spec.
final pairs = <(List<String>, List<String>, double)>[
  (['ink', 'ink-muted'], ['surface', 'surface-raised'], 4.5),
  (['on-mood'], _range('mood-', '-soft'), 4.5),
  (['on-mood'], ['mood-3', 'mood-4', 'mood-5'], 3),
  (['ink', 'ink-muted'], _range('mood-', '-night'), 4.5),
  (['on-hero', 'on-hero-muted'], ['hero'], 4.5),
  (['on-sky'], ['sky'], 4.5),
  (['on-sand'], ['sand'], 4.5),
  (['on-tide'], ['tide'], 4.5),
  (['danger'], ['surface', 'surface-raised'], 4.5),
  (['line'], ['surface', 'surface-raised'], 3),
  // Titre et « Voir » de la plage de l'accueil, sur son bandeau de mer.
  (['on-hero'], ['hero-wave-1'], 4.5),
];

/// Paires propres au thème clair : les cartes d'entrée gardent le thème clair dans
/// les deux thèmes (spec 008, CA12), leur heure est en `ink-muted`.
final lightOnlyPairs = <(List<String>, List<String>, double)>[
  (['ink-muted'], _range('mood-', '-soft'), 4.5),
];

void main() {
  test(
    'tokens.json est en version 2 (sinon les paires v2 n\'existent pas)',
    () {
      expect(_tokens['version'], 2);
    },
  );

  test('la formule WCAG : noir sur blanc 21:1, identique 1:1', () {
    expect(contrast('#000000', '#ffffff'), closeTo(21, 0.001));
    expect(contrast('#777777', '#777777'), closeTo(1, 0.001));
  });

  for (final theme in ['light', 'dark']) {
    group('CA3 : thème $theme', () {
      for (final (foregrounds, backgrounds, threshold) in [
        ...pairs,
        if (theme == 'light') ...lightOnlyPairs,
      ]) {
        for (final fg in foregrounds) {
          for (final bg in backgrounds) {
            test('$fg sur $bg : au moins $threshold:1', () {
              expect(_tokens['version'], 2, reason: 'tokens.json v2 attendu');
              final ratio = contrast(_hex(fg, theme), _hex(bg, theme));
              expect(
                ratio,
                greaterThanOrEqualTo(threshold),
                reason:
                    '$fg ${_hex(fg, theme)} sur $bg ${_hex(bg, theme)} : '
                    '${ratio.toStringAsFixed(2)}:1',
              );
            });
          }
        }
      }
    });
  }
}
