// Liste des termes (spec 002, CA14) : le code reprend à l'identique le bloc de la spec.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/distress/distress_detector.dart';
import 'package:tidemark/distress/distress_terms.dart';

const detector = DistressDetector();

/// Expressions du bloc ```text de la section « Liste des termes » de la spec : les
/// lignes vides et celles qui commencent par `#` sont ignorées.
Set<String> specExpressions() {
  final spec = File('docs/specs/002-garde-fou-detresse.md').readAsStringSync();
  final section = spec.indexOf('### Liste des termes');
  expect(
    section,
    isNonNegative,
    reason: 'section « Liste des termes » absente',
  );
  final open = spec.indexOf('```text', section);
  expect(open, isNonNegative, reason: 'bloc ```text absent');
  final start = spec.indexOf('\n', open) + 1;
  final end = spec.indexOf('```', start);
  return spec
      .substring(start, end)
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toSet();
}

/// Initialisé à la première lecture, donc dans un test.
final fromSpec = specExpressions();

void main() {
  test('CA14 : la lecture de la spec trouve une liste réaliste', () {
    // Garde-fou du test : une lecture qui ne trouverait rien ferait passer la
    // comparaison d'ensembles sur deux listes vides.
    expect(fromSpec.length, greaterThan(80));
    expect(fromSpec, contains('envie de mourir'));
    expect(fromSpec, contains('aucune issue'));
    expect(fromSpec.any((e) => e.startsWith('#')), isFalse);
  });

  test('CA14 : la liste du code est identique au bloc de la spec', () {
    final inCode = distressExpressions.toSet();

    expect(
      inCode.difference(fromSpec),
      isEmpty,
      reason: 'dans le code mais pas dans la spec',
    );
    expect(
      fromSpec.difference(inCode),
      isEmpty,
      reason: 'dans la spec mais pas dans le code',
    );
  });

  test('CA14 : la liste du code ne répète aucune expression', () {
    expect(distressExpressions, isNotEmpty);
    expect(distressExpressions.length, distressExpressions.toSet().length);
  });

  test('les expressions sont écrites sous leur forme normalisée', () {
    expect(distressExpressions, isNotEmpty);
    final notNormalized = [
      for (final e in distressExpressions)
        if (DistressDetector.normalize(e) != e) e,
    ];
    expect(notNormalized, isEmpty);
  });

  test('CA14 : chaque expression de la spec, insérée dans une phrase fictive, '
      'est détectée', () {
    final missed = [
      for (final e in fromSpec)
        if (!detector.detectInText('Ce soir, franchement, $e. Voilà.')) e,
    ];
    expect(missed, isEmpty);
  });

  test('CA14 : chaque expression, seule, en début ou en fin de texte, est '
      'détectée', () {
    final missed = [
      for (final e in fromSpec)
        if (!detector.detectInText(e) ||
            !detector.detectInText('$e, vraiment') ||
            !detector.detectInText('vraiment, $e'))
          e,
    ];
    expect(missed, isEmpty);
  });

  test(
    'CA14 : chaque expression, en majuscules et séparée par des retours à la '
    'ligne, est détectée',
    () {
      final missed = [
        for (final e in fromSpec)
          if (!detector.detectInText(e.toUpperCase().replaceAll(' ', '\n'))) e,
      ];
      expect(missed, isEmpty);
    },
  );

  test('CA3 : collée à la fin du mot précédent, aucune expression n\'est '
      'détectée', () {
    final wrongly = [
      for (final e in fromSpec)
        if (detector.detectInText('x$e')) e,
    ];
    expect(wrongly, isEmpty);
  });

  test('CA3 : collée au début du mot suivant, aucune expression n\'est '
      'détectée', () {
    final wrongly = [
      for (final e in fromSpec)
        if (detector.detectInText('${e}x')) e,
    ];
    expect(wrongly, isEmpty);
  });

  test('les termes exclus volontairement ne sont pas des expressions', () {
    for (final excluded in ['me tue', 'mort', 'mourir', 'en finir']) {
      expect(distressExpressions, isNot(contains(excluded)));
      expect(detector.detectInText(excluded), isFalse);
    }
  });
}
