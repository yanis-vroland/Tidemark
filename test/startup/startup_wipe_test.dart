// Démarrage avec la spec 005 (CA10, CA22, CA23, CA26, CA28 à CA32) : purge des
// fichiers temporaires, reprise d'une suppression interrompue, marqueur
// d'installation, clé introuvable. Vraie base chiffrée dans un dossier temporaire,
// trousseau en mémoire, aucun écran.
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/distress/distress_detector.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/main.dart';
import 'package:tidemark/storage/app_database.dart';

import '../support/fake_share_sheet.dart';
import '../support/wipe_harness.dart';

void main() {
  late WipeEnv env;
  late FakeShareSheet sheet;
  final opened = <Widget>[];

  setUp(() {
    env = WipeEnv();
    sheet = FakeShareSheet();
  });

  tearDown(() async {
    for (final app in opened) {
      if (app is TidemarkApp) {
        try {
          await (app.repository as DriftEntryRepository).db.close();
        } catch (_) {}
      }
    }
    opened.clear();
    env.dispose();
  });

  Future<Widget> start({bool wiped = false}) async {
    final app = await startApp(
      storage: env.storage(),
      shareSheet: sheet,
      wiped: wiped,
    );
    opened.add(app);
    return app;
  }

  /// Un vrai journal de [count] entrées sans texte (aucune analyse), au degré
  /// « Haute » : la base est fermée ensuite. Rend la clé de la base.
  Future<String> seedJournal({int count = 2}) async {
    final journal = await openJournal(
      folder: env.folder,
      keyStore: env.keyStore,
    );
    for (var i = 0; i < count; i++) {
      await journal.entries.addEntry(mood: 3);
    }
    await journal.settings.setLowMoodSensitivity(LowMoodSensitivity.high);
    await (journal.entries as DriftEntryRepository).db.close();
    env.log.clear();
    return env.keyStore.stored!;
  }

  /// Marqueur d'installation, modèle (même partiel) et fichiers temporaires.
  void writeAuxiliaryFiles({bool installed = true}) {
    env.folder.createSync(recursive: true);
    if (installed) File('${env.folder.path}/installed').writeAsStringSync('');
    Directory('${env.folder.path}/models').createSync(recursive: true);
    File('${env.folder.path}/models/modele.gguf.part').writeAsStringSync('xx');
    Directory('${env.cache.path}/tidemark-export').createSync(recursive: true);
    File('${env.cache.path}/tidemark-export/reste.json')
        .writeAsStringSync('{}');
    Directory('${env.cache.path}/share_plus').createSync(recursive: true);
    File('${env.cache.path}/share_plus/copie.json').writeAsStringSync('{}');
  }

  List<int> databaseBytes() =>
      File('${env.folder.path}/journal.db').readAsBytesSync();

  Future<List<Entry>> entriesOf(Widget app) =>
      (app as TidemarkApp).repository.watchEntries().first;

  group('démarrage normal', () {
    test('CA13 : une app ouverte a l\'export et la suppression branchés, '
        'et la feuille de partage n\'est pas ouverte', () async {
      final app = await start();

      expect(app, isA<TidemarkApp>());
      final data = (app as TidemarkApp).data;
      expect(data, isNotNull);
      expect(identical(data!.export.shareSheet, sheet), isTrue);
      expect(data.wiper.folder.path, env.folder.path);
      expect(data.wiper.cacheFolder.path, env.cache.path);
      expect(sheet.shared, isEmpty);
      expect(app.wiped, isFalse);
    });

    test(
      'CA18 : wiped: true rend une liste qui affichera le message de fin',
      () async {
        final app = await start(wiped: true);

        expect(app, isA<TidemarkApp>());
        expect((app as TidemarkApp).wiped, isTrue);
      },
    );

    test('CA17 : la suppression branchée sur l\'app ouverte ferme la vraie '
        'base et efface tout', () async {
      await seedJournal();
      writeAuxiliaryFiles();
      final app = await start() as TidemarkApp;
      env.log.clear();

      await app.data!.wiper.wipe();

      expect(env.exists('tidemark/journal.db'), isFalse);
      expect(env.exists('tidemark/models'), isFalse);
      expect(env.exists('tidemark/wipe-pending'), isFalse);
      expect(env.exists('cache/tidemark-export'), isFalse);
      expect(env.exists('cache/share_plus'), isFalse);
      expect(env.keyStore.stored, isNull);
      expect(
        env.log.indexOf('deleteFile tidemark/journal.db'),
        lessThan(env.log.indexOf('deleteAll')),
      );
    });
  });

  group('CA10 : purge des fichiers temporaires au démarrage', () {
    test('CA10 : les dossiers temporaires d\'export sont vidés au '
        'démarrage', () async {
      writeAuxiliaryFiles();

      await start();

      expect(env.exportLeftovers(), isEmpty);
      expect(
        File('${env.folder.path}/models/modele.gguf.part').existsSync(),
        isTrue,
      );
    });

    test(
      'CA10 : une purge en échec n\'empêche pas l\'app de s\'ouvrir',
      () async {
        writeAuxiliaryFiles();
        final locked = '${env.cache.path}/tidemark-export';
        await Process.run('chmod', ['555', locked]);
        try {
          final app = await start();

          expect(app, isA<TidemarkApp>());
        } finally {
          await Process.run('chmod', ['755', locked]);
        }
      },
    );
  });

  group('CA22 : reprise d\'une suppression interrompue', () {
    final interruptions = <String, void Function(WipeEnv env)>{
      'juste après l\'écriture du marqueur': (env) {},
      'après l\'effacement de la base (clé encore là)': (env) {
        for (final name in const [
          'journal.db',
          'journal.db-wal',
          'journal.db-shm',
          'journal.db-journal',
        ]) {
          final file = File('${env.folder.path}/$name');
          if (file.existsSync()) file.deleteSync();
        }
      },
      'après l\'effacement de la base et de la clé': (env) {
        for (final name in const [
          'journal.db',
          'journal.db-wal',
          'journal.db-shm',
          'journal.db-journal',
        ]) {
          final file = File('${env.folder.path}/$name');
          if (file.existsSync()) file.deleteSync();
        }
        env.keyStore.stored = null;
      },
    };

    for (final MapEntry(key: name, value: interrupt) in interruptions.entries) {
      test('CA22 : app fermée $name : le démarrage finit la suppression, '
          'puis rend une liste vide avec le message de fin', () async {
        final oldKey = await seedJournal();
        writeAuxiliaryFiles();
        File('${env.folder.path}/wipe-pending').writeAsStringSync('');
        interrupt(env);

        final app = await start();

        expect(app, isA<TidemarkApp>());
        expect((app as TidemarkApp).wiped, isTrue);
        expect(env.exists('tidemark/wipe-pending'), isFalse);
        expect(env.exists('tidemark/models'), isFalse);
        expect(env.exportLeftovers(), isEmpty);
        expect(env.exists('tidemark/installed'), isTrue);
        expect(await entriesOf(app), isEmpty);
        expect(env.keyStore.stored, isNotNull);
        expect(env.keyStore.stored, isNot(oldKey));
        // Le degré de sensibilité est revenu à « Normale ».
        expect(
          await app.settings.watchLowMoodSensitivity().first,
          LowMoodSensitivity.normal,
        );
      });
    }

    test(
      'CA22 : la clé est effacée avant la création de la nouvelle',
      () async {
        await seedJournal();
        File('${env.folder.path}/wipe-pending').writeAsStringSync('');

        await start();

        expect(env.log, contains('deleteAll'));
        expect(env.log, contains('writeKey'));
        expect(
          env.log.indexOf('deleteAll'),
          lessThan(env.log.indexOf('writeKey')),
        );
      },
    );

    test('CA22 : la reprise a lieu avant l\'ouverture : aucune ancienne entrée '
        'n\'est lisible', () async {
      await seedJournal(count: 3);
      File('${env.folder.path}/wipe-pending').writeAsStringSync('');

      final app = await start();

      expect(await entriesOf(app), isEmpty);
    });
  });

  group('CA23 : reprise au démarrage en échec', () {
    for (final failing in wipeFailurePoints.where(
      (step) => step != 'closeJournal',
    )) {
      test('CA23 : échec à « $failing » : écran « suppression non terminée », '
          'base non ouverte, aucune clé créée', () async {
        final oldKey = await seedJournal();
        writeAuxiliaryFiles();
        File('${env.folder.path}/wipe-pending').writeAsStringSync('');
        final writesBefore = env.keyStore.writes;
        final dbBefore = databaseBytes();
        env.failAt(failing);

        final app = await start();

        expect(app, isA<StartupErrorApp>());
        final error = app as StartupErrorApp;
        expect(error.wipeIncomplete, isTrue);
        expect(error.keyMissing, isFalse);
        expect(env.keyStore.writes, writesBefore, reason: 'aucune clé créée');
        expect(env.log, isNot(contains('writeKey')));
        expect(env.exists('tidemark/wipe-pending'), isTrue);
        // Une base n'existe que si l'échec précède son effacement : c'est l'ancienne,
        // ni ouverte ni modifiée, et sa clé existe encore. Sinon, aucune base neuve.
        final dbStep = wipeFailurePoints.indexOf(
          'deleteFile tidemark/journal.db',
        );
        final dbStillThere = wipeFailurePoints.indexOf(failing) <= dbStep;
        expect(env.exists('tidemark/journal.db'), dbStillThere);
        if (dbStillThere) {
          expect(databaseBytes(), dbBefore);
          expect(env.keyStore.stored, oldKey);
        }
      });
    }

    test('CA23 : une fois la panne réparée, le démarrage suivant finit la '
        'suppression', () async {
      await seedJournal();
      writeAuxiliaryFiles();
      File('${env.folder.path}/wipe-pending').writeAsStringSync('');
      env.failAt('deleteAll');
      expect(await start(), isA<StartupErrorApp>());
      env.repair();

      final app = await start();

      expect(app, isA<TidemarkApp>());
      expect((app as TidemarkApp).wiped, isTrue);
      expect(env.exists('tidemark/wipe-pending'), isFalse);
    });
  });

  group('CA26 et CA28 : clé introuvable', () {
    test('CA26 : base présente, clé absente : écran « clé introuvable » avec '
        'la suppression proposée', () async {
      await seedJournal();
      env.keyStore.stored = null;
      writeAuxiliaryFiles();

      final app = await start();

      expect(app, isA<StartupErrorApp>());
      final error = app as StartupErrorApp;
      expect(error.keyMissing, isTrue);
      expect(error.wipeIncomplete, isFalse);
      expect(error.wiper, isNotNull);
    });

    test('CA28 : l\'app n\'efface rien d\'elle-même : base, modèle et '
        'marqueur intacts, aucune clé créée', () async {
      await seedJournal();
      env.keyStore.stored = null;
      writeAuxiliaryFiles();
      final dbBefore = databaseBytes();
      final writesBefore = env.keyStore.writes;

      await start();

      expect(databaseBytes(), dbBefore);
      expect(env.exists('tidemark/models/modele.gguf.part'), isTrue);
      expect(env.exists('tidemark/wipe-pending'), isFalse);
      expect(env.log, isNot(contains('deleteAll')));
      expect(env.keyStore.writes, writesBefore);
      expect(env.keyStore.stored, isNull);
    });

    test('CA28 : même sans marqueur d\'installation (installation antérieure), '
        'rien n\'est effacé', () async {
      await seedJournal();
      env.keyStore.stored = null;
      writeAuxiliaryFiles(installed: false);
      final dbBefore = databaseBytes();

      final app = await start();

      expect(app, isA<StartupErrorApp>());
      expect((app as StartupErrorApp).keyMissing, isTrue);
      expect(databaseBytes(), dbBefore);
      expect(env.log, isNot(contains('deleteAll')));
    });

    test('CA26 : pour toute autre cause (base illisible), ni suppression ni '
        'effacement de la clé', () async {
      env.folder.createSync(recursive: true);
      File('${env.folder.path}/journal.db').writeAsStringSync('pas une base');
      File('${env.folder.path}/installed').writeAsStringSync('');
      env.keyStore.stored = 'ab' * 32;

      final app = await start();

      expect(app, isA<StartupErrorApp>());
      expect((app as StartupErrorApp).keyMissing, isFalse);
      expect(app.wipeIncomplete, isFalse);
      expect(env.keyStore.stored, 'ab' * 32);
      expect(env.log, isNot(contains('deleteAll')));
      expect(
        File('${env.folder.path}/journal.db').readAsStringSync(),
        'pas une base',
      );
    });
  });

  group('marqueur d\'installation au démarrage', () {
    test('CA29 : ni marqueur ni base, une clé restée : elle est effacée, le '
        'marqueur est créé, la base neuve a une clé neuve', () async {
      final leftover = 'cd' * 32;
      env.keyStore.stored = leftover;

      final app = await start();

      expect(app, isA<TidemarkApp>());
      expect(env.exists('tidemark/installed'), isTrue);
      expect(env.exists('tidemark/journal.db'), isTrue);
      expect(env.keyStore.stored, isNotNull);
      expect(env.keyStore.stored, isNot(leftover));
      expect(
        env.log.indexOf('deleteAll'),
        lessThan(env.log.indexOf('writeKey')),
      );
    });

    test('CA30 : base présente sans marqueur : aucune clé effacée, marqueur '
        'créé, le journal s\'ouvre avec ses entrées', () async {
      final key = await seedJournal(count: 3);

      final app = await start();

      expect(app, isA<TidemarkApp>());
      expect(env.log, isNot(contains('deleteAll')));
      expect(env.keyStore.stored, key);
      expect(env.exists('tidemark/installed'), isTrue);
      expect(await entriesOf(app), hasLength(3));
    });

    test('CA31 : marqueur présent : aucune clé n\'est effacée', () async {
      final key = await seedJournal();
      writeAuxiliaryFiles();

      final app = await start();

      expect(app, isA<TidemarkApp>());
      expect(env.log, isNot(contains('deleteAll')));
      expect(env.keyStore.stored, key);
      expect(await entriesOf(app), hasLength(2));
    });

    test('CA31 : marqueur présent sans base, la clé du trousseau est gardée '
        'et sert à la base neuve', () async {
      env.folder.createSync(recursive: true);
      File('${env.folder.path}/installed').writeAsStringSync('');
      env.keyStore.stored = 'ef' * 32;

      final app = await start();

      expect(app, isA<TidemarkApp>());
      expect(env.log, isNot(contains('deleteAll')));
      expect(env.keyStore.stored, 'ef' * 32);
    });

    test('CA32 : l\'effacement de la clé restante échoue : l\'app s\'ouvre '
        'normalement, sans marqueur', () async {
      env.keyStore.stored = 'cd' * 32;
      env.keyStore.deleteAllError = StateError('trousseau inaccessible');

      final app = await start();

      expect(app, isA<TidemarkApp>());
      expect((app as TidemarkApp).wiped, isFalse);
      expect(env.exists('tidemark/installed'), isFalse);
    });

    test(
      'CA32 : au démarrage suivant, le marqueur est retenté et créé',
      () async {
        env.keyStore.stored = 'cd' * 32;
        env.keyStore.deleteAllError = StateError('trousseau inaccessible');
        final first = await start() as TidemarkApp;
        await (first.repository as DriftEntryRepository).db.close();
        env.repair();

        final second = await start();

        expect(second, isA<TidemarkApp>());
        expect(env.exists('tidemark/installed'), isTrue);
      },
    );

    test(
      'CA32 : l\'écriture du marqueur échoue : l\'app s\'ouvre normalement',
      () async {
        env.files.failOn.add('createFile tidemark/installed');

        final app = await start();

        expect(app, isA<TidemarkApp>());
        expect(env.exists('tidemark/installed'), isFalse);
      },
    );

    test(
      'CA32 : au démarrage suivant, l\'écriture du marqueur est retentée',
      () async {
        env.files.failOn.add('createFile tidemark/installed');
        final first = await start() as TidemarkApp;
        await (first.repository as DriftEntryRepository).db.close();
        env.repair();

        await start();

        expect(env.exists('tidemark/installed'), isTrue);
      },
    );
  });
}
