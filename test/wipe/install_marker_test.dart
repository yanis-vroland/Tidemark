// Marqueur d'installation (spec 005, « Marqueur d'installation » ; CA29 à CA32,
// ADR-002, RM45) : table de décision, sans ouvrir de base.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/wipe/install_marker.dart';

import '../support/wipe_harness.dart';

void main() {
  late WipeEnv env;

  setUp(() => env = WipeEnv());
  tearDown(() => env.dispose());

  Future<void> check() => checkInstallMarker(
    folder: env.folder,
    keyStore: env.keyStore,
    files: env.files,
  );

  void writeDatabase() {
    env.folder.createSync(recursive: true);
    File('${env.folder.path}/journal.db').writeAsStringSync('base');
  }

  void writeMarker() {
    env.folder.createSync(recursive: true);
    File('${env.folder.path}/installed').writeAsStringSync('');
  }

  group('CA31 : marqueur présent', () {
    test('CA31 : sans base, aucune clé n\'est effacée et rien n\'est '
        'écrit', () async {
      writeMarker();
      env.keyStore.stored = 'cle';

      await check();

      expect(env.log, isEmpty);
      expect(env.keyStore.stored, 'cle');
    });

    test('CA31 : avec une base, aucune clé n\'est effacée et rien n\'est '
        'écrit', () async {
      writeMarker();
      writeDatabase();
      env.keyStore.stored = 'cle';

      await check();

      expect(env.log, isEmpty);
      expect(env.keyStore.stored, 'cle');
    });
  });

  group('CA29 : nouvelle installation (ni marqueur, ni base)', () {
    test('CA29 : la clé restée dans le trousseau est effacée, puis le '
        'marqueur est créé', () async {
      env.folder.createSync(recursive: true);
      env.keyStore.stored = 'cle-restee';

      await check();

      expect(env.log, ['deleteAll', 'createFile tidemark/installed']);
      expect(env.keyStore.stored, isNull);
      expect(env.exists('tidemark/installed'), isTrue);
    });

    test('CA29 : le dossier de l\'app n\'existe pas encore : il est créé avec '
        'le marqueur', () async {
      env.keyStore.stored = 'cle-restee';
      expect(env.folder.existsSync(), isFalse);

      await check();

      expect(env.keyStore.stored, isNull);
      expect(env.exists('tidemark/installed'), isTrue);
    });

    test('CA29 : sans clé restante, le marqueur est créé quand même', () async {
      await check();

      expect(env.exists('tidemark/installed'), isTrue);
      expect(
        env.keyStore.writes,
        0,
        reason: 'la clé neuve vient de l\'ouverture',
      );
    });
  });

  group('CA30 : base présente sans marqueur (installation antérieure)', () {
    test('CA30 : aucune clé n\'est effacée, le marqueur est créé', () async {
      writeDatabase();
      env.keyStore.stored = 'cle-du-journal';

      await check();

      expect(env.log, ['createFile tidemark/installed']);
      expect(env.keyStore.stored, 'cle-du-journal');
      expect(env.exists('tidemark/installed'), isTrue);
      expect(File('${env.folder.path}/journal.db').readAsStringSync(), 'base');
    });

    test('CA30 : même clé absente, rien n\'est effacé (la clé introuvable est '
        'traitée par l\'ouverture)', () async {
      writeDatabase();

      await check();

      expect(env.log, ['createFile tidemark/installed']);
      expect(File('${env.folder.path}/journal.db').existsSync(), isTrue);
    });
  });

  group('CA32 : erreurs', () {
    test('CA32 : l\'effacement de la clé échoue, rien ne lève, le marqueur '
        'n\'est pas créé', () async {
      env.folder.createSync(recursive: true);
      env.keyStore.stored = 'cle-restee';
      env.keyStore.deleteAllError = StateError('trousseau inaccessible');

      await check();

      expect(env.exists('tidemark/installed'), isFalse);
      expect(env.log, ['deleteAll']);
    });

    test('CA32 : tout est retenté à l\'appel suivant', () async {
      env.folder.createSync(recursive: true);
      env.keyStore.stored = 'cle-restee';
      env.keyStore.deleteAllError = StateError('trousseau inaccessible');
      await check();
      env.repair();
      env.log.clear();

      await check();

      expect(env.log, ['deleteAll', 'createFile tidemark/installed']);
      expect(env.keyStore.stored, isNull);
      expect(env.exists('tidemark/installed'), isTrue);
    });

    test('CA32 : l\'écriture du marqueur échoue, rien ne lève, le marqueur '
        'n\'existe pas', () async {
      env.folder.createSync(recursive: true);
      env.keyStore.stored = 'cle-restee';
      env.files.failOn.add('createFile tidemark/installed');

      await check();

      expect(env.exists('tidemark/installed'), isFalse);
    });

    test('CA32 : après une écriture du marqueur en échec, l\'appel suivant le '
        'crée', () async {
      env.folder.createSync(recursive: true);
      env.files.failOn.add('createFile tidemark/installed');
      await check();
      env.repair();

      await check();

      expect(env.exists('tidemark/installed'), isTrue);
    });

    test('CA32 : l\'écriture du marqueur échoue pour une base antérieure, '
        'rien ne lève et la clé reste', () async {
      writeDatabase();
      env.keyStore.stored = 'cle-du-journal';
      env.files.failOn.add('createFile tidemark/installed');

      await check();

      expect(env.keyStore.stored, 'cle-du-journal');
      expect(env.exists('tidemark/installed'), isFalse);
    });
  });
}
