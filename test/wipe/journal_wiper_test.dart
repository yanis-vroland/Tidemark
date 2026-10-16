// Suppression totale, sans écran (spec 005, « Suppression totale » ; CA17, CA18, CA20
// à CA25) : ordre des étapes, erreurs, reprise, idempotence. Dossiers temporaires
// réels, trousseau et accès aux fichiers qui enregistrent leurs appels.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/wipe/journal_wiper.dart';

import '../support/wipe_harness.dart';

void main() {
  late WipeEnv env;

  setUp(() => env = WipeEnv());
  tearDown(() => env.dispose());

  /// Tout ce que la suppression doit avoir effacé (CA18).
  void expectEverythingWiped() {
    for (final path in const [
      'tidemark/journal.db',
      'tidemark/journal.db-wal',
      'tidemark/journal.db-shm',
      'tidemark/journal.db-journal',
      'tidemark/models',
      'cache/tidemark-export',
      'cache/share_plus',
      'tidemark/wipe-pending',
    ]) {
      expect(env.exists(path), isFalse, reason: '$path devrait être effacé');
    }
    expect(env.keyStore.stored, isNull);
  }

  group('IoWipeFiles (CA25 : une cible absente compte comme traitée)', () {
    const files = IoWipeFiles();

    test('CA25 : createFile crée le fichier vide et son dossier', () async {
      final file = File('${env.root.path}/a/b/marqueur');

      await files.createFile(file);

      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), 0);
    });

    test('CA25 : createFile réussit si le fichier existe déjà', () async {
      final file = File('${env.root.path}/marqueur');
      await files.createFile(file);

      await files.createFile(file);

      expect(file.existsSync(), isTrue);
    });

    test(
      'CA25 : deleteFile efface le fichier, et réussit s\'il est absent',
      () async {
        final file = File('${env.root.path}/x')..writeAsStringSync('x');

        await files.deleteFile(file);
        await files.deleteFile(file);

        expect(file.existsSync(), isFalse);
      },
    );

    test(
      'CA25 : deleteFile réussit même si le dossier parent est absent',
      () async {
        await files.deleteFile(File('${env.root.path}/absent/fichier'));
      },
    );

    test('CA25 : deleteDirectory efface le dossier et tout son contenu, et '
        'réussit s\'il est absent', () async {
      final dir = Directory('${env.root.path}/d/sous')
        ..createSync(recursive: true);
      File('${dir.path}/f').writeAsStringSync('x');
      final top = Directory('${env.root.path}/d');

      await files.deleteDirectory(top);
      await files.deleteDirectory(top);

      expect(top.existsSync(), isFalse);
    });
  });

  group('CA17 : les étapes, dans l\'ordre', () {
    test('CA17 : marqueur, fermeture de la base, fichiers de la base, clé, '
        'modèle, fichiers temporaires, effacement du marqueur', () async {
      env.populate();

      await env.wiper().wipe();

      expectWipeSteps(env.log, wipeStepGroups);
    });

    test('CA17 : le marqueur wipe-pending existe avant la fermeture de la base '
        'et pendant tout le reste', () async {
      env.populate();
      var markerAtClose = false;
      env.closeBody = () async {
        markerAtClose = env.exists('tidemark/wipe-pending');
      };

      await env.wiper().wipe();

      expect(markerAtClose, isTrue);
    });

    test('CA17 : le journal.db est effacé avant que la clé le soit', () async {
      env.populate();

      await env.wiper().wipe();

      expect(
        env.log.indexOf('deleteFile tidemark/journal.db'),
        lessThan(env.log.indexOf('deleteAll')),
      );
    });

    test('CA17 : la suppression ne dépend pas d\'une fermeture de la base si '
        'aucune n\'est fournie', () async {
      env.populate();
      final wiper = JournalWiper(
        folder: env.folder,
        cacheFolder: env.cache,
        keyStore: env.keyStore,
        files: env.files,
      );

      await wiper.wipe();

      expectEverythingWiped();
    });
  });

  group('CA18 : état après une suppression réussie', () {
    test('CA18 : la base et ses fichiers, la clé, le dossier du modèle (même '
        'partiel) et les dossiers temporaires n\'existent plus', () async {
      env.populate();

      await env.wiper().wipe();

      expectEverythingWiped();
      expect(env.wiper().isPending, isFalse);
    });

    test('CA18 : le marqueur d\'installation est conservé : l\'app reste '
        'installée', () async {
      env.populate();

      await env.wiper().wipe();

      expect(env.exists('tidemark/installed'), isTrue);
    });

    test('CA18 : la suppression n\'écrit jamais de clé', () async {
      env.populate();

      await env.wiper().wipe();

      expect(env.keyStore.writes, 0);
    });

    test('CA18 : le dossier du modèle est models/, celui du lot G', () async {
      expect(env.wiper().modelFolder.path, '${env.folder.path}/models');
    });
  });

  group('CA20 : le marqueur ne peut pas être écrit', () {
    test('CA20 : WipeNotStartedError, rien n\'est effacé, la base n\'est pas '
        'fermée', () async {
      env.populate();
      env.files.failOn.add('createFile tidemark/wipe-pending');

      await expectLater(
        env.wiper().wipe(),
        throwsA(isA<WipeNotStartedError>()),
      );

      expect(env.log, ['createFile tidemark/wipe-pending']);
      expect(env.closeCalls, 0);
      for (final path in const [
        'tidemark/journal.db',
        'tidemark/journal.db-wal',
        'tidemark/journal.db-shm',
        'tidemark/journal.db-journal',
        'tidemark/models/modele.gguf.part',
        'cache/tidemark-export/reste.json',
        'cache/share_plus/copie.json',
      ]) {
        expect(env.exists(path), isTrue, reason: '$path ne devait pas bouger');
      }
      expect(env.keyStore.stored, 'ancienne-cle');
      expect(env.wiper().isPending, isFalse);
    });

    test(
      'CA20 : une fois l\'écriture possible, un nouvel essai efface tout',
      () async {
        env.populate();
        env.files.failOn.add('createFile tidemark/wipe-pending');
        await expectLater(
          env.wiper().wipe(),
          throwsA(isA<WipeNotStartedError>()),
        );
        env.repair();

        await env.wiper().wipe();

        expectEverythingWiped();
      },
    );
  });

  group('CA21 et CA24 : une étape échoue', () {
    for (final failing in wipeFailurePoints) {
      test('CA21 : échec à « $failing », les étapes suivantes n\'ont pas lieu '
          'et wipe-pending reste', () async {
        env.populate();
        env.failAt(failing);

        await expectLater(
          env.wiper().wipe(),
          throwsA(isA<WipeIncompleteError>()),
        );

        expectWipeStoppedAt(env.log, failing);
        expect(env.wiper().isPending, isTrue);
        expect(env.exists('tidemark/installed'), isTrue);
      });

      test('CA24 : échec à « $failing », la clé existe encore si journal.db '
          'existe encore, et aucune clé n\'est créée', () async {
        env.populate();
        env.failAt(failing);

        await expectLater(
          env.wiper().wipe(),
          throwsA(isA<WipeIncompleteError>()),
        );

        if (env.exists('tidemark/journal.db')) {
          expect(
            env.keyStore.stored,
            isNotNull,
            reason: 'journal.db existe : sa clé ne doit pas avoir été effacée',
          );
        }
        expect(env.keyStore.writes, 0);
      });

      test('CA21 : après un échec à « $failing », la reprise rejoue les '
          'étapes et finit la suppression', () async {
        env.populate();
        env.failAt(failing);
        await expectLater(
          env.wiper().wipe(),
          throwsA(isA<WipeIncompleteError>()),
        );
        env.repair();
        env.log.clear();

        await env.wiper().resume();

        expectEverythingWiped();
        expect(env.exists('tidemark/installed'), isTrue);
        expect(
          env.log,
          isNot(contains('createFile tidemark/wipe-pending')),
          reason: 'la reprise ne réécrit pas le marqueur',
        );
      });
    }

    test('CA24 : la clé survit tant que journal.db existe, à chaque échec '
        'successif d\'une même suppression', () async {
      env.populate();
      env.failAt('deleteFile tidemark/journal.db');
      final wiper = env.wiper();

      for (var attempt = 0; attempt < 3; attempt++) {
        await expectLater(
          attempt == 0 ? wiper.wipe() : wiper.resume(),
          throwsA(isA<WipeIncompleteError>()),
        );
        expect(env.exists('tidemark/journal.db'), isTrue);
        expect(env.keyStore.stored, 'ancienne-cle');
      }
    });

    test('CA21 : la fermeture de la base n\'est pas rejouée une fois '
        'réussie', () async {
      env.populate();
      env.failAt('deleteAll');
      final wiper = env.wiper();
      await expectLater(wiper.wipe(), throwsA(isA<WipeIncompleteError>()));
      expect(env.closeCalls, 1);
      env.repair();

      await wiper.resume();

      expect(env.closeCalls, 1);
    });

    test(
      'CA21 : la fermeture de la base est retentée tant qu\'elle échoue',
      () async {
        env.populate();
        env.failAt('closeJournal');
        final wiper = env.wiper();
        await expectLater(wiper.wipe(), throwsA(isA<WipeIncompleteError>()));
        env.repair();

        await wiper.resume();

        expect(env.closeCalls, 2);
        expectEverythingWiped();
      },
    );
  });

  group('CA22 : reprise d\'une suppression interrompue', () {
    test('CA22 : avec wipe-pending déjà là, resume rejoue les étapes 2 à 6, '
        'sans réécrire le marqueur', () async {
      env.populate();
      env.file('tidemark/wipe-pending').writeAsStringSync('');
      expect(env.wiper().isPending, isTrue);

      await env.wiper().resume();

      expectWipeSteps(env.log, wipeStepGroups.skip(1).toList());
      expectEverythingWiped();
    });

    test('CA22 : la reprise après une interruption à mi-chemin (base et clé '
        'déjà effacées) finit le travail', () async {
      env.populate();
      env.file('tidemark/wipe-pending').writeAsStringSync('');
      for (final name in const [
        'journal.db',
        'journal.db-wal',
        'journal.db-shm',
        'journal.db-journal',
      ]) {
        env.file('tidemark/$name').deleteSync();
      }
      env.keyStore.stored = null;

      await env.wiper().resume();

      expectEverythingWiped();
    });

    test('isPending : faux sans marqueur, vrai avec', () {
      expect(env.wiper().isPending, isFalse);

      env.folder.createSync(recursive: true);
      env.file('tidemark/wipe-pending').writeAsStringSync('');

      expect(env.wiper().isPending, isTrue);
    });
  });

  group('CA25 : une cible déjà absente compte comme effacée', () {
    test('CA25 : rien n\'existe (ni base, ni clé, ni modèle, ni dossier '
        'temporaire, ni dossier de l\'app) : la suppression réussit', () async {
      await env.wiper().wipe();

      expectEverythingWiped();
    });

    final absent = <String, void Function(WipeEnv env)>{
      'les fichiers de la base (clé introuvable)': (env) {
        for (final name in const [
          'journal.db',
          'journal.db-wal',
          'journal.db-shm',
          'journal.db-journal',
        ]) {
          env.file('tidemark/$name').deleteSync();
        }
      },
      'la clé': (env) => env.keyStore.stored = null,
      'le modèle (jamais téléchargé)': (env) =>
          Directory('${env.folder.path}/models').deleteSync(recursive: true),
      'le dossier temporaire d\'export': (env) =>
          Directory('${env.cache.path}/tidemark-export')
              .deleteSync(recursive: true),
      'la copie de share_plus': (env) =>
          Directory('${env.cache.path}/share_plus').deleteSync(recursive: true),
    };

    for (final MapEntry(key: name, value: remove) in absent.entries) {
      test('CA25 : $name déjà absent, l\'étape réussit', () async {
        env.populate();
        remove(env);

        await env.wiper().wipe();

        expectEverythingWiped();
        expectWipeSteps(env.log, wipeStepGroups);
      });
    }
  });
}
