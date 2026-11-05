// Charte v2 (spec 008, CA1) : les valeurs écrites dans la spec, indépendamment de
// tokens.json. charter_fidelity_test.dart vérifie que le code suit tokens.json ;
// ce test vérifie que les deux disent ce que la spec dit.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';
import 'package:tidemark/ui/theme/tidemark_tokens.dart';
import 'package:tidemark/ui/theme/tidemark_typography.dart';

Color _hex(String value) =>
    Color(int.parse('FF${value.substring(1)}', radix: 16));

/// Jeton -> (clair, sombre), tableau « Couleurs » de la spec 008.
const Map<String, (String, String)> specColors = {
  'surface': ('#f7f3ec', '#0c1719'),
  'surface-raised': ('#ffffff', '#15252a'),
  'ink': ('#14262b', '#e6efed'),
  'ink-muted': ('#4b5e64', '#b4c5c5'),
  'line': ('#76898d', '#7d9599'),
  'tide': ('#1d5f6b', '#7cc5c9'),
  'on-tide': ('#ffffff', '#0a2226'),
  'tide-soft': ('#dbeae9', '#1e383c'),
  'danger': ('#a3392a', '#f39582'),
  'mood-1': ('#5868ad', '#5868ad'),
  'mood-2': ('#6b93d3', '#6b93d3'),
  'mood-3': ('#62b3a5', '#62b3a5'),
  'mood-4': ('#f0b84a', '#f0b84a'),
  'mood-5': ('#f78b52', '#f78b52'),
  'mood-1-soft': ('#dfe3f6', '#dfe3f6'),
  'mood-2-soft': ('#dde9f9', '#dde9f9'),
  'mood-3-soft': ('#d9f1eb', '#d9f1eb'),
  'mood-4-soft': ('#fdf0cf', '#fdf0cf'),
  'mood-5-soft': ('#ffe2d1', '#ffe2d1'),
  'on-mood': ('#14262b', '#14262b'),
  'mood-1-night': ('#e9ebf5', '#1a2136'),
  'mood-2-night': ('#e8eff8', '#172536'),
  'mood-3-night': ('#e6f2ee', '#142a29'),
  'mood-4-night': ('#fbf2dc', '#2c271c'),
  'mood-5-night': ('#fde9dc', '#30231d'),
  'bubble-cheek': ('#ff8f7d', '#ff8f7d'),
  'bubble-tear': ('#8fc1ef', '#8fc1ef'),
  'bubble-shine': ('#ffffff', '#ffffff'),
  'hero': ('#1d5f6b', '#0f3a41'),
  'hero-wave-1': ('#2a7480', '#13454c'),
  'hero-wave-2': ('#3b8b93', '#185058'),
  'on-hero': ('#ffffff', '#ffffff'),
  'on-hero-muted': ('#d5ebea', '#c9dfdf'),
  'sky': ('#cfe9ec', '#0f2d3d'),
  'on-sky': ('#0f3f48', '#e6efed'),
  'sea': ('#3b8b93', '#1d5f6b'),
  'sun': ('#fdd77a', '#fdd77a'),
  'moon': ('#fdf0cf', '#fdf0cf'),
  'sand': ('#f6e4bd', '#3a3222'),
  'on-sand': ('#6b5320', '#e8d9b5'),
  'brand': ('#1d5f6b', '#1d5f6b'),
  'on-brand': ('#ffffff', '#ffffff'),
  'brand-accent': ('#e2b55a', '#e2b55a'),
};

