// Format du fichier d'export, version 2 (spec 005, « Format du fichier d'export »,
// CA4 à CA8 ; version 2 : spec 010, CA11). Code Dart pur : ni Flutter ni base, aucun fichier.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/analysis/mood_analyzer.dart';
import 'package:tidemark/distress/distress_detector.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/export/journal_exporter.dart';

const exporter = JournalExporter();

/// Date de l'export des tests octet pour octet : en UTC, pour que le décalage écrit
/// (`+00:00`) ne dépende pas du fuseau de la machine.
final exportedAtUtc = DateTime.utc(2026, 10, 14, 19, 52, 7);

Entry entry({
  required int id,
  required int mood,
  String? text,
  required DateTime createdAt,
  Duration offset = Duration.zero,
  AnalysisStatus status = AnalysisStatus.skipped,
  List<Tag> tags = const [],
}) => Entry(
  id: id,
  mood: mood,
  text: text,
  createdAt: createdAt,
  utcOffset: offset,
  analysisStatus: status,
  tags: tags,
);

/// Chaque champ d'une étiquette sur sa propre ligne : c'est ce que fait
/// `JsonEncoder.withIndent('  ')` (règle normative), pas la présentation compacte de
/// l'exemple de la spec.
const expectedFullExport = r'''
{
  "formatVersion": 2,
  "app": "Tidemark",
  "exportedAt": "2026-10-14T19:52:07+00:00",
  "settings": {
    "lowMoodSensitivity": "high"
  },
  "entries": [
    {
      "createdAt": "2026-10-13T22:05:00+02:00",
      "mood": 2,
      "moodLabel": "Bas",
      "text": "Encore une nuit trop courte.\nJe repousse tout à demain.",
      "analysisStatus": "tagged",
      "tags": [
        {
          "kind": "emotion",
          "label": "fatigue"
        },
        {
          "kind": "emotion",
          "label": "zen"
        },
        {
          "kind": "emotion",
          "label": "écoute"
        },
        {
          "kind": "theme",
          "label": "sommeil"
        }
      ],
      "topics": []
    },
    {
      "createdAt": "2026-10-14T01:15:00-05:00",
      "mood": 5,
      "moodLabel": "Très bien",
      "text": "Dit \"bravo\" à C:\\dossier/sous-dossier, 😀 fin\u0001\u001f\tTab",
      "analysisStatus": "untagged",
      "tags": [],
      "topics": []
    },
    {
      "createdAt": "2026-10-14T08:15:00+02:00",
      "mood": 3,
      "moodLabel": "Neutre",
      "text": null,
      "analysisStatus": "skipped",
      "tags": [],
      "topics": []
    },
    {
      "createdAt": "2026-10-15T00:30:00+05:30",
      "mood": 1,
      "moodLabel": "Très bas",
      "text": "Très bas.",
      "analysisStatus": "pending",
      "tags": [],
      "topics": []
    }
  ]
}
''';

/// Quatre entrées fictives, dans le désordre. Les entrées 2 et 3 ont le même instant
/// de saisie (06:15 UTC) : l'identifiant les départage.
List<Entry> fullEntries() => [
  entry(
    id: 4,
    mood: 1,
    text: 'Très bas.',
    createdAt: DateTime.utc(2026, 10, 14, 19, 0),
    offset: const Duration(hours: 5, minutes: 30),
    status: AnalysisStatus.pending,
  ),
  entry(
    id: 3,
    mood: 3,
    createdAt: DateTime.utc(2026, 10, 14, 6, 15),
    offset: const Duration(hours: 2),
    status: AnalysisStatus.skipped,
  ),
  entry(
    id: 1,
    mood: 2,
    text: 'Encore une nuit trop courte.\nJe repousse tout à demain.',
    createdAt: DateTime.utc(2026, 10, 13, 20, 5),
    offset: const Duration(hours: 2),
    status: AnalysisStatus.tagged,
    // Dans le désordre : le tri est du ressort de l'export.
    tags: const [
      Tag('sommeil', TagKind.theme),
      Tag('zen', TagKind.emotion),
      Tag('écoute', TagKind.emotion),
      Tag('fatigue', TagKind.emotion),
    ],
  ),
  entry(
    id: 2,
    mood: 5,
    text: 'Dit "bravo" à C:\\dossier/sous-dossier, 😀 fin\u0001\u001f\tTab',
    createdAt: DateTime.utc(2026, 10, 14, 6, 15),
    offset: const Duration(hours: -5),
    status: AnalysisStatus.untagged,
  ),
];

