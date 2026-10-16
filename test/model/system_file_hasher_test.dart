// Calcul de l'empreinte du modèle par la bibliothèque du système (ADR-004,
// option F ; critères F1 à F9). Le canal est simulé : aucun vrai natif, aucun
// réseau, aucun vrai modèle d'IA.
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/main.dart';
import 'package:tidemark/model/model_downloader.dart';
import 'package:tidemark/model/model_source.dart';
import 'package:tidemark/model/model_state.dart';
import 'package:tidemark/model/system_file_hasher.dart';
import 'package:tidemark/storage/app_database.dart';
import 'package:tidemark/storage/database_key.dart';

import '../support/fake_model_transport.dart';
import '../support/model_fixtures.dart';

class _MemoryKeyStore implements KeyStore {
  String? stored;

  @override
  Future<String?> read() async => stored;

  @override
  Future<void> write(String key) async => stored = key;

  @override
  Future<void> deleteAll() async => stored = null;
}

/// Repli factice : compte ses appels, garde les chemins, rend [result] ou, à
/// défaut, le vrai calcul Dart.
class _FallbackProbe {
  final List<String> paths = [];
  String? result;
  Object? error;

  int get calls => paths.length;

  Future<String> call(String path) {
    paths.add(path);
    final failure = error;
    if (failure != null) return Future<String>.error(failure);
    final fixed = result;
    if (fixed != null) return Future.value(fixed);
    return sha256OfFile(path);
  }
}

/// Source [path] sans ses commentaires `//` : une ligne commentée ne compte pas.
String _code(String path) =>
    File(path)
        .readAsLinesSync()
        .map((line) => line.replaceFirst(RegExp(r'//.*'), ''))
        .join('\n');

const _expected =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _otherWellFormed =
    'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
