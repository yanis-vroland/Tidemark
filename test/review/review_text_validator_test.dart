// Validateur du texte du bilan (spec 006, « Validation de la sortie », CA22 à CA26,
// CA36) : code Dart pur, sans modèle. Les listes de rejet sont relues dans la spec
// (CA25).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/analysis/tag_vocabulary.dart';
import 'package:tidemark/distress/distress_detector.dart';
import 'package:tidemark/distress/distress_terms.dart';
import 'package:tidemark/review/review_terms.dart';
import 'package:tidemark/review/review_text_validator.dart';

import '../support/analysis_harness.dart' show fencedBlock;
import '../support/fake_review_writer.dart' show jsonText, validReviewText;
import '../support/review_harness.dart';

const validator = ReviewTextValidator();

/// Phrase fictive sans mot de nombre, sans expression interdite et sans détresse,
/// autour de [piece].
String around(String piece) => 'Une semaine calme, $piece, plutôt lumineuse.';

/// Texte accepté tel quel, dans une sortie conforme.
String? validateText(String text) => validator.validate(jsonText(text));

/// Expressions du bloc de code [lang] sous le titre [heading] de la spec : lignes
/// `#` et vides ignorées.
List<String> specList(String heading) => [
  for (final line in const LineSplitter().convert(
    fencedBlock(readReviewSpec(), heading: heading, lang: 'text'),
  ))
    if (line.trim().isNotEmpty && !line.startsWith('#')) line.trim(),
];

const numberHeading = '### Liste des mots de nombre';
const forbiddenHeading = '### Liste des expressions interdites';