Map<String, dynamic> parse(String json) =>
    jsonDecode(json) as Map<String, dynamic>;

String build(
  List<Entry> entries, {
  LowMoodSensitivity sensitivity = LowMoodSensitivity.normal,
  DateTime? exportedAt,
}) => exporter.buildExport(
  entries: entries,
  sensitivity: sensitivity,
  exportedAt: exportedAt ?? exportedAtUtc,
);

List<Map<String, dynamic>> exportedEntries(String json) =>
    (parse(json)['entries'] as List).cast<Map<String, dynamic>>();

void main() {
  group('CA4 : le fichier, octet pour octet', () {
    test('CA4 : entrées fictives et degré « Haute », JSON de la version 2', () {
      final json = build(fullEntries(), sensitivity: LowMoodSensitivity.high);

      expect(json, expectedFullExport);
    });

    test('CA4 : sans entrée, « entries » est une liste vide', () {
      final json = build(const []);

      expect(json, r'''
{
  "formatVersion": 2,
  "app": "Tidemark",
  "exportedAt": "2026-10-14T19:52:07+00:00",
  "settings": {
    "lowMoodSensitivity": "normal"
  },
  "entries": []
}
''');
    });

    test('CA4 : les trois degrés s\'écrivent high, normal et low', () {
      final written = {
        for (final sensitivity in LowMoodSensitivity.values)
          sensitivity:
              (parse(build(const [], sensitivity: sensitivity))['settings']
                  as Map)['lowMoodSensitivity'],
      };

      expect(written, {
        LowMoodSensitivity.high: 'high',
        LowMoodSensitivity.normal: 'normal',
        LowMoodSensitivity.low: 'low',
      });
    });

    test('CA4 : champs dans l\'ordre de la spec, sans identifiant', () {
      final json = parse(build(fullEntries()));

      expect(json.keys, [
        'formatVersion',
        'app',
        'exportedAt',
        'settings',
        'entries',
      ]);
      final first = (json['entries'] as List).first as Map;
      expect(first.keys, [
        'createdAt',
        'mood',
        'moodLabel',
        'text',
        'analysisStatus',
        'tags',
        'topics',
      ]);
      expect(first.containsKey('id'), isFalse);
    });

    test('CA4, CA11 : la version du format est 2', () {
      expect(exportFormatVersion, 2);
      expect(parse(build(const []))['formatVersion'], 2);
    });

    test('CA4 : le fichier se termine par un saut de ligne, sans BOM', () {
      final json = build(fullEntries());

      expect(json.endsWith('}\n'), isTrue);
      expect(json.startsWith('{'), isTrue);
      expect(json.codeUnits.first, isNot(0xFEFF));
    });

    test('CA4 : les entrées vont de la plus ancienne à la plus récente, '
        'l\'identifiant départageant deux saisies au même instant', () {
      final created = [
        for (final e in exportedEntries(build(fullEntries()))) e['createdAt'],
      ];

      expect(created, [
        '2026-10-13T22:05:00+02:00',
        '2026-10-14T01:15:00-05:00',
        '2026-10-14T08:15:00+02:00',
        '2026-10-15T00:30:00+05:30',
      ]);
    });

    test('CA4 : l\'ordre des entrées passées ne change pas le fichier', () {
      final forward = build(fullEntries());
      final backward = build(fullEntries().reversed.toList());

      expect(backward, forward);
    });

    test('CA4 : exportedAt est écrit avec son propre décalage, à la '
        'seconde (heure locale de la machine)', () {
      final local = DateTime(2026, 10, 14, 21, 52, 7);
      final offset = local.timeZoneOffset;
      final sign = offset.isNegative ? '-' : '+';
      final minutes = offset.inMinutes.abs();
      final expectedOffset =
          '$sign${(minutes ~/ 60).toString().padLeft(2, '0')}'
          ':${(minutes % 60).toString().padLeft(2, '0')}';

      final written = parse(build(const [], exportedAt: local))['exportedAt'];

      expect(written, '2026-10-14T21:52:07$expectedOffset');
    });
  });

  group('CA5 : date de saisie avec le décalage enregistré', () {
    test('CA5 : saisie à 21:40 avec +02:00, createdAt vaut '
        '2026-10-14T21:40:00+02:00 quel que soit le fuseau de l\'export', () {
      final json = build(
        [
          entry(
            id: 1,
            mood: 4,
            text: 'Soirée calme.',
            // 21:40 à +02:00 = 19:40 UTC.
            createdAt: DateTime.utc(2026, 10, 14, 19, 40),
            offset: const Duration(hours: 2),
            status: AnalysisStatus.pending,
          ),
        ],
        // Export fait à un autre décalage (+00:00) que celui de la saisie (+02:00).
        exportedAt: DateTime.utc(2026, 10, 14, 19, 52, 7),
      );

      expect(
        exportedEntries(json).single['createdAt'],
        '2026-10-14T21:40:00+02:00',
      );
    });

    test(
      'CA5 : le décalage de la machine n\'intervient pas dans createdAt',
      () {
        // Un décalage qu'aucune machine d'essai n'a probablement : +03:45.
        final json = build([
          entry(
            id: 1,
            mood: 3,
            createdAt: DateTime.utc(2026, 1, 5, 23, 30),
            offset: const Duration(hours: 3, minutes: 45),
          ),
        ]);

        expect(
          exportedEntries(json).single['createdAt'],
          '2026-01-06T03:15:00+03:45',
        );
      },
    );
  });

  group('formatWithOffset', () {
    final cases = <(DateTime, Duration, String)>[
      (
        DateTime.utc(2026, 10, 14, 19, 40),
        const Duration(hours: 2),
        '2026-10-14T21:40:00+02:00',
      ),
      (
        DateTime.utc(2026, 10, 14, 19, 40),
        const Duration(hours: -5),
        '2026-10-14T14:40:00-05:00',
      ),
      (
        DateTime.utc(2026, 10, 14, 19, 40),
        Duration.zero,
        '2026-10-14T19:40:00+00:00',
      ),
      (
        DateTime.utc(2026, 10, 14, 19, 40),
        const Duration(hours: 5, minutes: 30),
        '2026-10-15T01:10:00+05:30',
      ),
      (
        DateTime.utc(2026, 3, 1, 1, 2, 3),
        const Duration(hours: -9, minutes: -30),
        '2026-02-28T15:32:03-09:30',
      ),
    ];

    for (final (utc, offset, expected) in cases) {
      test('$utc avec $offset donne $expected', () {
        expect(formatWithOffset(utc, offset), expected);
      });
    }
  });

  group('CA3 : nom du fichier', () {
    test('CA3 : tidemark-export-2026-10-14-2152.json pour 21:52 locale', () {
      expect(
        exportFileName(DateTime(2026, 10, 14, 21, 52)),
        'tidemark-export-2026-10-14-2152.json',
      );
    });

    test('CA3 : mois, jour, heure et minute sont complétés par des zéros', () {
      expect(
        exportFileName(DateTime(2026, 1, 5, 3, 4, 59)),
        'tidemark-export-2026-01-05-0304.json',
      );
    });

    test('CA3 : minuit donne 0000', () {
      expect(
        exportFileName(DateTime(2026, 12, 31, 0, 0)),
        'tidemark-export-2026-12-31-0000.json',
      );
    });
  });

  group('CA6 : entrées sans texte et en détresse', () {
    test('CA6 : l\'entrée sans texte et l\'entrée en détresse figurent, '
        'skipped et sans étiquette', () {
      final list = exportedEntries(
        build([
          entry(
            id: 1,
            mood: 3,
            createdAt: DateTime.utc(2026, 10, 14, 6, 15),
            offset: const Duration(hours: 2),
            status: AnalysisStatus.skipped,
          ),
          entry(
            id: 2,
            mood: 1,
            text: 'Je n\'y arrive plus.',
            createdAt: DateTime.utc(2026, 10, 14, 7, 0),
            offset: const Duration(hours: 2),
            status: AnalysisStatus.skipped,
          ),
        ]),
      );

      expect(list, hasLength(2));
      expect(list[0]['text'], isNull);
      expect(list[0].containsKey('text'), isTrue);
      expect(list[0]['analysisStatus'], 'skipped');
      expect(list[0]['tags'], isEmpty);
      expect(list[1]['text'], 'Je n\'y arrive plus.');
      expect(list[1]['analysisStatus'], 'skipped');
      expect(list[1]['tags'], isEmpty);
    });

    test('CA6 : les quatre statuts s\'écrivent pending, tagged, untagged et '
        'skipped', () {
      final statuses = [
        for (final e in exportedEntries(build(fullEntries())))
          e['analysisStatus'],
      ];

      expect(statuses, ['tagged', 'untagged', 'skipped', 'pending']);
    });

    test('CA6 : le libellé d\'humeur suit la valeur, de 1 à 5', () {
      final json = build([
        for (var mood = 1; mood <= 5; mood++)
          entry(
            id: mood,
            mood: mood,
            createdAt: DateTime.utc(2026, 10, 14, mood),
          ),
      ]);

      expect(
        [for (final e in exportedEntries(json)) (e['mood'], e['moodLabel'])],
        [
          (1, 'Très bas'),
          (2, 'Bas'),
          (3, 'Neutre'),
          (4, 'Bien'),
          (5, 'Très bien'),
        ],
      );
    });
  });

  group('CA7 : étiquettes', () {
    test('CA7 : forme {kind, label}, emotion avant theme, puis par libellé '
        'en unités de code UTF-16 (« écoute » après « zen »)', () {
      final tags = exportedEntries(build(fullEntries())).first['tags'];

      expect(tags, [
        {'kind': 'emotion', 'label': 'fatigue'},
        {'kind': 'emotion', 'label': 'zen'},
        {'kind': 'emotion', 'label': 'écoute'},
        {'kind': 'theme', 'label': 'sommeil'},
      ]);
    });

    test('CA7 : une émotion passe avant un thème, même si son libellé est '
        'plus loin dans l\'alphabet', () {
      final json = build([
        entry(
          id: 1,
          mood: 3,
          text: 'Avec des amis.',
          createdAt: DateTime.utc(2026, 10, 14, 6),
          status: AnalysisStatus.tagged,
          tags: const [Tag('amis', TagKind.theme), Tag('zen', TagKind.emotion)],
        ),
      ]);

      expect(exportedEntries(json).single['tags'], [
        {'kind': 'emotion', 'label': 'zen'},
        {'kind': 'theme', 'label': 'amis'},
      ]);
    });

    test('CA7 : sans étiquette (avant le lot G), tags est une liste vide '
        'pour toutes les entrées', () {
      final json = build([
        for (var i = 1; i <= 3; i++)
          entry(
            id: i,
            mood: 3,
            text: 'Entrée $i.',
            createdAt: DateTime.utc(2026, 10, 14, i),
            status: AnalysisStatus.pending,
          ),
      ]);

      expect(
        [for (final e in exportedEntries(json)) e['tags']],
        [isEmpty, isEmpty, isEmpty],
      );
      expect(json, contains('"tags": []'));
    });
  });

  group('CA8 : texte relu à l\'identique', () {
    const tricky =
        'Été à l\'île de Ré : « très bien », dit-elle.\n'
        'Famille \u{1F468}\u200D\u{1F469}\u200D\u{1F467} et drapeau \u{1F1EB}\u{1F1F7}.\r\n'
        'Chemin C:\\Users\\moi\\notes, guillemets "droits", barre /, tab\t.\n'
        '\u0000 nul, \u0008 retour, \u001f séparateur, \u007f suppression.\n'
        '\n  Fin avec espaces  \n';

    test('CA8 : accents, émoji composé, guillemets, barre oblique inverse '
        'et retours à la ligne reviennent identiques', () {
      final json = build([
        entry(
          id: 1,
          mood: 4,
          text: tricky,
          createdAt: DateTime.utc(2026, 10, 14, 6),
          status: AnalysisStatus.pending,
        ),
      ]);

      expect(exportedEntries(json).single['text'], tricky);
    });

    test('CA8 : les caractères non ASCII sont écrits tels quels, la barre '
        'oblique n\'est pas échappée', () {
      final json = build([
        entry(
          id: 1,
          mood: 4,
          text: 'é 😀 a/b',
          createdAt: DateTime.utc(2026, 10, 14, 6),
          status: AnalysisStatus.pending,
        ),
      ]);

      expect(json, contains('"text": "é 😀 a/b"'));
    });

    test('CA8 : le fichier est du JSON valide, qui se relit avec un lecteur '
        'standard', () {
      expect(() => jsonDecode(build(fullEntries())), returnsNormally);
    });
  });
}