const _fallbackValue =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger = TestDefaultBinaryMessengerBinding.instance;
  late _FallbackProbe fallback;
  late List<MethodCall> received;

  /// Installe le faux canal natif : [handler] rend la réponse ou lève.
  void mockChannel(Future<Object?> Function(MethodCall call) handler) {
    messenger.defaultBinaryMessenger.setMockMethodCallHandler(
      modelHashChannel,
      (call) {
        received.add(call);
        return handler(call);
      },
    );
  }

  SystemFileHasher hasher({String expected = _expected}) =>
      SystemFileHasher(expected: expected, fallback: fallback.call);

  setUp(() {
    fallback = _FallbackProbe()..result = _fallbackValue;
    received = [];
  });
  tearDown(() {
    messenger.defaultBinaryMessenger.setMockMethodCallHandler(
      modelHashChannel,
      null,
    );
  });

  group('SystemFileHasher.call', () {
    test('F1 : invoque sha256OfFile sur le canal avec {path: path}', () async {
      mockChannel((_) async => _expected);

      await hasher().call('/tmp/model.gguf');

      expect(received, hasLength(1));
      expect(received.single.method, 'sha256OfFile');
      expect(received.single.arguments, {'path': '/tmp/model.gguf'});
    });

    test('F1 : le canal par défaut s\'appelle dev.tidemark/model_hash', () {
      expect(modelHashChannel.name, 'dev.tidemark/model_hash');
    });

    test('F2 : empreinte native égale à expected : rendue telle quelle, sans '
        'appeler le repli', () async {
      mockChannel((_) async => _expected);

      expect(await hasher().call('/tmp/model.gguf'), _expected);

      expect(fallback.calls, 0);
    });

    test('F3 : empreinte native bien formée mais différente : la réponse '
        'native n\'est pas crue, le repli décide', () async {
      mockChannel((_) async => _otherWellFormed);

      expect(await hasher().call('/tmp/model.gguf'), _fallbackValue);

      expect(fallback.paths, ['/tmp/model.gguf']);
    });

    test('F4 : PlatformException du canal : le repli décide', () async {
      mockChannel((_) async => throw PlatformException(code: 'io'));

      expect(await hasher().call('/tmp/model.gguf'), _fallbackValue);

      expect(fallback.paths, ['/tmp/model.gguf']);
    });

    test('F5 : aucun gestionnaire enregistré (MissingPluginException) : le '
        'repli décide', () async {
      // Aucun mockChannel : le canal n'a pas de gestionnaire.
      expect(await hasher().call('/tmp/model.gguf'), _fallbackValue);

      expect(fallback.paths, ['/tmp/model.gguf']);
    });

    final malformed = <String, Object?>{
      'null': null,
      'trop courte': _expected.substring(1),
      'trop longue': '${_expected}0',
      'vide': '',
      'caractères non hexadécimaux': 'g' * 64,
      'majuscules': _expected.toUpperCase(),
      'espaces autour': ' $_expected ',
      'entier': 42,
      'liste': [_expected],
      'booléen': true,
    };
    for (final entry in malformed.entries) {
      test('F6 : réponse native mal formée (${entry.key}) : le repli '
          'décide', () async {
        mockChannel((_) async => entry.value);

        expect(await hasher().call('/tmp/model.gguf'), _fallbackValue);

        expect(fallback.paths, ['/tmp/model.gguf']);
      });
    }

    test('F6 : majuscules identiques à expected en minuscules : jamais crues '
        'sans le repli', () async {
      mockChannel((_) async => _expected.toUpperCase());

      await hasher().call('/tmp/model.gguf');

      expect(fallback.calls, 1);
    });

    test('F1 : l\'empreinte attendue ne transite jamais par le canal (le natif '
        'ne peut pas la renvoyer sans calcul)', () async {
      mockChannel((_) async => _expected);

      await hasher().call('/tmp/model.gguf');

      final arguments = received.single.arguments as Map;
      expect(arguments.keys, ['path']);
      expect(arguments.values, isNot(contains(_expected)));
    });

    test('F10 : canal qui ne répond jamais : le repli décide après le délai '
        'borné', () async {
      final never = Completer<Object?>();
      mockChannel((_) => never.future);
      final bounded = SystemFileHasher(
        expected: _expected,
        fallback: fallback.call,
        nativeTimeout: const Duration(milliseconds: 50),
      );

      expect(await bounded.call('/tmp/model.gguf'), _fallbackValue);

      expect(fallback.paths, ['/tmp/model.gguf']);
    });

    test('F10 : délai par défaut large (60 s) : un calcul natif lent mais '
        'réel n\'est pas abandonné trop tôt', () {
      expect(
        const SystemFileHasher(expected: _expected).nativeTimeout,
        const Duration(seconds: 60),
      );
    });

    test('F7 : FileSystemException du repli propagée telle quelle (fichier '
        'absent)', () async {
      mockChannel((_) async => throw PlatformException(code: 'io'));
      final missing = FileSystemException('absent', '/tmp/absent.gguf');
      fallback.error = missing;

      await expectLater(
        hasher().call('/tmp/absent.gguf'),
        throwsA(same(missing)),
      );
    });

    test('F7 : fichier réellement absent avec le repli par défaut : '
        'FileSystemException', () async {
      mockChannel((_) async => throw PlatformException(code: 'io'));
      final real = SystemFileHasher(expected: _expected);

      await expectLater(
        real.call(
          '/tmp/tidemark_absent_${DateTime.now().microsecondsSinceEpoch}',
        ),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('F8 : intégration avec HttpModelDownloader', () {
    late Directory tmp;
    late Directory models;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('tidemark_hasher_');
      models = Directory('${tmp.path}/models');
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    File finalFile() => File('${models.path}/${testSource.fileName}');

    HttpModelDownloader build() => HttpModelDownloader(
      transport: FakeModelTransport(),
      folder: models,
      source: testSource,
      idleTimeout: const Duration(seconds: 5),
      hashFile: SystemFileHasher(
        expected: testSource.sha256,
        fallback: fallback.call,
      ).call,
    );

    Future<HttpModelDownloader> readyWith(List<int> bytes) async {
      models.createSync(recursive: true);
      finalFile().writeAsBytesSync(bytes);
      final downloader = build();
      await downloader.checkAtStartup();
      expect(downloader.current, isA<ModelReady>());
      return downloader;
    }

    setUp(() => fallback.result = null); // vrai calcul Dart par défaut

    test('F8a : canal en erreur, bon fichier : true, ModelReady, fichier '
        'gardé', () async {
      mockChannel((_) async => throw PlatformException(code: 'io'));
      final downloader = await readyWith(modelBytes);

      expect(await downloader.verifyBeforeFirstLoad(), isTrue);

      expect(downloader.current, isA<ModelReady>());
      expect(finalFile().readAsBytesSync(), modelBytes);
      expect(fallback.calls, 1);
    });

    test('F8b : canal en erreur, mauvais contenu : false, fichier effacé, '
        'ModelAbsent', () async {
      mockChannel((_) async => throw PlatformException(code: 'io'));
      final downloader = await readyWith(wrongBytes);

      expect(await downloader.verifyBeforeFirstLoad(), isFalse);

      expect(downloader.current, isA<ModelAbsent>());
      expect(finalFile().existsSync(), isFalse);
      expect(filesIn(models), isEmpty);
    });

    test('F8c : canal qui rend une empreinte fausse, fichier bon : true (le '
        'repli Dart confirme), fichier gardé', () async {
      mockChannel((_) async => _otherWellFormed);
      final downloader = await readyWith(modelBytes);

      expect(await downloader.verifyBeforeFirstLoad(), isTrue);

      expect(fallback.calls, 1);
      expect(downloader.current, isA<ModelReady>());
      expect(finalFile().readAsBytesSync(), modelBytes);
    });

    test('F8d : canal qui rend l\'empreinte attendue : true sans appel au '
        'repli (voie rapide)', () async {
      mockChannel((_) async => testSource.sha256);
      final downloader = await readyWith(modelBytes);

      expect(await downloader.verifyBeforeFirstLoad(), isTrue);

      expect(fallback.calls, 0);
      expect(downloader.current, isA<ModelReady>());
    });

    test('F8e : verifyAfterLoadFailure, canal qui rend une empreinte fausse, '
        'fichier bon : fichier gardé, ModelReady', () async {
      mockChannel((_) async => _otherWellFormed);
      final downloader = await readyWith(modelBytes);

      await downloader.verifyAfterLoadFailure();

      expect(fallback.calls, 1);
      expect(downloader.current, isA<ModelReady>());
      expect(finalFile().readAsBytesSync(), modelBytes);
    });

    test('F8f : verifyAfterLoadFailure, canal en erreur, mauvais contenu : '
        'fichier effacé, ModelAbsent', () async {
      mockChannel((_) async => throw PlatformException(code: 'io'));
      final downloader = await readyWith(wrongBytes);

      await downloader.verifyAfterLoadFailure();

      expect(downloader.current, isA<ModelAbsent>());
      expect(finalFile().existsSync(), isFalse);
    });
  });

  group('F9 : câblage', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('tidemark_wire_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('F9 : openJournal construit un HttpModelDownloader dont hashFile est '
        'modelSha256OfFile', () async {
      final journal = await openJournal(
        folder: dir,
        keyStore: _MemoryKeyStore(),
      );
      addTearDown(() => (journal.entries as DriftEntryRepository).db.close());

      final downloader = journal.downloader;

      expect(downloader, isA<HttpModelDownloader>());
      expect(
        identical(
          (downloader as HttpModelDownloader).hashFile,
          modelSha256OfFile,
        ),
        isTrue,
      );
      // `modelSha256OfFile` compare à l'empreinte de `qwenModelSource` : le
      // téléchargeur doit vérifier contre la même source, sinon la voie rapide
      // ne servirait plus jamais.
      expect(downloader.source, same(qwenModelSource));
    });

    test('F9 : modelSha256OfFile prend la voie native pour l\'empreinte du '
        'modèle de l\'app', () async {
      // Chemin absent : le repli Dart lèverait FileSystemException.
      mockChannel((_) async => qwenModelSource.sha256);

      expect(
        await modelSha256OfFile('/tmp/tidemark_absent.gguf'),
        qwenModelSource.sha256,
      );
    });

    test('F9 : le natif iOS déclare le canal et la méthode de la constante '
        'Dart, hors commentaires', () {
      final swift = _code('ios/Runner/ModelHashChannel.swift');

      expect(swift, contains('"${modelHashChannel.name}"'));
      expect(swift, contains('"sha256OfFile"'));
      expect(swift, contains('FlutterMethodChannel('));
    });

    test('F9 : le calcul iOS tourne hors du fil principal', () {
      final swift = _code('ios/Runner/ModelHashChannel.swift');

      expect(
        swift,
        contains(RegExp(r'^\s*queue\.async\s*\{', multiLine: true)),
      );
    });

    test('F9 : AppDelegate enregistre le canal iOS sur le moteur, hors '
        'commentaires', () {
      final delegate = _code('ios/Runner/AppDelegate.swift');

      expect(
        delegate,
        contains(RegExp(r'^\s*ModelHashChannel\.register\(', multiLine: true)),
      );
    });

    test('F9 : le natif Android déclare et enregistre le canal de la '
        'constante Dart, sur une file d\'arrière-plan, hors commentaires', () {
      final kotlin = _code(
        'android/app/src/main/kotlin/dev/tidemark/tidemark/MainActivity.kt',
      );

      expect(kotlin, contains('"${modelHashChannel.name}"'));
      expect(kotlin, contains('"sha256OfFile"'));
      expect(kotlin, contains('override fun configureFlutterEngine('));
      expect(kotlin, contains('super.configureFlutterEngine(flutterEngine)'));
      expect(kotlin, contains(RegExp(r'^\s*MethodChannel\(', multiLine: true)));
      expect(kotlin, contains('makeBackgroundTaskQueue()'));
      expect(kotlin, contains('.setMethodCallHandler'));
    });

    test('F9 : le natif Android répond même après une Error (pas seulement '
        'une Exception)', () {
      final kotlin = _code(
        'android/app/src/main/kotlin/dev/tidemark/tidemark/MainActivity.kt',
      );

      expect(kotlin, contains(RegExp(r'catch \(\w+: Throwable\)')));
    });
  });
}
