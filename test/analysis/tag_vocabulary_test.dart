// Liste fermée des étiquettes et schéma de sortie (spec 004, CA1, RM4, RM19, RM33).
// La référence est le bloc « Liste fermée des étiquettes » de la spec, relu à chaque
// exécution : le test ne contient aucune copie de la liste.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/analysis/tag_vocabulary.dart';

import '../support/analysis_harness.dart';

const vocabularyHeading = '### Liste fermée des étiquettes';

({List<String> emotions, List<String> themes}) specVocabulary() =>
    parseVocabularyBlock(
      fencedBlock(readSpec(), heading: vocabularyHeading, lang: 'text'),
    );

Map<String, dynamic> encodedSchema() =>
    jsonDecode(jsonEncode(TagVocabulary.outputSchema)) as Map<String, dynamic>;

List<dynamic> enumOf(Map<String, dynamic> schema, String property) =>
    (((schema['properties'] as Map<String, dynamic>)[property]
                as Map<String, dynamic>)['items']
            as Map<String, dynamic>)['enum']
        as List<dynamic>;

void main() {
  group('CA1 : le code reprend la liste de la spec', () {
    test('CA1 : le bloc de la spec respecte son format, 12 émotions et 12 '
        'thèmes', () {
      final spec = specVocabulary();

      expect(spec.emotions, hasLength(12));
      expect(spec.themes, hasLength(12));
    });

    test('CA1 : les émotions du code sont celles de la spec, même ordre', () {
      expect(TagVocabulary.emotions, specVocabulary().emotions);
    });

    test('CA1 : les thèmes du code sont ceux de la spec, même ordre', () {
      expect(TagVocabulary.themes, specVocabulary().themes);
    });

    test(
      'CA1 : les listes `enum` du schéma sont tirées des listes du code',
      () {
        final schema = encodedSchema();

        expect(enumOf(schema, 'emotions'), TagVocabulary.emotions);
        expect(enumOf(schema, 'themes'), TagVocabulary.themes);
        expect(TagVocabulary.emotions, isNotEmpty);
        expect(TagVocabulary.themes, isNotEmpty);
      },
    );

    test('CA1 : le schéma passé au moteur est celui de la spec (bornes, clés '
        'requises, pas de clé en plus)', () {
      final expected = jsonDecode(
        fencedBlock(readSpec(), heading: '### Schéma de sortie', lang: 'json'),
      ) as Map<String, dynamic>;

      expect(encodedSchema(), expected);
    });

    test('RM4 : aucune étiquette ne nomme un trouble ou un diagnostic', () {
      final all = [...TagVocabulary.emotions, ...TagVocabulary.themes];

      expect(all, hasLength(24));
      for (final forbidden in ['dépression', 'burn-out', 'crise']) {
        expect(
          all.any((l) => l.contains(forbidden)),
          isFalse,
          reason: forbidden,
        );
      }
    });

    test('les étiquettes sont en minuscules, sans doublon, et une étiquette '
        'n\'est pas à la fois émotion et thème', () {
      final all = [...TagVocabulary.emotions, ...TagVocabulary.themes];

      expect(all, hasLength(24));
      expect(all.toSet(), hasLength(24));
      expect(all.every((l) => l == l.toLowerCase()), isTrue);
    });
  });

  group('CA1 : un bloc hors format fait échouer le test avec un message', () {
    const valid = '# Émotions\njoie\ncalme\n# Thèmes\ntravail\nsport';

    Matcher failsWith(String fragment) => throwsA(
      isA<FormatException>().having(
        (e) => e.message,
        'message',
        contains(fragment),
      ),
    );

    test('un bloc conforme est lu', () {
      final parsed = parseVocabularyBlock(valid);

      expect(parsed.emotions, ['joie', 'calme']);
      expect(parsed.themes, ['travail', 'sport']);
    });

    test('une ligne vide est refusée', () {
      expect(
        () => parseVocabularyBlock(valid.replaceFirst('joie\n', 'joie\n\n')),
        failsWith('ligne vide'),
      );
    });

    test('un commentaire est refusé', () {
      expect(
        () => parseVocabularyBlock('$valid\n# à revoir'),
        failsWith('commentaire'),
      );
    });

    test('un espace en fin de ligne est refusé', () {
      expect(
        () => parseVocabularyBlock(valid.replaceFirst('joie', 'joie ')),
        failsWith('espace en fin de ligne'),
      );
    });

    test('un bloc sans « # Thèmes » est refusé', () {
      expect(
        () => parseVocabularyBlock('# Émotions\njoie\ncalme'),
        failsWith('Thèmes'),
      );
    });

    test('un bloc qui ne commence pas par « # Émotions » est refusé', () {
      expect(
        () => parseVocabularyBlock('joie\n# Thèmes\ntravail'),
        failsWith('# Émotions'),
      );
    });

    test('des sections dans l\'ordre inverse sont refusées', () {
      expect(
        () => parseVocabularyBlock('# Thèmes\ntravail\n# Émotions\njoie'),
        throwsA(isA<FormatException>()),
      );
    });

    test('un titre absent de la spec est signalé', () {
      expect(
        () => fencedBlock(
          '# Autre\n```text\nx\n```',
          heading: '### Absent',
          lang: 'text',
        ),
        failsWith('aucun bloc'),
      );
    });
  });
}
