// Vérification de l'empreinte avant le premier chargement (spec 003, règle
// « Vérification avant le premier chargement », CA34, CA35, CA36 ; ADR-004).
// Dossier temporaire et faux transport : aucun réseau, aucun modèle d'IA. Le calcul
// de l'empreinte est injecté (`hashFile`) pour être compté, retenu ou en erreur.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/model/model_downloader.dart';
import 'package:tidemark/model/model_state.dart';

import '../support/fake_model_transport.dart';
import '../support/model_fixtures.dart';

/// Calcul d'empreinte factice : compte ses appels et garde les chemins reçus ; son
/// comportement se règle par [behavior] (par défaut, le vrai calcul).
class HashProbe {
  final List<String> paths = [];

  /// Remplace le calcul ; reçoit le numéro d'appel (à partir de 1).
  Future<String> Function(String path, int call)? behavior;

  int get calls => paths.length;

  Future<String> call(String path) {
    paths.add(path);
    final custom = behavior;
    if (custom != null) return custom(path, paths.length);
    return sha256OfFile(path);
  }
}

void main() {
  late Directory tmp;
  late Directory models;
  late HashProbe probe;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tidemark_verify_');
    models = Directory('${tmp.path}/models');
    probe = HashProbe();
  });
  tearDown(() {
    // Un test a pu retirer les droits d'un fichier : on les rend avant d'effacer.
    for (final entity in tmp.listSync(recursive: true)) {
      if (entity is File && !Platform.isWindows) {
        Process.runSync('chmod', ['644', entity.path]);
      }
    }
    tmp.deleteSync(recursive: true);
  });

  File finalFile() => File('${models.path}/${testSource.fileName}');

  HttpModelDownloader build([FakeModelTransport? transport]) =>
      HttpModelDownloader(
        transport: transport ?? FakeModelTransport(),
        folder: models,
        source: testSource,
        idleTimeout: const Duration(seconds: 5),
        hashFile: probe.call,
      );

  /// Modèle `ready` au démarrage (CA22) avec le contenu [bytes].
  Future<HttpModelDownloader> readyWith(List<int> bytes) async {
    models.createSync(recursive: true);
    finalFile().writeAsBytesSync(bytes);
    final downloader = build();
    await downloader.checkAtStartup();
    expect(downloader.current, isA<ModelReady>());
    return downloader;
  }

  void expectAbsentWithoutFailure(ModelDownloader downloader) {
    expect(downloader.current, isA<ModelAbsent>());
    expect((downloader.current as ModelAbsent).failure, isNull);
  }

  group('CA34 : premier appel du lancement', () {
    test(
      'CA34 : empreinte juste : rend true, le modèle reste ready, le fichier '
      'est gardé',
      () async {
        final downloader = await readyWith(modelBytes);

        expect(await downloader.verifyBeforeFirstLoad(), isTrue);

        expect(downloader.current, isA<ModelReady>());
        expect(finalFile().readAsBytesSync(), modelBytes);
        expect(probe.calls, 1, reason: 'l\'empreinte est calculée une fois');
        expect(probe.paths.single, finalFile().path);
      },
    );

    test('CA34 : même taille, contenu modifié : rend false, le fichier est '
        'effacé, le modèle est absent sans cause d\'échec', () async {
      final downloader = await readyWith(wrongBytes);
      expect(wrongBytes.length, testSource.sizeBytes);

      expect(await downloader.verifyBeforeFirstLoad(), isFalse);

      expectAbsentWithoutFailure(downloader);
      expect(filesIn(models), isEmpty);
    });

    test('CA34 : empreinte fausse : l\'état « absent » est émis, jamais un '
        'état d\'échec', () async {
      final downloader = await readyWith(wrongBytes);
      final log = StateLog(downloader);
      addTearDown(log.close);

      await downloader.verifyBeforeFirstLoad();
      await pumpEventQueue();

      expect(log.last, isA<ModelAbsent>());
      expect(
        log.states.whereType<ModelAbsent>().every((s) => s.failure == null),
        isTrue,
      );
    });

    test('CA34 : fichier illisible (droits retirés) : rend false, le modèle '
        'est absent sans cause d\'échec', () async {
      final downloader = await readyWith(modelBytes);
      final result = Process.runSync('chmod', ['000', finalFile().path]);
      expect(result.exitCode, 0);
      // Si le fichier reste lisible malgré tout (utilisateur privilégié), le cas
      // n'est pas simulable ici : le test suivant le couvre par `hashFile`.
      var readable = true;
      try {
        finalFile().openSync().closeSync();
      } on FileSystemException {
        readable = false;
      }
      if (readable) {
        markTestSkipped('fichier lisible malgré chmod 000 (utilisateur root)');
        return;
      }

      expect(await downloader.verifyBeforeFirstLoad(), isFalse);

      expectAbsentWithoutFailure(downloader);
    }, skip: Platform.isWindows ? 'chmod indisponible' : false);

    test('CA34 : fichier disparu entre le démarrage et la vérification : rend '
        'false, le modèle est absent sans cause d\'échec', () async {
      final downloader = await readyWith(modelBytes);
      finalFile().deleteSync();

      expect(await downloader.verifyBeforeFirstLoad(), isFalse);

      expectAbsentWithoutFailure(downloader);
    });

    test('CA34 : modèle absent : rend false sans rien calculer', () async {
      final downloader = build();
      await downloader.checkAtStartup();
      expect(downloader.current, isA<ModelAbsent>());

      expect(await downloader.verifyBeforeFirstLoad(), isFalse);

      expect(probe.calls, 0);
      expectAbsentWithoutFailure(downloader);
    });

    test('CA34 : avant tout checkAtStartup (état initial absent) : rend false '
        'sans rien calculer, même si un fichier traîne', () async {
      models.createSync(recursive: true);
      finalFile().writeAsBytesSync(modelBytes);
      final downloader = build();

      expect(await downloader.verifyBeforeFirstLoad(), isFalse);

      expect(probe.calls, 0);
      expect(finalFile().existsSync(), isTrue, reason: 'rien n\'est effacé');
    });

    test('CA34 : téléchargement en cours : rend false sans rien calculer, et '
        'le téléchargement n\'est pas perturbé', () async {
      final body = GatedResponse();
      final downloader = build(FakeModelTransport([body.response]));
      final download = downloader.start();
      await eventually(
        () => downloader.current is ModelDownloading,
        reason: 'téléchargement démarré',
      );

      expect(await downloader.verifyBeforeFirstLoad(), isFalse);

      expect(probe.calls, 0);
      expect(downloader.current, isA<ModelDownloading>());
      await downloader.cancel();
      await download;
    });
  });

  group('CA35 : appels suivants, concurrence, erreurs', () {
    test('CA35 : un deuxième appel après une vérification juste rend true sans '
        'nouveau calcul', () async {
      final downloader = await readyWith(modelBytes);

      expect(await downloader.verifyBeforeFirstLoad(), isTrue);
      expect(await downloader.verifyBeforeFirstLoad(), isTrue);
      expect(await downloader.verifyBeforeFirstLoad(), isTrue);

      expect(probe.calls, 1);
      expect(downloader.current, isA<ModelReady>());
    });

    test('CA35 : deux appels simultanés ne font qu\'un seul calcul', () async {
      final gate = Completer<void>();
      probe.behavior = (path, call) async {
        await gate.future;
        return sha256OfFile(path);
      };
      final downloader = await readyWith(modelBytes);

      final first = downloader.verifyBeforeFirstLoad();
      final second = downloader.verifyBeforeFirstLoad();
      await pumpEventQueue();
      expect(
        probe.calls,
        1,
        reason: 'le calcul est partagé pendant qu\'il dure',
      );
      gate.complete();

      expect(await Future.wait([first, second]), [true, true]);
      expect(probe.calls, 1);
    });

    test('CA35 : deux appels simultanés avec empreinte fausse rendent false '
        'tous les deux, avec un seul calcul', () async {
      final gate = Completer<void>();
      probe.behavior = (path, call) async {
        await gate.future;
        return sha256OfFile(path);
      };
      final downloader = await readyWith(wrongBytes);

      final first = downloader.verifyBeforeFirstLoad();
      final second = downloader.verifyBeforeFirstLoad();
      await pumpEventQueue();
      gate.complete();

      expect(await Future.wait([first, second]), [false, false]);
      expect(probe.calls, 1);
      expect(downloader.current, isA<ModelAbsent>());
    });

    test('CA35 : modèle téléchargé et vérifié pendant le lancement (CA14) : '
        'rend true sans appeler hashFile', () async {
      final transport = FakeModelTransport([
        FakeModelTransport.ok(chunksOf(modelBytes, 100)),
      ]);
      final downloader = build(transport);
      await downloader.checkAtStartup();
      await downloader.start();
      await eventually(
        () => downloader.current is ModelReady,
        reason: 'téléchargement terminé',
      );

      expect(await downloader.verifyBeforeFirstLoad(), isTrue);

      expect(probe.calls, 0);
      expect(downloader.current, isA<ModelReady>());
    });

    test('CA35 : après deleteModel(), rend false et le modèle reste absent, '
        'même après une vérification juste', () async {
      final downloader = await readyWith(modelBytes);
      expect(await downloader.verifyBeforeFirstLoad(), isTrue);

      await downloader.deleteModel();

      expect(await downloader.verifyBeforeFirstLoad(), isFalse);
      expect(downloader.current, isA<ModelAbsent>());
      expect(filesIn(models), isEmpty);
    });

    test('CA35 : modèle effacé pendant le calcul : rend false, le modèle est '
        'absent et aucun état « prêt » n\'est émis ensuite', () async {
      final gate = Completer<void>();
      probe.behavior = (path, call) async {
        await gate.future;
        // Le fichier a disparu mais le calcul rend l'empreinte juste : la
        // vérification ne doit pas ressusciter le modèle.
        return testSource.sha256;
      };
      final downloader = await readyWith(modelBytes);
      final log = StateLog(downloader);
      addTearDown(log.close);
      await pumpEventQueue();
      final before = log.states.length;

      final verification = downloader.verifyBeforeFirstLoad();
      await pumpEventQueue();
      expect(probe.calls, 1);
      await downloader.deleteModel();
      gate.complete();

      expect(await verification, isFalse);
      await pumpEventQueue();
      expect(downloader.current, isA<ModelAbsent>());
      expect(log.states.skip(before).whereType<ModelReady>(), isEmpty);
      expect(filesIn(models), isEmpty);
      expect(await downloader.verifyBeforeFirstLoad(), isFalse);
    });

    test('CA35 : une erreur du calcul autre qu\'un fichier illisible rend '
        'false, garde le fichier et le modèle ready ; l\'appel suivant '
        'recalcule', () async {
      probe.behavior = (path, call) {
        if (call == 1) throw StateError('mémoire insuffisante');
        return sha256OfFile(path);
      };
      final downloader = await readyWith(modelBytes);

      expect(await downloader.verifyBeforeFirstLoad(), isFalse);

      expect(downloader.current, isA<ModelReady>());
      expect(finalFile().readAsBytesSync(), modelBytes);
      expect(probe.calls, 1);

      expect(await downloader.verifyBeforeFirstLoad(), isTrue);
      expect(probe.calls, 2, reason: 'rien n\'a été gardé en mémoire');
      expect(downloader.current, isA<ModelReady>());
    });

    test('CA35 : une erreur asynchrone du calcul se traite comme une erreur '
        'synchrone', () async {
      probe.behavior = (path, call) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        throw const IsolateSpawnLikeError();
      };
      final downloader = await readyWith(modelBytes);

      expect(await downloader.verifyBeforeFirstLoad(), isFalse);

      expect(downloader.current, isA<ModelReady>());
      expect(finalFile().existsSync(), isTrue);
      expect(await downloader.verifyBeforeFirstLoad(), isFalse);
      expect(probe.calls, 2);
    });

    test('CA35 : un calcul qui lève FileSystemException est traité comme une '
        'empreinte fausse : fichier effacé, modèle absent sans cause '
        'd\'échec', () async {
      probe.behavior = (path, call) =>
          throw FileSystemException('illisible', path);
      final downloader = await readyWith(modelBytes);

      expect(await downloader.verifyBeforeFirstLoad(), isFalse);

      expectAbsentWithoutFailure(downloader);
      expect(filesIn(models), isEmpty);
    });

    test('CA35 : après une empreinte fausse, retéléchargement : rend true '
        'sans nouveau calcul', () async {
      final downloader = await readyWith(wrongBytes);
      expect(await downloader.verifyBeforeFirstLoad(), isFalse);
      final transport = FakeModelTransport([
        FakeModelTransport.ok(chunksOf(modelBytes, 100)),
      ]);
      final again = build(transport);
      await again.checkAtStartup();
      await again.start();
      await eventually(
        () => again.current is ModelReady,
        reason: 'retéléchargement terminé',
      );
      final callsBefore = probe.calls;

      expect(await again.verifyBeforeFirstLoad(), isTrue);

      expect(probe.calls, callsBefore);
    });
  });

  group('CA36 : calcul hors du fil principal', () {
    const size = 32 * 1024 * 1024;

    late File big;
    late String expected;

    setUp(() {
      big = File('${tmp.path}/big.bin')
        ..writeAsBytesSync(Uint8List(size), flush: true);
      expected = sha256.convert(Uint8List(size)).toString();
    });

    test('CA36 : sha256OfFile rend l\'empreinte hexadécimale juste', () async {
      expect(await sha256OfFile(big.path), expected);
    });

    test('CA36 : sha256OfFile rend l\'empreinte d\'un petit fichier', () async {
      final small = File('${tmp.path}/small.bin')..writeAsBytesSync(modelBytes);

      expect(await sha256OfFile(small.path), testSource.sha256);
    });

    test('CA36 : pendant le calcul d\'un fichier de 32 Mo, un minuteur '
        'périodique du fil principal se déclenche au moins 3 fois', () async {
      var ticks = 0;
      final timer = Timer.periodic(
        const Duration(milliseconds: 4),
        (_) => ticks++,
      );
      addTearDown(timer.cancel);

      final digest = await sha256OfFile(big.path);
      timer.cancel();

      expect(digest, expected);
      expect(
        ticks,
        greaterThanOrEqualTo(3),
        reason:
            'le calcul bloque le fil principal : il doit tourner dans un '
            'isolat',
      );
    });

    test('CA36 : verifyAfterLoadFailure passe par le hashFile injecté : '
        'empreinte rendue fausse, le fichier est effacé et le modèle est '
        'absent', () async {
      probe.behavior = (path, call) async => 'f' * 64;
      final downloader = await readyWith(modelBytes);

      await downloader.verifyAfterLoadFailure();

      expect(probe.calls, 1);
      expect(probe.paths.single, finalFile().path);
      expectAbsentWithoutFailure(downloader);
      expect(filesIn(models), isEmpty);
    });

    test('CA36 : verifyAfterLoadFailure passe par le hashFile injecté : '
        'empreinte rendue juste, le modèle reste ready', () async {
      // Contenu faux sur disque : seule la valeur rendue par `hashFile` décide.
      probe.behavior = (path, call) async => testSource.sha256;
      final downloader = await readyWith(wrongBytes);

      await downloader.verifyAfterLoadFailure();

      expect(probe.calls, 1);
      expect(downloader.current, isA<ModelReady>());
      expect(finalFile().existsSync(), isTrue);
    });

    test('CA36 : verifyBeforeFirstLoad passe par le hashFile injecté : '
        'seule sa valeur décide', () async {
      probe.behavior = (path, call) async => testSource.sha256;
      final downloader = await readyWith(wrongBytes);

      expect(await downloader.verifyBeforeFirstLoad(), isTrue);

      expect(probe.calls, 1);
      expect(downloader.current, isA<ModelReady>());
    });
  });
}

/// Erreur autre qu'un fichier illisible (mémoire, isolat interrompu).
class IsolateSpawnLikeError implements Exception {
  const IsolateSpawnLikeError();
}
