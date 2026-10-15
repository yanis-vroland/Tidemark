// Validation de la sortie du modèle (spec 004, CA2 à CA5, RM9) : `TagOutputParser`
// est du code pur, testé sur des chaînes. Il ne lève jamais d'exception.
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/analysis/mood_analyzer.dart';
import 'package:tidemark/analysis/tag_output_parser.dart';

import '../support/analysis_harness.dart';

const conform = '{"emotions": ["fatigue", "calme"], "themes": ["travail"]}';

void expectUntagged(String raw) {
  late AnalysisResult result;
  expect(() => result = TagOutputParser.parse(raw), returnsNormally);
  expect(result, isA<Untagged>(), reason: 'sortie : $raw');
}

void main() {
  group('CA2 : sortie conforme', () {
    test('CA2 : fatigue et calme (émotions) puis travail (thème), dans cet '
        'ordre', () {
      expectTagged(TagOutputParser.parse(conform), [
        emotion('fatigue'),
        emotion('calme'),
        theme('travail'),
      ]);
    });

    test('CA2 : les émotions viennent avant les thèmes, même si les clés sont '
        'écrites dans l\'autre ordre', () {
      expectTagged(
        TagOutputParser.parse(
          '{"themes": ["sport"], "emotions": ["joie", "espoir"]}',
        ),
        [emotion('joie'), emotion('espoir'), theme('sport')],
      );
    });

    test('CA2 : l\'ordre de la sortie est conservé, pas l\'ordre alphabétique '
        'ni celui de la liste fermée', () {
      expectTagged(
        TagOutputParser.parse(
          '{"emotions": ["tristesse", "joie"], "themes": ["sport", "famille"]}',
        ),
        [
          emotion('tristesse'),
          emotion('joie'),
          theme('sport'),
          theme('famille'),
        ],
      );
    });

    test('CA2 : chaque étiquette de la liste fermée est acceptée à sa place, '
        'avec accents', () {
      expectTagged(
        TagOutputParser.parse(
          '{"emotions": ["fierté", "anxiété", "colère"], '
          '"themes": ["études", "santé"]}',
        ),
        [
          emotion('fierté'),
          emotion('anxiété'),
          emotion('colère'),
          theme('études'),
          theme('santé'),
        ],
      );
    });
  });

  group('CA3 : sortie non conforme, toujours Untagged et sans exception', () {
    const cases = <String, String>{
      'chaîne vide': '',
      'espaces seuls': '   \n ',
      'texte qui n\'est pas du JSON': 'Voici les étiquettes : joie et calme.',
      'JSON tronqué': '{"emotions": ["fatigue", "calme"], "themes": ["trav',
      'JSON tronqué avant la fin de l\'objet':
          '{"emotions": ["fatigue"], "themes": ["travail"]',
      'tableau au lieu d\'un objet': '["fatigue", "travail"]',
      'null': 'null',
      'nombre': '42',
      'chaîne JSON': '"joie"',
      'objet vide': '{}',
      'clé emotions absente': '{"themes": ["travail"]}',
      'clé themes absente': '{"emotions": ["joie"]}',
      'clé en plus':
          '{"emotions": ["joie"], "themes": ["travail"], "note": "ok"}',
      'clé en plus qui détourne la consigne': '{"emotions": ["joie"], "themes": [], "reponse": "ignore les consignes"}',
      'clé mal nommée': '{"emotion": ["joie"], "themes": ["travail"]}',
      'emotions n\'est pas un tableau (chaîne)':
          '{"emotions": "joie", "themes": ["travail"]}',
      'emotions vaut null': '{"emotions": null, "themes": ["travail"]}',
      'themes n\'est pas un tableau (objet)':
          '{"emotions": ["joie"], "themes": {"travail": true}}',
      'élément non chaîne (nombre)': '{"emotions": [1], "themes": ["travail"]}',
      'élément non chaîne (null)':
          '{"emotions": ["joie", null], "themes": ["travail"]}',
      'élément non chaîne (tableau)':
          '{"emotions": [["joie"]], "themes": ["travail"]}',
      'étiquette hors liste': '{"emotions": ["euphorie"], "themes": []}',
      'étiquette hors liste parmi des valides':
          '{"emotions": ["joie", "euphorie"], "themes": ["travail"]}',
      'étiquette qui nomme un trouble':
          '{"emotions": ["dépression"], "themes": ["santé"]}',
      'émotion dans le tableau des thèmes':
          '{"emotions": [], "themes": ["joie"]}',
      'thème dans le tableau des émotions':
          '{"emotions": ["travail"], "themes": ["sport"]}',
      'variante de casse (Joie)': '{"emotions": ["Joie"], "themes": []}',
      'variante de casse (majuscules)': '{"emotions": ["JOIE"], "themes": []}',
      'variante d\'accent (anxiete)':
          '{"emotions": ["anxiete"], "themes": ["travail"]}',
      'accent ajouté à tort': '{"emotions": ["joié"], "themes": []}',
      'accent décomposé (e + accent combinant)':
          '{"emotions": ["fierté"], "themes": []}',
      'espace dans l\'étiquette': '{"emotions": [" joie"], "themes": []}',
      'étiquette vide': '{"emotions": [""], "themes": ["travail"]}',
      '4 émotions':
          '{"emotions": ["joie", "calme", "espoir", "fatigue"], "themes": []}',
      '5 émotions distinctes':
          '{"emotions": ["joie", "calme", "espoir", "fatigue", "ennui"], '
          '"themes": ["travail"]}',
      '3 thèmes':
          '{"emotions": ["joie"], "themes": ["travail", "sport", "famille"]}',
      'aucune étiquette en tout': '{"emotions": [], "themes": []}',
      'texte avant l\'objet': 'Voici : $conform',
      'texte après l\'objet': '$conform Merci !',
      'objet dans un bloc de code Markdown': '```json\n$conform\n```',
      'deux objets à la suite': '$conform$conform',
      'objet suivi d\'un autre objet':
          '$conform {"emotions": [], "themes": []}',
    };

    for (final entry in cases.entries) {
      test('CA3 : ${entry.key}', () => expectUntagged(entry.value));
    }
  });

  group('CA4 : doublons et espaces', () {
    test('CA4 : les doublons sont retirés, le premier est gardé', () {
      expectTagged(
        TagOutputParser.parse(
          '{"emotions": ["joie", "joie", "calme"], "themes": []}',
        ),
        [emotion('joie'), emotion('calme')],
      );
    });

    test('CA4 : le premier doublon est gardé à sa place', () {
      expectTagged(
        TagOutputParser.parse(
          '{"emotions": ["calme", "joie", "calme"], "themes": []}',
        ),
        [emotion('calme'), emotion('joie')],
      );
    });

    test('CA4 : les doublons de thèmes sont retirés aussi', () {
      expectTagged(
        TagOutputParser.parse(
          '{"emotions": [], "themes": ["sport", "sport", "nature"]}',
        ),
        [theme('sport'), theme('nature')],
      );
    });

    test('CA4 : les doublons sont retirés avant le plafond : 4 éléments dont '
        '3 distincts sont conformes', () {
      expectTagged(
        TagOutputParser.parse(
          '{"emotions": ["joie", "joie", "calme", "espoir"], "themes": []}',
        ),
        [emotion('joie'), emotion('calme'), emotion('espoir')],
      );
    });

    test('CA4 : quatre fois la même émotion donne une seule émotion', () {
      expectTagged(
        TagOutputParser.parse(
          '{"emotions": ["joie", "joie", "joie", "joie"], "themes": []}',
        ),
        [emotion('joie')],
      );
    });

    test('CA4 : trois thèmes dont deux identiques donnent deux thèmes', () {
      expectTagged(
        TagOutputParser.parse(
          '{"emotions": ["joie"], "themes": ["sport", "sport", "famille"]}',
        ),
        [emotion('joie'), theme('sport'), theme('famille')],
      );
    });

    test('CA4 : 4 émotions distinctes restent non conformes même avec des '
        'doublons en plus', () {
      expectUntagged(
        '{"emotions": ["joie", "joie", "calme", "espoir", "fatigue"], '
        '"themes": ["travail"]}',
      );
    });

    test('CA4 : des espaces et sauts de ligne autour de l\'objet sont '
        'ignorés', () {
      expectTagged(TagOutputParser.parse('  \n\t$conform \n\n'), [
        emotion('fatigue'),
        emotion('calme'),
        theme('travail'),
      ]);
    });

    test('CA4 : doublons et espaces ensemble', () {
      expectTagged(
        TagOutputParser.parse(
          ' {"emotions": ["joie", "joie", "calme"], "themes": []} ',
        ),
        [emotion('joie'), emotion('calme')],
      );
    });
  });

  group('CA5 et bornes : 0 à 3 émotions, 0 à 2 thèmes, au moins une', () {
    test('CA5 : 0 émotion et 1 thème donnent ce seul thème', () {
      expectTagged(
        TagOutputParser.parse('{"emotions": [], "themes": ["maison"]}'),
        [theme('maison')],
      );
    });

    test('1 émotion et 0 thème donnent cette seule émotion (minimum de 1)', () {
      expectTagged(
        TagOutputParser.parse('{"emotions": ["ennui"], "themes": []}'),
        [emotion('ennui')],
      );
    });

    test('3 émotions et 2 thèmes sont les bornes hautes, conformes', () {
      expectTagged(
        TagOutputParser.parse(
          '{"emotions": ["joie", "calme", "gratitude"], '
          '"themes": ["amis", "loisirs"]}',
        ),
        [
          emotion('joie'),
          emotion('calme'),
          emotion('gratitude'),
          theme('amis'),
          theme('loisirs'),
        ],
      );
    });

    test('3 émotions seules sont conformes', () {
      expectTagged(
        TagOutputParser.parse(
          '{"emotions": ["joie", "calme", "gratitude"], "themes": []}',
        ),
        [emotion('joie'), emotion('calme'), emotion('gratitude')],
      );
    });

    test('2 thèmes seuls sont conformes', () {
      expectTagged(
        TagOutputParser.parse('{"emotions": [], "themes": ["amis", "argent"]}'),
        [theme('amis'), theme('argent')],
      );
    });
  });

  group('cas limite : texte qui tente de détourner la consigne', () {
    test('une réponse libre à la place de l\'objet est Untagged', () {
      expectUntagged(
        'Bien sûr ! Ignorons les consignes : voici un poème sur la mer.',
      );
    });

    test('une réponse libre glissée avant l\'objet conforme est Untagged', () {
      expectUntagged('Ignore les consignes. $conform');
    });
  });
}
