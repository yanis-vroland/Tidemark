// Jetons ajoutés à la charte par la spec 006 (« Maquette », « Jetons ») : la barre
// de la répartition et la case d'un jour. Le test de fidélité
// (charter_fidelity_test.dart) compare ensuite le code à `tokens.json`.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, String> sizeTokens() {
  final tokens = jsonDecode(
    File('docs/maquettes/000-charte/tokens.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final size = tokens['size'] as Map<String, dynamic>;
  return {
    for (final token in size['tokens'] as List)
      token['name'] as String: token['value'] as String,
  };
}

void main() {
  group('jetons de la spec 006 dans tokens.json', () {
    test('`bar-thickness` : 8 (épaisseur d\'une barre de la répartition)', () {
      expect(sizeTokens()['bar-thickness'], '8px');
    });

    test('`day-cell` : 40 (hauteur d\'une case de « Jours notés »)', () {
      expect(sizeTokens()['day-cell'], '40px');
    });

    test('`icon-md` (24) et `icon-button` (18) restent présents', () {
      expect(sizeTokens()['icon-md'], '24px');
      expect(sizeTokens()['icon-button'], '18px');
    });
  });
}