void main() {
  group('sortie acceptée', () {
    test('une sortie conforme et propre rend son texte', () {
      expect(
        validateText('Une semaine notée presque chaque jour.'),
        'Une semaine notée presque chaque jour.',
      );
    });

    test('le texte est rendu sans espace au début ni à la fin', () {
      expect(
        validator.validate('{"text": "  Une semaine calme.  "}'),
        'Une semaine calme.',
      );
    });

    test('le texte rendu est celui du JSON décodé (guillemets et \\u00e9 '
        'décodés)', () {
      expect(
        validator.validate(r'{"text": "Une journée \"calme\"."}'),
        'Une journée "calme".',
      );
    });

    test('le texte d\'exemple de la maquette est accepté', () {
      expect(validateText(validReviewText), validReviewText);
    });

    test('« un » et « une » ne sont pas des mots de nombre : ce sont des '
        'articles', () {
      expect(
        validateText('Une semaine, un jour calme, un matin lumineux.'),
        isNotNull,
      );
    });

    test('CA36 : {"text": "Une semaine calme. Sors marcher davantage."} est '
        'acceptée : limite assumée des impératifs absents de la liste', () {
      expect(
        validator.validate(
          '{"text": "Une semaine calme. Sors marcher davantage."}',
        ),
        'Une semaine calme. Sors marcher davantage.',
      );
    });
  });

  group('CA26 règle 1 : objet JSON conforme au schéma, texte non vide', () {
    final invalid = <String, String>{
      'texte libre, pas du JSON': 'Une semaine calme.',
      'sortie vide': '',
      'JSON tronqué': '{"text": "Une semaine calme."',
      'tableau JSON': '["Une semaine calme."]',
      'chaîne JSON': '"Une semaine calme."',
      'objet vide': '{}',
      'champ absent (autre nom)': '{"texte": "Une semaine calme."}',
      'texte nul': '{"text": null}',
      'texte numérique': '{"text": 12}',
      'texte en tableau': '{"text": ["Une semaine calme."]}',
      'champ en trop (additionalProperties false)':
          '{"text": "Une semaine calme.", "note": "x"}',
      'JSON précédé de texte': 'Voici : {"text": "Une semaine calme."}',
      'JSON suivi de texte': '{"text": "Une semaine calme."} Merci.',
    };
    invalid.forEach((name, output) {
      test('CA26 : $name : rejeté', () {
        expect(validator.validate(output), isNull);
      });
    });

    test('CA26 : texte vide : rejeté', () {
      expect(validator.validate('{"text": ""}'), isNull);
    });

    test('CA26 : texte fait d\'espaces et de retours à la ligne : rejeté', () {
      expect(validator.validate('{"text": "   "}'), isNull);
      expect(validator.validate(r'{"text": " \n\t "}'), isNull);
    });
  });

  group('CA26 règle 2 : 300 caractères visibles au plus', () {
    test('CA26 : 300 caractères : accepté', () {
      expect(validateText('a' * 300), isNotNull);
    });

    test('CA26 : 301 caractères : rejeté', () {
      expect(validateText('a' * 301), isNull);
    });

    test('CA26 : un émoji composé compte pour un : 300 émojis composés '
        '(plusieurs milliers d\'unités de code) sont acceptés', () {
      const family = '👨‍👩‍👧‍👦';
      expect(family.length, greaterThan(1));
      expect(validateText(family * 300), isNotNull);
    });

    test('CA26 : 301 émojis composés : rejeté', () {
      const family = '👨‍👩‍👧‍👦';
      expect(validateText(family * 301), isNull);
    });

    test('CA26 : une lettre accentuée décomposée (e + accent) compte pour un '
        'caractère visible', () {
      const decomposed = 'é';
      expect(validateText(decomposed * 300), isNotNull);
      expect(validateText(decomposed * 301), isNull);
    });
  });

  group('CA22 règle 3 : aucun caractère numérique', () {
    final numeric = <String, String>{
      'chiffre': '3 jours',
      'chiffre collé à un mot': 'sur 5',
      'chiffre arabe-indien': '٣ jours',
      'chiffre dévanagari': '३ jours',
      'chiffre pleine chasse': '３ jours',
      'exposant': 'jours au carré²',
      'fraction': '½ de la semaine',
      'chiffre romain (catégorie nombre)': 'Ⅳ jours',
      'signe pour cent': 'presque tout le temps, 100 %',
      'signe % seul': 'à 50% environ',
      'signe pour mille': 'un taux de ‰',
    };
    numeric.forEach((name, piece) {
      test('CA22 : $name (« $piece ») : rejeté', () {
        expect(validateText(around(piece)), isNull);
      });
    });

    test('CA22 : « % » seul, sans chiffre : rejeté', () {
      expect(validateText(around('%')), isNull);
    });

    test('CA22 : la phrase sans caractère numérique est acceptée', () {
      expect(validateText(around('presque chaque jour')), isNotNull);
    });
  });

  group('CA23 règle 4 : mots de nombre, en mots entiers', () {
    final rejected = <String, String>{
      'Trois jours': 'Trois jours notés cette semaine.',
      'la moitié': 'La moitié de la semaine a été notée.',
      'majuscules': 'QUATRE jours se sont ressemblé.',
      'accents': 'Un deuxième jour est revenu.',
      'ponctuation collée': 'Une semaine calme (dix), plutôt lumineuse.',
      'ponctuation derrière': 'Une semaine calme, plutôt lumineuse : sept.',
      'expression de deux mots': 'Une semaine à pour cent calme.',
      'expression avec trait d\'union': 'Une semaine à pour-cent lumineuse.',
      'espaces multiples dans l\'expression':
          'Une semaine à pour   cent calme.',
      'sens de « nouveau » (neuf)': 'Un neuf départ pour la semaine.',
      'double': 'Le double de calme que d\'habitude.',
      'un quart': 'Un quart de la semaine est calme.',
      'mille': 'Mille éclats de lumière.',
    };
    rejected.forEach((name, sentence) {
      test('CA23 : $name : rejeté', () {
        expect(validateText(sentence), isNull);
      });
    });

    final accepted = <String, String>{
      '« septembre » contient « sept »': 'Une semaine calme de septembre.',
      '« deuxièmement » contient « deuxième »':
          'Une semaine calme, et deuxièmement lumineuse.',
      '« centre » contient « cent »':
          'Une semaine calme, centrée sur le centre.',
      '« quartier » contient « quart »': 'Une semaine calme dans le quartier.',
      '« dixit » contient « dix »': 'Une semaine calme, dixit la lumière.',
    };
    accepted.forEach((name, sentence) {
      test('CA23 : $name : accepté (pas de rejet sur une sous-chaîne)', () {
        expect(validateText(sentence), isNotNull);
      });
    });
  });

  group('CA24 règle 4 : expressions interdites et règle 5 : détresse', () {
    test('CA24 : « Tu devrais consulter. » : rejeté', () {
      expect(validateText('Tu devrais consulter.'), isNull);
    });

    test('CA24 : « Une semaine inquiétante. » : rejeté', () {
      expect(validateText('Une semaine inquiétante.'), isNull);
    });

    final rejected = <String, String>{
      'conseil, majuscules': 'TU DEVRAIS te reposer.',
      'apostrophe droite': "N'oublie pas de respirer.",
      'apostrophe typographique': 'N’hésite pas à te poser.',
      'trait d\'union': 'Repose-toi ce week-end.',
      'soin': 'Un psychologue pourrait aider.',
      'jugement': 'Bravo pour cette semaine.',
    };
    rejected.forEach((name, sentence) {
      test('CA24 : $name : rejeté', () {
        expect(validateText(sentence), isNull);
      });
    });

    test('CA24 : expression de la liste de détresse de la spec 002, dans une '
        'phrase propre : rejeté', () {
      expect(
        const DistressDetector().detectInText(distressText),
        isTrue,
        reason: 'prérequis : la phrase est bien détectée',
      );
      expect(validateText(distressText), isNull);
      expect(validateText(around('j’ai envie de mourir')), isNull);
    });

    test('CA24 : chaque expression de la liste de détresse fait rejeter la '
        'sortie (règle 5, detectInText)', () {
      final accepted = [
        for (final expression in distressExpressions)
          if (validateText(around(expression)) != null) expression,
      ];
      expect(distressExpressions, isNotEmpty);
      expect(accepted, isEmpty, reason: 'acceptées à tort : $accepted');
    });

    test('mots entiers : « normalement » ne contient pas l\'expression '
        '« normal » en mot entier : accepté', () {
      expect(
        validateText('Une semaine calme, normalement lumineuse.'),
        isNotNull,
      );
    });
  });

  group('CA25 : listes du code identiques aux blocs de la spec', () {
    test('CA25 : mots de nombre : même ensemble d\'expressions que le bloc '
        '« Liste des mots de nombre »', () {
      final spec = specList(numberHeading);
      expect(spec, isNotEmpty);
      expect(numberWords.toSet(), spec.toSet());
    });

    test('CA25 : expressions interdites : même ensemble que le bloc « Liste '
        'des expressions interdites » (lignes # et vides ignorées)', () {
      final spec = specList(forbiddenHeading);
      expect(spec, isNotEmpty);
      expect(forbiddenExpressions.toSet(), spec.toSet());
    });

    test('CA25 : aucun doublon dans les listes du code', () {
      expect(numberWords, isNotEmpty);
      expect(forbiddenExpressions, isNotEmpty);
      expect(numberWords.length, numberWords.toSet().length);
      expect(forbiddenExpressions.length, forbiddenExpressions.toSet().length);
    });

    test('CA25 : les listes sont sous forme normalisée (minuscules, sans '
        'accents, sans ponctuation)', () {
      expect(numberWords, isNotEmpty);
      expect(forbiddenExpressions, isNotEmpty);
      for (final expression in [...numberWords, ...forbiddenExpressions]) {
        expect(
          DistressDetector.normalize(expression),
          expression,
          reason: '« $expression » n\'est pas normalisée',
        );
      }
    });

    test('CA25 : « un » et « une » ne figurent dans aucune liste', () {
      expect(numberWords, isNotEmpty);
      expect(specList(numberHeading), isNot(contains('un')));
      expect(specList(numberHeading), isNot(contains('une')));
      expect(numberWords, isNot(contains('un')));
      expect(numberWords, isNot(contains('une')));
    });

    test('CA25 : chaque mot de nombre de la spec, inséré dans une phrase '
        'fictive, fait rejeter la sortie', () {
      final accepted = [
        for (final word in specList(numberHeading))
          if (validateText(around(word)) != null) word,
      ];
      expect(accepted, isEmpty, reason: 'acceptés à tort : $accepted');
    });

    test('CA25 : chaque mot de nombre de la spec, en majuscules, fait '
        'rejeter la sortie', () {
      final accepted = [
        for (final word in specList(numberHeading))
          if (validateText(around(word.toUpperCase())) != null) word,
      ];
      expect(accepted, isEmpty, reason: 'acceptés à tort : $accepted');
    });

    test('CA25 : chaque expression interdite de la spec, insérée dans une '
        'phrase fictive, fait rejeter la sortie', () {
      final accepted = [
        for (final expression in specList(forbiddenHeading))
          if (validateText(around(expression)) != null) expression,
      ];
      expect(accepted, isEmpty, reason: 'acceptées à tort : $accepted');
    });

    test('CA25 : la phrase fictive elle-même est acceptée : un rejet vient '
        'bien de l\'expression insérée', () {
      expect(validateText(around('presque chaque jour')), isNotNull);
    });
  });

  group('exigence pour la spec 004 : la liste fermée des étiquettes', () {
    final labels = [...TagVocabulary.emotions, ...TagVocabulary.themes];

    test('aucun libellé de la liste fermée ne figure dans les listes de '
        'rejet', () {
      expect(numberWords, isNotEmpty);
      expect(forbiddenExpressions, isNotEmpty);
      final rejectionList = {...numberWords, ...forbiddenExpressions};
      final conflicts = [
        for (final label in labels)
          if (rejectionList.contains(DistressDetector.normalize(label))) label,
      ];
      expect(conflicts, isEmpty);
    });

    test('aucun libellé de la liste fermée ne figure dans les listes de '
        'rejet de la spec non plus', () {
      final rejectionList = {
        ...specList(numberHeading),
        ...specList(forbiddenHeading),
      };
      final conflicts = [
        for (final label in labels)
          if (rejectionList.contains(DistressDetector.normalize(label))) label,
      ];
      expect(conflicts, isEmpty);
    });

    test('une phrase qui contient chaque libellé est acceptée : une semaine '
        'dominée par cette étiquette garde son texte', () {
      final rejected = [
        for (final label in labels)
          if (validateText('Une semaine où $label revient souvent.') == null)
            label,
      ];
      expect(rejected, isEmpty, reason: 'rejetés à tort : $rejected');
    });
  });
}
