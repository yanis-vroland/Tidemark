// Fidélité du thème à la charte : chaque jeton de docs/maquettes/000-charte/tokens.json
// a sa constante Dart, avec la même valeur, et inversement (aucune constante orpheline).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';
import 'package:tidemark/ui/theme/tidemark_tokens.dart';
import 'package:tidemark/ui/theme/tidemark_typography.dart';

Map<String, dynamic> _tokens() =>
    jsonDecode(File('docs/maquettes/000-charte/tokens.json').readAsStringSync())
        as Map<String, dynamic>;

Color _hex(String value) =>
    Color(int.parse('FF${value.substring(1)}', radix: 16));

double _px(String value) => double.parse(value.replaceAll('px', ''));

Map<String, double> _lengths(Map<String, dynamic> family) => {
  for (final token in family['tokens'] as List)
    token['name'] as String: _px(token['value'] as String),
};

void main() {
  final tokens = _tokens();

  group('couleurs', () {
    final colorTokens = (tokens['color'] as Map)['tokens'] as List;

    for (final theme in ['light', 'dark']) {
      test('thème $theme : mêmes jetons, mêmes valeurs', () {
        final dart = theme == 'light'
            ? TidemarkColors.light.toTokenMap()
            : TidemarkColors.dark.toTokenMap();
        final charter = {
          for (final token in colorTokens)
            token['name'] as String: _hex(
              (token['value'] as Map)[theme] as String,
            ),
        };
        expect(dart.keys.toSet(), charter.keys.toSet());
        for (final name in charter.keys) {
          expect(dart[name], charter[name], reason: 'jeton $name ($theme)');
        }
      });
    }
  });

  test('espacements', () {
    expect(
      TidemarkSpacing.tokens,
      _lengths(tokens['spacing'] as Map<String, dynamic>),
    );
  });

  test('rayons', () {
    expect(
      TidemarkRadius.tokens,
      _lengths(tokens['radius'] as Map<String, dynamic>),
    );
  });

  test('tailles', () {
    expect(
      TidemarkSize.tokens,
      _lengths(tokens['size'] as Map<String, dynamic>),
    );
  });

  test('opacités', () {
    expect(
      TidemarkOpacity.tokens,
      _lengths(tokens['opacity'] as Map<String, dynamic>),
    );
  });

  test('styles de texte : taille, interligne, graisse, approche, famille', () {
    final type = tokens['type'] as Map<String, dynamic>;
    final families = {
      'display': TidemarkTypography.displayFamily,
      'body': TidemarkTypography.bodyFamily,
    };
    final names = <String>{};
    for (final group in type['groups'] as List) {
      for (final style in group['styles'] as List) {
        final name = style['name'] as String;
        names.add(name);
        final dart = TidemarkTypography.tokens[name];
        expect(dart, isNotNull, reason: 'style $name absent du code');
        final size = _px(style['fontSize'] as String);
        expect(dart!.fontSize, size, reason: name);
        expect(
          dart.height! * size,
          closeTo(_px(style['lineHeight'] as String), 0.001),
          reason: name,
        );
        expect(dart.fontWeight!.value, style['fontWeight'], reason: name);
        expect(dart.fontVariations, [
          FontVariation.weight((style['fontWeight'] as int).toDouble()),
        ], reason: name);
        expect(
          dart.letterSpacing,
          style['letterSpacing'] == null
              ? 0
              : _px(style['letterSpacing'] as String),
          reason: name,
        );
        expect(dart.fontFamily, families[group['family']], reason: name);
      }
    }
    expect(TidemarkTypography.tokens.keys.toSet(), names);
  });
}
