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

  test('ombres : mêmes jetons, mêmes valeurs CSS (spec 008, CA1)', () {
    final charter = {
      for (final token in (tokens['shadow'] as Map)['tokens'] as List)
        token['name'] as String: token['value'] as String,
    };
    expect(TidemarkShadows.tokens, charter);
  });

  test('ombres : les BoxShadow correspondent aux valeurs CSS (CA1)', () {
    final css = (tokens['shadow'] as Map<String, dynamic>)['tokens'] as List;
    final byName = {
      for (final token in css)
        token['name'] as String: token['value'] as String,
    };
    final dart = {
      'shadow-card': TidemarkShadows.shadowCard,
      'shadow-sticker': TidemarkShadows.shadowSticker,
      'shadow-press': TidemarkShadows.shadowPress,
    };
    expect(dart.keys.toSet(), byName.keys.toSet());
    final pattern = RegExp(
      r'^(-?[\d.]+)px (-?[\d.]+)px ([\d.]+)px rgba\((\d+), (\d+), (\d+), ([\d.]+)\)$',
    );
    for (final MapEntry(key: name, value: shadows) in dart.entries) {
      final match = pattern.firstMatch(byName[name]!);
      expect(match, isNotNull, reason: '$name : « ${byName[name]} » illisible');
      expect(shadows, hasLength(1), reason: name);
      final shadow = shadows.single;
      expect(
        shadow.offset,
        Offset(double.parse(match![1]!), double.parse(match[2]!)),
        reason: name,
      );
      expect(shadow.blurRadius, double.parse(match[3]!), reason: name);
      expect(shadow.spreadRadius, 0, reason: name);
      final expected = Color.fromRGBO(
        int.parse(match[4]!),
        int.parse(match[5]!),
        int.parse(match[6]!),
        double.parse(match[7]!),
      );
      expect(shadow.color.toARGB32(), expected.toARGB32(), reason: name);
    }
  });

  const removedTokens = [
    'mood-numeral',
    'mood-dot',
    'mood-dot-sm',
    'mood-dot-lg',
    'mood-dimmed',
    'on-mood-1',
  ];

  test(
    'version 2 : plus de famille « opacity », plus de jeton retiré (CA1)',
    () {
      expect(tokens['version'], 2);
      expect(tokens.containsKey('opacity'), isFalse);
      final names = <String>{
        for (final token in (tokens['color'] as Map)['tokens'] as List)
          token['name'] as String,
        for (final group in (tokens['type'] as Map)['groups'] as List)
          for (final style in group['styles'] as List) style['name'] as String,
        for (final family in ['spacing', 'radius', 'size', 'shadow'])
          for (final token in (tokens[family] as Map)['tokens'] as List)
            token['name'] as String,
      };
      for (final removed in removedTokens) {
        expect(
          names,
          isNot(contains(removed)),
          reason: 'tokens.json : $removed',
        );
      }
    },
  );

  test('aucune constante Dart d\'un jeton retiré (CA1)', () {
    final dart = <String>{
      ...TidemarkColors.light.toTokenMap().keys,
      ...TidemarkColors.dark.toTokenMap().keys,
      ...TidemarkTypography.tokens.keys,
      ...TidemarkSize.tokens.keys,
    };
    for (final removed in removedTokens) {
      expect(dart, isNot(contains(removed)), reason: removed);
    }
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