void main() {
  group('couleurs (CA1)', () {
    test(
      'le code a exactement les jetons de la spec, dans les deux thèmes',
      () {
        expect(
          TidemarkColors.light.toTokenMap().keys.toSet(),
          specColors.keys.toSet(),
        );
        expect(
          TidemarkColors.dark.toTokenMap().keys.toSet(),
          specColors.keys.toSet(),
        );
      },
    );

    for (final entry in specColors.entries) {
      test(
        '${entry.key} : ${entry.value.$1} (clair), ${entry.value.$2} (sombre)',
        () {
          expect(
            TidemarkColors.light.toTokenMap()[entry.key],
            _hex(entry.value.$1),
            reason: 'clair',
          );
          expect(
            TidemarkColors.dark.toTokenMap()[entry.key],
            _hex(entry.value.$2),
            reason: 'sombre',
          );
        },
      );
    }

    test('les champs nommés du contrat existent et valent les jetons', () {
      final c = TidemarkColors.light;
      expect(c.mood1Soft, _hex('#dfe3f6'));
      expect(c.mood5Soft, _hex('#ffe2d1'));
      expect(c.mood1Night, _hex('#e9ebf5'));
      expect(c.mood5Night, _hex('#fde9dc'));
      expect(c.bubbleCheek, _hex('#ff8f7d'));
      expect(c.bubbleTear, _hex('#8fc1ef'));
      expect(c.bubbleShine, _hex('#ffffff'));
      expect(c.hero, _hex('#1d5f6b'));
      expect(c.heroWave1, _hex('#2a7480'));
      expect(c.heroWave2, _hex('#3b8b93'));
      expect(c.onHero, _hex('#ffffff'));
      expect(c.onHeroMuted, _hex('#d5ebea'));
      expect(c.sky, _hex('#cfe9ec'));
      expect(c.onSky, _hex('#0f3f48'));
      expect(c.sea, _hex('#3b8b93'));
      expect(c.sun, _hex('#fdd77a'));
      expect(c.moon, _hex('#fdf0cf'));
      expect(c.sand, _hex('#f6e4bd'));
      expect(c.onSand, _hex('#6b5320'));
      final d = TidemarkColors.dark;
      expect(d.mood1Night, _hex('#1a2136'));
      expect(d.hero, _hex('#0f3a41'));
      expect(d.sand, _hex('#3a3222'));
      expect(d.onSand, _hex('#e8d9b5'));
    });

    test('moodColor, moodSoftColor et moodNightColor suivent l\'humeur', () {
      for (final c in [TidemarkColors.light, TidemarkColors.dark]) {
        for (var mood = 1; mood <= 5; mood++) {
          expect(c.moodColor(mood), c.toTokenMap()['mood-$mood']);
          expect(c.moodSoftColor(mood), c.toTokenMap()['mood-$mood-soft']);
          expect(c.moodNightColor(mood), c.toTokenMap()['mood-$mood-night']);
        }
      }
    });
  });

  group('typographie (CA1)', () {
    // (taille, interligne, graisse, approche, famille)
    const display = TidemarkTypography.displayFamily;
    const body = TidemarkTypography.bodyFamily;
    final spec = <String, (double, double, int, double, String)>{
      'display': (40, 44, 800, -1, display),
      'title': (22, 28, 700, 0, display),
      'stat': (30, 34, 800, 0, display),
      'headline': (17, 24, 600, 0, body),
      'body': (16, 24, 400, 0, body),
      'button': (17, 20, 700, 0, body),
      'label': (14, 20, 600, double.nan, body),
      'sticker': (15, 20, 700, 0, body),
      'caption': (13, 18, 400, 0, body),
    };

    test('exactement les neuf styles de la spec, sans mood-numeral', () {
      expect(TidemarkTypography.tokens.keys.toSet(), spec.keys.toSet());
    });

    for (final MapEntry(key: name, value: v) in spec.entries) {
      test('style $name', () {
        final style = TidemarkTypography.tokens[name]!;
        expect(style.fontSize, v.$1);
        expect(style.height! * v.$1, closeTo(v.$2, 0.001));
        expect(style.fontWeight!.value, v.$3);
        expect(style.fontVariations, [FontVariation.weight(v.$3.toDouble())]);
        // « label » : approche non précisée par la spec (voir ambiguïtés).
        if (!v.$4.isNaN) expect(style.letterSpacing ?? 0, v.$4);
        expect(style.fontFamily, v.$5);
      });
    }
  });

  group('rayons, tailles, ombres (CA1)', () {
    test('rayons', () {
      expect(TidemarkRadius.radiusSm, 8);
      expect(TidemarkRadius.radiusMd, 16);
      expect(TidemarkRadius.radiusLg, 24);
      expect(TidemarkRadius.radiusXl, 28);
      expect(TidemarkRadius.tokens.keys.toSet(), {
        'radius-sm',
        'radius-md',
        'radius-lg',
        'radius-xl',
        'radius-pill',
      });
    });

    test('tailles', () {
      expect(TidemarkSize.tapMin, 44);
      expect(TidemarkSize.buttonHeight, 56);
      expect(TidemarkSize.bubbleSm, 36);
      expect(TidemarkSize.bubbleMd, 48);
      expect(TidemarkSize.bubbleCheck, 54);
      expect(TidemarkSize.bubbleSelect, 44);
      expect(TidemarkSize.bubbleSelectOn, 52);
      expect(TidemarkSize.bubbleLg, 120);
      expect(TidemarkSize.bubbleXl, 150);
      expect(TidemarkSize.navBubble, 64);
      expect(TidemarkSize.tokens, containsPair('bubble-xl', 150));
      expect(TidemarkSize.tokens, containsPair('nav-bubble', 64));
      for (final kept in [
        'icon-sm',
        'icon-md',
        'icon-button',
        'progress-height',
        'ring-width',
        'bar-thickness',
        'day-cell',
        'logo-md',
      ]) {
        expect(TidemarkSize.tokens, contains(kept));
      }
    });

    test('ombres : valeurs CSS exactes de la spec', () {
      expect(TidemarkShadows.tokens, {
        'shadow-card': '0px 12px 32px rgba(20, 38, 43, 0.12)',
        'shadow-sticker': '0px 3px 0px rgba(20, 38, 43, 0.14)',
        'shadow-press': '0px 4px 0px rgba(10, 34, 38, 0.3)',
      });
    });

    test('ombres : BoxShadow de la spec (x, y, flou, couleur)', () {
      expect(TidemarkShadows.shadowCard.single.offset, const Offset(0, 12));
      expect(TidemarkShadows.shadowCard.single.blurRadius, 32);
      expect(TidemarkShadows.shadowSticker.single.offset, const Offset(0, 3));
      expect(TidemarkShadows.shadowSticker.single.blurRadius, 0);
      expect(TidemarkShadows.shadowPress.single.offset, const Offset(0, 4));
      expect(TidemarkShadows.shadowPress.single.blurRadius, 0);
      expect(
        TidemarkShadows.shadowCard.single.color.toARGB32(),
        Color.fromRGBO(20, 38, 43, 0.12).toARGB32(),
      );
      expect(
        TidemarkShadows.shadowSticker.single.color.toARGB32(),
        Color.fromRGBO(20, 38, 43, 0.14).toARGB32(),
      );
      expect(
        TidemarkShadows.shadowPress.single.color.toARGB32(),
        Color.fromRGBO(10, 34, 38, 0.3).toARGB32(),
      );
    });
  });

  test('tokens.json est en version 2 avec les valeurs de la spec', () {
    final json = jsonDecode(
      File('docs/maquettes/000-charte/tokens.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(json['version'], 2);
    final byName = {
      for (final t in (json['color'] as Map)['tokens'] as List)
        t['name'] as String: t['value'] as Map,
    };
    expect(byName.keys.toSet(), specColors.keys.toSet());
    for (final entry in specColors.entries) {
      expect(byName[entry.key]!['light'], entry.value.$1, reason: entry.key);
      expect(byName[entry.key]!['dark'], entry.value.$2, reason: entry.key);
    }
  });
}
