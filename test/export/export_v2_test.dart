// Format du fichier d'export, version 2 (spec 010, CA11) : `formatVersion` à 2 et,
// pour chaque entrée, `topics` après `tags`, la liste des libellés des sujets dans
// l'ordre de la liste (vide sans sujet). Le reste est identique à la version 1
// (spec 005, « Format »). Code Dart pur, puis export complet sur un dépôt factice.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/analysis/mood_analyzer.dart';
import 'package:tidemark/distress/distress_detector.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/entries/topic.dart';
import 'package:tidemark/export/journal_export.dart';
import 'package:tidemark/export/journal_exporter.dart';

import '../support/fake_entry_repository.dart';
import '../support/fake_settings_repository.dart';
import '../support/fake_share_sheet.dart';
import '../support/wipe_harness.dart' show WipeEnv;

const exporter = JournalExporter();
final exportedAt = DateTime.utc(2026, 10, 14, 19, 52, 7);

Entry entry({
  required int id,
  required DateTime createdAt,
  List<Tag> tags = const [],
  List<Topic> topics = const [],
  String? text,
}) => Entry(
  id: id,
  mood: 4,
  text: text,
  createdAt: createdAt,
  utcOffset: const Duration(hours: 2),
  analysisStatus: text == null ? AnalysisStatus.skipped : AnalysisStatus.tagged,
  tags: tags,
  topics: topics,
);

String build(List<Entry> entries) => exporter.buildExport(
  entries: entries,
  sensitivity: LowMoodSensitivity.normal,
  exportedAt: exportedAt,
);

List<Map<String, dynamic>> entriesOf(String json) =>
    ((jsonDecode(json) as Map)['entries'] as List).cast<Map<String, dynamic>>();

void main() {
  group('le fichier de la version 2', () {
    test('CA11 : la version du format est 2', () {
      expect(exportFormatVersion, 2);
      expect((jsonDecode(build(const [])) as Map)['formatVersion'], 2);
    });

    test('CA11 : une entrée avec sujets, octet pour octet', () {
      final json = build([
        entry(
          id: 1,
          createdAt: DateTime.utc(2026, 10, 14, 19, 40),
          text: 'Balade.',
          tags: const [Tag('calme', TagKind.emotion)],
          topics: [Topic.nature, Topic.amis],
        ),
      ]);

      expect(json, r'''
{
  "formatVersion": 2,
  "app": "Tidemark",
  "exportedAt": "2026-10-14T19:52:07+00:00",
  "settings": {
    "lowMoodSensitivity": "normal"
  },
  "entries": [
    {
      "createdAt": "2026-10-14T21:40:00+02:00",
      "mood": 4,
      "moodLabel": "Bien",
      "text": "Balade.",
      "analysisStatus": "tagged",
      "tags": [
        {
          "kind": "emotion",
          "label": "calme"
        }
      ],
      "topics": [
        "amis",
        "nature"
      ]
    }
  ]
}
''');
    });

    test('CA11 : topics vient juste après tags, et est le dernier champ', () {
      final first = entriesOf(
        build([
          entry(
            id: 1,
            createdAt: DateTime.utc(2026, 10, 14, 19, 40),
            topics: [Topic.sport],
          ),
        ]),
      ).single;

      expect(first.keys, [
        'createdAt',
        'mood',
        'moodLabel',
        'text',
        'analysisStatus',
        'tags',
        'topics',
      ]);
    });

    test('CA11 : sans sujet, topics est une liste vide, pour chaque '
        'entrée', () {
      final json = build([
        for (var i = 1; i <= 3; i++)
          entry(id: i, createdAt: DateTime.utc(2026, 10, 14, i)),
      ]);

      expect(
        [for (final e in entriesOf(json)) e['topics']],
        [isEmpty, isEmpty, isEmpty],
      );
      expect(json, contains('"topics": []'));
    });

    test('CA11 : les six sujets s\'écrivent par leur libellé, dans l\'ordre '
        'de la liste', () {
      final json = build([
        entry(
          id: 1,
          createdAt: DateTime.utc(2026, 10, 14, 19, 40),
          topics: Topic.values,
        ),
      ]);

      expect(entriesOf(json).single['topics'], [
        'sommeil',
        'travail',
        'amis',
        'famille',
        'sport',
        'nature',
      ]);
    });

    test('CA11 : des sujets donnés dans le désordre sont écrits dans l\'ordre '
        'de la liste', () {
      final json = build([
        entry(
          id: 1,
          createdAt: DateTime.utc(2026, 10, 14, 19, 40),
          topics: [Topic.nature, Topic.sommeil, Topic.famille],
        ),
      ]);

      expect(entriesOf(json).single['topics'], [
        'sommeil',
        'famille',
        'nature',
      ]);
    });

    test('CA11 : un même libellé comme sujet et comme étiquette reste dans '
        'les deux champs', () {
      final json = build([
        entry(
          id: 1,
          createdAt: DateTime.utc(2026, 10, 14, 19, 40),
          text: 'Journée de travail.',
          tags: const [Tag('travail', TagKind.theme)],
          topics: [Topic.travail],
        ),
      ]);

      final exported = entriesOf(json).single;
      expect(exported['tags'], [
        {'kind': 'theme', 'label': 'travail'},
      ]);
      expect(exported['topics'], ['travail']);
    });

    test('CA11 : les autres champs sont ceux de la version 1 : les sujets ne '
        'changent ni les étiquettes ni le reste', () {
      final withTopics = entriesOf(
        build([
          entry(
            id: 1,
            createdAt: DateTime.utc(2026, 10, 14, 19, 40),
            text: 'Texte.',
            tags: const [Tag('calme', TagKind.emotion)],
            topics: [Topic.amis],
          ),
        ]),
      ).single;
      final without = entriesOf(
        build([
          entry(
            id: 1,
            createdAt: DateTime.utc(2026, 10, 14, 19, 40),
            text: 'Texte.',
            tags: const [Tag('calme', TagKind.emotion)],
          ),
        ]),
      ).single;

      expect({...withTopics}..remove('topics'), {...without}..remove('topics'));
    });
  });

  group('export complet sur un dépôt factice', () {
    late WipeEnv env;

    setUp(() => env = WipeEnv());
    tearDown(() => env.dispose());

    test('CA11 : le fichier remis à la feuille de partage est en version 2 et '
        'porte les sujets de chaque entrée', () async {
      final entries = FakeEntryRepository();
      entries.seed(
        mood: 4,
        text: 'Balade au bord de l\'eau.',
        createdAt: DateTime(2026, 10, 14, 18, 30),
        topics: [Topic.nature, Topic.sport],
      );
      entries.seed(mood: 3, createdAt: DateTime(2026, 10, 14, 8, 15));
      final sheet = FakeShareSheet();
      final export = JournalExport(
        entries: entries,
        settings: FakeSettingsRepository(LowMoodSensitivity.normal),
        shareSheet: sheet,
        cacheFolder: Directory('${env.root.path}/cache'),
        clock: () => DateTime(2026, 10, 14, 21, 52, 7),
      );

      await export.run();

      final json = jsonDecode(sheet.shared.single.content) as Map;
      expect(json['formatVersion'], 2);
      final list = (json['entries'] as List).cast<Map>();
      // De la plus ancienne à la plus récente.
      expect(list.map((e) => e['topics']), [
        isEmpty,
        ['sport', 'nature'],
      ]);
    });
  });
}
