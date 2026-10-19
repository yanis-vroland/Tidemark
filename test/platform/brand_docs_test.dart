// Spec 007, CA8 et CA9 : charte et dépôt. Les fichiers sont lus à la racine du dépôt.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/png.dart';

const charter = 'docs/maquettes/000-charte';

void expectFile(String path) {
  expect(File(path).existsSync(), isTrue, reason: '$path est absent');
}

String text(String path) {
  expectFile(path);
  return File(path).readAsStringSync();
}

void main() {
  group('CA8 : composant Logo de la charte', () {
    for (final path in [
      '$charter/components/Logo/preview.html',
      '$charter/components/Logo/README.md',
      '$charter/captures/Logo-clair.png',
      '$charter/captures/Logo-sombre.png',
    ]) {
      test('CA8 : $path existe', () => expectFile(path));
    }

    test('CA8 : les captures sont des PNG', () {
      for (final theme in ['clair', 'sombre']) {
        final png = readPng('$charter/captures/Logo-$theme.png');
        expect(png, isNotNull, reason: 'Logo-$theme.png : PNG attendu');
      }
    });
  });

  group('CA8 : SVG du logo', () {
    for (final name in [
      'tidemark-logo',
      'tidemark-mark',
      'tidemark-mark-mono',
    ]) {
      test('CA8 : logo/$name.svg est un SVG', () {
        expect(text('$charter/logo/$name.svg'), contains('<svg'));
      });
    }

    test('CA8 : la version monochrome n\'utilise pas la couleur du point', () {
      expect(
        text('$charter/logo/tidemark-mark-mono.svg').toLowerCase(),
        isNot(contains('#e2b55a')),
      );
    });

    test(
      'CA8 : la version monochrome est tout en ink clair (spec, « Le logo »)',
      () {
        final svg = text('$charter/logo/tidemark-mark-mono.svg').toLowerCase();
        final colors = RegExp(r'#[0-9a-f]{6}').allMatches(svg).map((m) => m[0]);
        expect(colors.toSet(), {'#13272c'});
      },
    );

    test('CA8 : la version couleur utilise brand et brand-accent', () {
      final svg = text('$charter/logo/tidemark-logo.svg').toLowerCase();
      expect(svg, contains('#1d5f6b'));
      expect(svg, contains('#e2b55a'));
    });
  });

  group('CA8 : règles d\'usage dans charte.md', () {
    test('CA8 : « Pas de logo pour l\'instant » a disparu', () {
      expect(text('$charter/charte.md'), isNot(contains('Pas de logo pour l')));
    });

    test('CA8 : charte.md a une section « Logo »', () {
      expect(
        text('$charter/charte.md'),
        matches(RegExp(r'^#{1,6} .*Logo', multiLine: true)),
      );
    });
  });

  group('CA9 : logo en tête du README et visuel de partage', () {
    test('CA9 : le README commence par le logo centré', () {
      expect(
        text('README.md'),
        startsWith(
          '<p align="center"><img src="docs/maquettes/000-charte/logo/tidemark-logo.svg"',
        ),
      );
    });

    test('CA9 : le visuel de partage GitHub fait 1280 x 640', () {
      final png = readPng('$charter/logo/tidemark-social-preview.png');
      expect(
        png,
        isNotNull,
        reason: 'tidemark-social-preview.png : PNG attendu',
      );
      expect((png!.width, png.height), (1280, 640));
    });
  });
}
