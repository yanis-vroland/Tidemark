// Export du journal, sans écran (spec 005, règles 1 et 2 ; CA3, CA4, CA9, CA10, CA11,
// CA13) : lecture, écriture du fichier, feuille de partage factice, nettoyage.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/distress/distress_detector.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/export/journal_export.dart';
import 'package:tidemark/export/journal_exporter.dart';

import '../support/fake_entry_repository.dart';
import '../support/fake_settings_repository.dart';
import '../support/fake_share_sheet.dart';
import '../support/wipe_harness.dart';

Future<void> waitFor(bool Function() condition) async {
  final stop = DateTime.now().add(const Duration(seconds: 3));
  while (!condition()) {
    if (DateTime.now().isAfter(stop)) fail('condition jamais remplie');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late WipeEnv env;
  late FakeEntryRepository entries;
  late FakeSettingsRepository settings;
  late FakeShareSheet sheet;
  late DateTime Function() clock;

  JournalExport export([Directory? cache]) => JournalExport(
    entries: entries,
    settings: settings,
    shareSheet: sheet,
    cacheFolder: cache ?? env.cache,
    clock: () => clock(),
  );

  File exportFile(String name) =>
      File('${env.cache.path}/tidemark-export/$name');

  void leftover(String folder, String name) {
    Directory('${env.cache.path}/$folder').createSync(recursive: true);
    File('${env.cache.path}/$folder/$name').writeAsStringSync('{"reste": 1}');
  }

  setUp(() {
    env = WipeEnv();
    entries = FakeEntryRepository();
    settings = FakeSettingsRepository(LowMoodSensitivity.high);
    sheet = FakeShareSheet();
    clock = () => DateTime(2026, 10, 14, 21, 52, 7);
    entries.seed(
      mood: 4,
      text: 'Balade au bord de l\'eau.',
      createdAt: DateTime(2026, 10, 14, 18, 30),
    );
    entries.seed(
      mood: 2,
      text: 'Encore une nuit trop courte.\nJe repousse tout à demain.',
      createdAt: DateTime(2026, 10, 13, 22, 5),
    );
    entries.seed(mood: 3, createdAt: DateTime(2026, 10, 14, 8, 15));
  });
  tearDown(() => env.dispose());

  group('CA3 : ouverture de la feuille de partage', () {
    test(
      'CA3 : un seul appel, avec un fichier du dossier temporaire d\'export '
      'nommé d\'après le début de l\'export, de type application/json',
      () async {
        await export().run();

        expect(sheet.shared, hasLength(1));
        final shared = sheet.shared.single;
        expect(
          shared.path,
          '${env.cache.path}/tidemark-export/'
          'tidemark-export-2026-10-14-2152.json',
        );
        expect(shared.mimeType, 'application/json');
      },
    );

    test('CA3 : le nom du fichier est celui du début de l\'export, même si '
        'le jour change pendant l\'export', () async {
      final times = [
        DateTime(2026, 10, 14, 23, 59, 58),
        DateTime(2026, 10, 15, 0, 0, 3),
        DateTime(2026, 10, 15, 0, 0, 4),
      ];
      var next = 0;
      clock = () => times[next < times.length ? next++ : times.length - 1];

      await export().run();

      expect(sheet.shared.single.name, 'tidemark-export-2026-10-14-2359.json');
    });

    test('CA3 : deux exports dans la même minute donnent le même nom, et le '
        'second réussit', () async {
      await export().run();
      await export().run();

      expect(sheet.shared, hasLength(2));
      expect(sheet.shared[1].name, sheet.shared[0].name);
      expect(sheet.shared[1].bytes, sheet.shared[0].bytes);
    });
  });

  group('CA4 : contenu du fichier remis à la feuille de partage', () {
    test('CA4 : toutes les entrées, de la plus ancienne à la plus récente, '
        'et le degré de sensibilité', () async {
      await export().run();

      final json = jsonDecode(sheet.shared.single.content) as Map;
      expect(json['formatVersion'], 2);
      expect(json['app'], 'Tidemark');
      expect((json['settings'] as Map)['lowMoodSensitivity'], 'high');
      expect(
        [for (final e in json['entries'] as List) (e as Map)['text']],
        [
          'Encore une nuit trop courte.\nJe repousse tout à demain.',
          null,
          'Balade au bord de l\'eau.',
        ],
      );
    });

    test('CA4 : le fichier est celui que construit JournalExporter pour ces '
        'entrées, ce degré et le début de l\'export', () async {
      await export().run();

      expect(
        sheet.shared.single.content,
        const JournalExporter().buildExport(
          entries: await entries.allEntriesWithTags(),
          sensitivity: LowMoodSensitivity.high,
          exportedAt: DateTime(2026, 10, 14, 21, 52, 7),
        ),
      );
    });

    test('CA4 : le degré écrit suit le réglage de la personne', () async {
      settings.value = LowMoodSensitivity.low;

      await export().run();

      final json = jsonDecode(sheet.shared.single.content) as Map;
      expect((json['settings'] as Map)['lowMoodSensitivity'], 'low');
    });

    test('CA4 : UTF-8 sans BOM, terminé par un saut de ligne', () async {
      await export().run();

      final bytes = sheet.shared.single.bytes!;
      expect(bytes.take(3), isNot([0xEF, 0xBB, 0xBF]));
      expect(bytes.last, 0x0A);
      expect(utf8.decode(bytes), sheet.shared.single.content);
    });

    test(
      'CA6 : les entrées sans texte et en détresse sont exportées',
      () async {
        entries.seed(
          mood: 1,
          text: 'Je n\'y arrive plus.',
          createdAt: DateTime(2026, 10, 14, 20),
          status: AnalysisStatus.skipped,
        );

        await export().run();

        final list =
            ((jsonDecode(sheet.shared.single.content) as Map)['entries']
                    as List)
                .cast<Map>();
        expect(list, hasLength(4));
        expect(
          list.where((e) => e['analysisStatus'] == 'skipped'),
          hasLength(2),
        );
      },
    );
  });

  group('CA9 : après la feuille de partage', () {
    test('CA9 : le fichier existe pendant que la feuille est ouverte, puis '
        'est effacé quand elle se ferme', () async {
      final open = Completer<void>();
      sheet.hold = open;
      var finished = false;

      final done = export().run().then((_) => finished = true);
      await waitFor(() => sheet.shared.isNotEmpty);

      expect(finished, isFalse, reason: 'la feuille est encore ouverte');
      expect(
        exportFile('tidemark-export-2026-10-14-2152.json').existsSync(),
        isTrue,
      );

      open.complete();
      await done;

      expect(finished, isTrue);
      expect(env.exportLeftovers(), isEmpty);
    });

    test('CA9 : feuille fermée sans partage (annulée), le fichier est '
        'effacé aussi et run réussit', () async {
      await export().run();

      expect(sheet.shared, hasLength(1));
      expect(env.exportLeftovers(), isEmpty);
    });

    test('CA9 : la copie que share_plus garde dans share_plus/ reste jusqu\'au '
        'démarrage ou à l\'export suivant (Android)', () async {
      sheet.onShare = (file) =>
          leftover('share_plus', file.path.split('/').last);

      await export().run();

      expect(env.exportLeftovers(), [
        'share_plus/tidemark-export-2026-10-14-2152.json',
      ]);
    });
  });

  group('CA10 : fichiers restés dans les dossiers temporaires', () {
    test('CA10 : un nouvel export vide les deux dossiers avant d\'écrire son '
        'fichier', () async {
      leftover('tidemark-export', 'ancien.json');
      leftover('share_plus', 'copie.json');
      List<String>? duringShare;
      sheet.onShare = (_) => duringShare = env.exportLeftovers()..sort();

      await export().run();

      expect(duringShare, [
        'tidemark-export/tidemark-export-2026-10-14-2152.json',
      ]);
      expect(env.exportLeftovers(), isEmpty);
    });

    test('CA10 : purgeExportTemporaryFiles vide les deux dossiers, y compris '
        'leurs sous-dossiers', () async {
      leftover('tidemark-export', 'a.json');
      leftover('share_plus', 'b.json');
      Directory('${env.cache.path}/share_plus/sous/dossier')
          .createSync(recursive: true);
      File('${env.cache.path}/share_plus/sous/dossier/c.json')
          .writeAsStringSync('{}');

      await purgeExportTemporaryFiles(env.cache);

      expect(env.exportLeftovers(), isEmpty);
    });

    test('CA10 : la purge ne touche à rien d\'autre dans le cache', () async {
      leftover('tidemark-export', 'a.json');
      leftover('autre-dossier', 'garde.txt');
      File('${env.cache.path}/garde-aussi.txt').writeAsStringSync('x');

      await purgeExportTemporaryFiles(env.cache);

      expect(
        File('${env.cache.path}/autre-dossier/garde.txt').existsSync(),
        isTrue,
      );
      expect(File('${env.cache.path}/garde-aussi.txt').existsSync(), isTrue);
    });

    test(
      'CA25 : la purge réussit quand les dossiers n\'existent pas',
      () async {
        expect(env.cache.existsSync(), isFalse);

        await purgeExportTemporaryFiles(env.cache);

        expect(env.exportLeftovers(), isEmpty);
      },
    );

    test(
      'CA25 : la purge réussit quand un seul des deux dossiers existe',
      () async {
        leftover('share_plus', 'copie.json');

        await purgeExportTemporaryFiles(env.cache);

        expect(env.exportLeftovers(), isEmpty);
      },
    );

    test('les dossiers temporaires sont tidemark-export/ et share_plus/ du '
        'cache', () {
      expect(exportFolderName, 'tidemark-export');
      expect(sharePlusFolderName, 'share_plus');
      expect(exportMimeType, 'application/json');
      expect(
        [for (final d in exportTemporaryFolders(env.cache)) d.path],
        ['${env.cache.path}/tidemark-export', '${env.cache.path}/share_plus'],
      );
    });
  });

  group('CA11 : erreurs', () {
    Future<void> expectFailureWithoutLeftovers(
      Future<void> Function() act,
    ) async {
      leftover('tidemark-export', 'ancien.json');
      leftover('share_plus', 'copie.json');

      await expectLater(act(), throwsA(isA<ExportFailure>()));

      expect(env.exportLeftovers(), isEmpty);
    }

    test('CA11 : erreur de lecture des entrées, ExportFailure, la feuille '
        'n\'est pas ouverte, aucun fichier ne reste', () async {
      entries.allEntriesError = StateError('base illisible');

      await expectFailureWithoutLeftovers(() => export().run());

      expect(sheet.shared, isEmpty);
    });

    test('CA11 : erreur de lecture du réglage, ExportFailure, la feuille '
        'n\'est pas ouverte, aucun fichier ne reste', () async {
      settings.readError = StateError('réglage illisible');

      await expectFailureWithoutLeftovers(() => export().run());

      expect(sheet.shared, isEmpty);
    });

    test('CA11 : erreur d\'écriture du fichier, ExportFailure, la feuille '
        'n\'est pas ouverte', () async {
      // Le cache est « sous » un fichier ordinaire : aucun dossier ne peut y être
      // créé.
      env.root.createSync(recursive: true);
      final blocker = File('${env.root.path}/bloque')..writeAsStringSync('x');
      final impossible = Directory('${blocker.path}/cache');

      await expectLater(
        export(impossible).run(),
        throwsA(isA<ExportFailure>()),
      );

      expect(sheet.shared, isEmpty);
    });

    test('CA11 : ouverture de la feuille de partage en échec, ExportFailure, '
        'le fichier est effacé, aucun fichier ne reste', () async {
      sheet.error = StateError('aucune feuille de partage');
      sheet.onShare = (file) => leftover('share_plus', 'copie-partielle.json');

      await expectFailureWithoutLeftovers(() => export().run());

      expect(sheet.shared, hasLength(1));
    });

    test('CA11 : après une erreur, un nouvel essai réussit', () async {
      entries.allEntriesError = StateError('base illisible');
      await expectLater(export().run(), throwsA(isA<ExportFailure>()));
      entries.allEntriesError = null;

      await export().run();

      expect(sheet.shared, hasLength(1));
      expect(env.exportLeftovers(), isEmpty);
    });
  });

  group('CA13 : jamais d\'export de soi-même', () {
    test('CA13 : créer l\'export n\'ouvre pas la feuille de partage et '
        'n\'écrit aucun fichier', () async {
      export();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(sheet.shared, isEmpty);
      expect(env.cache.existsSync(), isFalse);
    });

    test('CA13 : un appel à run ouvre la feuille une seule fois, avec ce '
        'seul fichier', () async {
      await export().run();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(sheet.shared, hasLength(1));
    });
  });
}
