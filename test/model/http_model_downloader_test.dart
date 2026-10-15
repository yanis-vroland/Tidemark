// Téléchargeur du modèle (spec 003) : requête, redirections, vérification, échecs,
// démarrage. `FakeModelTransport` et un dossier temporaire : aucune requête vers
// Internet.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/model/model_downloader.dart';
import 'package:tidemark/model/model_source.dart';
import 'package:tidemark/model/model_state.dart';
import 'package:tidemark/model/model_transport.dart';

import '../support/fake_model_transport.dart';
import '../support/model_fixtures.dart';

void main() {
  late Directory tmp;
  late Directory models;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tidemark_model_');
    // Comme en production : le dossier `models/` n'existe pas encore.
    models = Directory('${tmp.path}/models');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  HttpModelDownloader build(
    ModelTransport transport, {
    Duration idleTimeout = const Duration(seconds: 5),
    ModelSource? source,
  }) => HttpModelDownloader(
    transport: transport,
    folder: models,
    source: source ?? testSource,
    idleTimeout: idleTimeout,
  );

  /// Lance un téléchargement et attend sa fin.
  Future<StateLog> download(HttpModelDownloader downloader) async {
    final log = StateLog(downloader);
    addTearDown(log.close);
    await downloader.start();
    await log.settled();
    return log;
  }

  void expectFailure(StateLog log, DownloadFailure failure) {
    expect(log.last, isA<ModelAbsent>());
    expect((log.last as ModelAbsent).failure, failure);
  }

  List<List<int>> goodBody() => chunksOf(modelBytes, 100);

  group('constantes', () {
    test('CA17 : le délai sans octet par défaut est de 30 secondes', () {
      final downloader = HttpModelDownloader(
        transport: FakeModelTransport(),
        folder: models,
      );

      expect(downloader.idleTimeout, const Duration(seconds: 30));
    });

    test('la source par défaut est qwenModelSource', () {
      final downloader = HttpModelDownloader(
        transport: FakeModelTransport(),
        folder: models,
      );

      expect(downloader.source, same(qwenModelSource));
    });
  });

  group('aucune requête sans appui (CA6)', () {
    test('CA6 : construire le téléchargeur, l\'observer et vérifier le '
        'démarrage n\'envoie aucune requête', () async {
      final transport = FakeModelTransport();
      final downloader = build(transport);

      final log = StateLog(downloader);
      addTearDown(log.close);
      await downloader.checkAtStartup();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(transport.calls, isEmpty);
      expect(downloader.current, isA<ModelAbsent>());
    });

    test('CA6 : le modèle est absent tant que rien n\'a été demandé', () {
      final downloader = build(FakeModelTransport());

      expect(downloader.current, isA<ModelAbsent>());
      expect((downloader.current as ModelAbsent).failure, isNull);
    });
  });

  group('requête (CA7)', () {
    test('CA7 : une seule demande, vers l\'URL de la source, sans paramètre '
        'ajouté', () async {
      final transport = FakeModelTransport([FakeModelTransport.ok(goodBody())]);

      await download(build(transport));

      expect(transport.calls, hasLength(1));
      expect(transport.calls.single.url, testSource.url);
      expect(transport.calls.single.url.hasQuery, isFalse);
    });

    test('CA7 : exactement les en-têtes User-Agent: Tidemark et '
        'Accept-Encoding: identity', () async {
      final transport = FakeModelTransport([FakeModelTransport.ok(goodBody())]);

      await download(build(transport));

      final headers = {
        for (final e in transport.calls.single.headers.entries)
          e.key.toLowerCase(): e.value,
      };
      expect(headers, {
        'user-agent': 'Tidemark',
        'accept-encoding': 'identity',
      });
    });

    test('CA7 : aucun en-tête Range, ni Cookie, ni Authorization', () async {
      final transport = FakeModelTransport([FakeModelTransport.ok(goodBody())]);

      await download(build(transport));

      final names = transport.calls.single.headers.keys.map(
        (k) => k.toLowerCase(),
      );
      expect(names, isNot(contains('range')));
      expect(names, isNot(contains('cookie')));
      expect(names, isNot(contains('authorization')));
    });

    test('CA7 : l\'état passe à « en téléchargement », avec la taille de la '
        'source, sans vérification en cours', () async {
      final transport = FakeModelTransport([FakeModelTransport.ok(goodBody())]);

      final log = await download(build(transport));

      final first = log.downloading.first;
      expect(first.totalBytes, testSource.sizeBytes);
      expect(first.receivedBytes, 0);
      expect(first.verifying, isFalse);
    });

    test(
      'Requête : la requête est la même sur chaque appareil : aucune donnée de '
      'la personne',
      () async {
        final a = FakeModelTransport([FakeModelTransport.ok(goodBody())]);
        final b = FakeModelTransport([FakeModelTransport.ok(goodBody())]);

        await download(build(a));
        tmp.deleteSync(recursive: true);
        tmp.createSync();
        await download(build(b));

        expect(a.calls.single.url, b.calls.single.url);
        expect(a.calls.single.headers, b.calls.single.headers);
      },
    );
  });

  group('redirections (CA8)', () {
    final allowed = <String, String>{
      'https://cdn-lfs.huggingface.co/repos/ab/file':
          'https://cdn-lfs.huggingface.co/repos/ab/file',
      'https://cas-bridge.xethub.hf.co/xet/abc?X-Amz-Signature=1&x=2':
          'https://cas-bridge.xethub.hf.co/xet/abc?X-Amz-Signature=1&x=2',
      'https://us.aws.cdn.hf.co/xet-bridge-us/abc':
          'https://us.aws.cdn.hf.co/xet-bridge-us/abc',
      'https://huggingface.co/autre/chemin':
          'https://huggingface.co/autre/chemin',
      'https://CDN-LFS.HuggingFace.CO/x': 'https://cdn-lfs.huggingface.co/x',
      'https://huggingface.co:443/x': 'https://huggingface.co/x',
      '/api/resolve-cache/models/Qwen/test':
          'https://huggingface.co/api/resolve-cache/models/Qwen/test',
    };

    for (final MapEntry(key: location, value: expected) in allowed.entries) {
      test('CA8 : « $location » est suivie, avec la même requête', () async {
        final transport = FakeModelTransport([
          FakeModelTransport.redirect(location),
          FakeModelTransport.ok(goodBody()),
        ]);

        final log = await download(build(transport));

        expect(log.last, isA<ModelReady>());
        expect(transport.calls, hasLength(2));
        expect(
          transport.calls[1].url.toString(),
          Uri.parse(expected).toString(),
        );
        expect(transport.calls[1].headers, transport.calls[0].headers);
        expect(
          transport.calls[1].headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('range')),
        );
      });
    }

    for (final status in [301, 302, 303, 307, 308]) {
      test('CA8 : une redirection $status est suivie', () async {
        final transport = FakeModelTransport([
          FakeModelTransport.redirect(
            'https://cdn-lfs.huggingface.co/x',
            status: status,
          ),
          FakeModelTransport.ok(goodBody()),
        ]);

        final log = await download(build(transport));

        expect(log.last, isA<ModelReady>());
        expect(transport.calls, hasLength(2));
      });
    }

    test(
      'CA8 : un Location relatif est résolu sur l\'URL courante, celle de la '
      'redirection précédente',
      () async {
        final transport = FakeModelTransport([
          FakeModelTransport.redirect('https://cdn-lfs.huggingface.co/a/b'),
          FakeModelTransport.redirect('/c/d'),
          FakeModelTransport.ok(goodBody()),
        ]);

        final log = await download(build(transport));

        expect(log.last, isA<ModelReady>());
        expect(
          transport.calls[2].url.toString(),
          'https://cdn-lfs.huggingface.co/c/d',
        );
      },
    );

    final refused = [
      'https://huggingface.co.evil.com/x',
      'https://evilhf.co/x',
      'https://hf.co.evil.com/x',
      'https://xhuggingface.co/x',
      'http://huggingface.co/x',
      'http://cdn-lfs.huggingface.co/x',
      'https://huggingface.co:8443/x',
      'https://cdn-lfs.huggingface.co:8080/x',
      'https://huggingface.co@evil.com/x',
      '//evil.com/x',
      'ftp://huggingface.co/x',
    ];

    for (final location in refused) {
      test('CA8 : « $location » est refusée : échec réseau, aucune requête '
          'vers elle', () async {
        final transport = FakeModelTransport([
          FakeModelTransport.redirect(location),
          FakeModelTransport.ok(goodBody()),
        ]);

        final log = await download(build(transport));

        expectFailure(log, DownloadFailure.network);
        expect(transport.calls, hasLength(1));
        expect(transport.calls.single.url, testSource.url);
        expect(filesIn(models), isEmpty);
      });
    }

    test('CA8 : une adresse refusée au deuxième saut est refusée aussi, sans '
        'requête vers elle', () async {
      final transport = FakeModelTransport([
        FakeModelTransport.redirect('https://cdn-lfs.huggingface.co/a'),
        FakeModelTransport.redirect('https://evilhf.co/b'),
        FakeModelTransport.ok(goodBody()),
      ]);

      final log = await download(build(transport));

      expectFailure(log, DownloadFailure.network);
      expect(transport.calls, hasLength(2));
    });

    test(
      'CA8 : 5 redirections sont suivies, puis le fichier est reçu',
      () async {
        final transport = FakeModelTransport([
          for (var i = 1; i <= 5; i++)
            FakeModelTransport.redirect('https://cdn-lfs.huggingface.co/hop$i'),
          FakeModelTransport.ok(goodBody()),
        ]);

        final log = await download(build(transport));

        expect(log.last, isA<ModelReady>());
        expect(transport.calls, hasLength(6));
      },
    );

    test('CA8 : une sixième redirection n\'est pas suivie : échec réseau après '
        'six demandes', () async {
      final transport = FakeModelTransport([
        for (var i = 1; i <= 6; i++)
          FakeModelTransport.redirect('https://cdn-lfs.huggingface.co/hop$i'),
        FakeModelTransport.ok(goodBody()),
      ]);

      final log = await download(build(transport));

      expectFailure(log, DownloadFailure.network);
      expect(transport.calls, hasLength(6));
      expect(filesIn(models), isEmpty);
    });

    test(
      'CA8 : une boucle de redirections s\'arrête aussi à la limite',
      () async {
        final transport = FakeModelTransport([
          for (var i = 1; i <= 20; i++)
            FakeModelTransport.redirect(i.isEven ? '/a' : '/b'),
        ]);

        final log = await download(build(transport));

        expectFailure(log, DownloadFailure.network);
        expect(transport.calls.length, lessThanOrEqualTo(6));
      },
    );

    test(
      'CA8 : une redirection sans en-tête Location est un échec réseau',
      () async {
        final transport = FakeModelTransport([
          const TransportResponse(statusCode: 302, body: Stream.empty()),
          FakeModelTransport.ok(goodBody()),
        ]);

        final log = await download(build(transport));

        expectFailure(log, DownloadFailure.network);
        expect(transport.calls, hasLength(1));
      },
    );
  });

  group('progression (CA9)', () {
    test('CA9 : chaque point de pourcentage est signalé, avec la taille '
        'attendue', () async {
      // 100 morceaux de 10 octets sur 1 000 : un point de pourcentage par morceau.
      final transport = FakeModelTransport([
        FakeModelTransport.ok(chunksOf(modelBytes, 10)),
      ]);

      final log = await download(build(transport));

      final percents = {
        for (final s in log.downloading)
          if (!s.verifying) s.receivedBytes * 100 ~/ s.totalBytes,
      };
      for (var p = 1; p <= 99; p++) {
        expect(percents, contains(p), reason: '$p %');
      }
      expect(
        log.downloading.every((s) => s.totalBytes == testSource.sizeBytes),
        isTrue,
      );
    });

    test('CA9 : les octets reçus ne reculent jamais', () async {
      final transport = FakeModelTransport([
        FakeModelTransport.ok(chunksOf(modelBytes, 10)),
      ]);

      final log = await download(build(transport));

      final received = log.downloading.map((s) => s.receivedBytes).toList();
      expect(received, orderedEquals([...received]..sort()));
    });
  });

  group('un seul téléchargement à la fois (CA10)', () {
    test('CA10 : un second start() ne lance aucune requête de plus et la '
        'progression continue', () async {
      final gate = GatedResponse();
      final transport = FakeModelTransport([gate.response]);
      final downloader = build(transport);
      final log = StateLog(downloader);
      addTearDown(log.close);

      unawaited(downloader.start());
      await eventually(() => transport.calls.isNotEmpty, reason: 'requête');
      gate.controller.add(modelBytes.sublist(0, 400));
      await eventually(
        () => log.downloading.any((s) => s.receivedBytes == 400),
        reason: '400 octets reçus',
      );

      unawaited(downloader.start());
      unawaited(downloader.start());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(transport.calls, hasLength(1));
      expect(downloader.current, isA<ModelDownloading>());
      expect((downloader.current as ModelDownloading).receivedBytes, 400);

      gate.controller.add(modelBytes.sublist(400));
      await gate.controller.close();
      await log.settled();
      expect(log.last, isA<ModelReady>());
      expect(transport.calls, hasLength(1));
    });
  });

  group('annulation (CA13)', () {
    // Ajoutés après les revues de code et de sécurité : l'annulation doit arrêter
    // le téléchargement à toute étape, sans attendre la fin du transfert.
    test(
      'CA13 : annuler avant la réponse du serveur n\'attend pas la réponse et '
      'ne lit rien',
      () async {
        final pending = Completer<TransportResponse>();
        final transport = _PendingTransport(pending.future);
        final downloader = build(transport);
        final log = StateLog(downloader);
        addTearDown(log.close);
        unawaited(downloader.start());
        await eventually(() => transport.calls > 0, reason: 'requête');

        await downloader.cancel().timeout(const Duration(seconds: 2));

        expect(downloader.current, isA<ModelAbsent>());
        expect((downloader.current as ModelAbsent).failure, isNull);
        expect(filesIn(models), isEmpty);
        // La réponse tardive est refermée sans être lue.
        final gate = GatedResponse();
        pending.complete(gate.response);
        await eventually(() => gate.cancelled, reason: 'réponse refermée');
        expect(filesIn(models), isEmpty);
      },
    );

    test(
      'CA13 : annuler pendant une redirection ne suit pas la redirection',
      () async {
        final pending = Completer<TransportResponse>();
        final transport = _PendingTransport(pending.future);
        final downloader = build(transport);
        unawaited(downloader.start());
        await eventually(() => transport.calls > 0, reason: 'requête');
        final cancelling = downloader.cancel();

        pending.complete(
          FakeModelTransport.redirect('https://cdn-lfs.huggingface.co/x'),
        );
        await cancelling;

        expect(transport.calls, 1);
        expect(downloader.current, isA<ModelAbsent>());
        expect((downloader.current as ModelAbsent).failure, isNull);
      },
    );

    test('cancel() sans téléchargement en cours ne change rien', () async {
      final downloader = build(FakeModelTransport());

      await downloader.cancel();

      expect(downloader.current, isA<ModelAbsent>());
      expect((downloader.current as ModelAbsent).failure, isNull);
    });

    test('deleteModel() pendant un téléchargement l\'arrête et ne laisse aucun '
        'fichier', () async {
      final gate = GatedResponse();
      final transport = FakeModelTransport([gate.response]);
      final downloader = build(transport);
      unawaited(downloader.start());
      await eventually(() => transport.calls.isNotEmpty, reason: 'requête');
      gate.controller.add(modelBytes.sublist(0, 300));
      await eventually(
        () => filesIn(models).contains(partName),
        reason: 'fichier temporaire écrit',
      );

      await downloader.deleteModel();

      expect(downloader.current, isA<ModelAbsent>());
      expect(filesIn(models), isEmpty);
      expect(gate.cancelled, isTrue);
    });

    test('CA13 : cancel() arrête le transfert, efface le fichier temporaire et '
        'ramène à « absent » sans cause d\'échec', () async {
      final gate = GatedResponse();
      final transport = FakeModelTransport([gate.response]);
      final downloader = build(transport);
      final log = StateLog(downloader);
      addTearDown(log.close);
      unawaited(downloader.start());
      await eventually(() => transport.calls.isNotEmpty, reason: 'requête');
      gate.controller.add(modelBytes.sublist(0, 300));
      await eventually(
        () => filesIn(models).contains(partName),
        reason: 'fichier temporaire écrit',
      );

      await downloader.cancel();

      expect(downloader.current, isA<ModelAbsent>());
      expect((downloader.current as ModelAbsent).failure, isNull);
      expect(filesIn(models), isEmpty);
      expect(gate.cancelled, isTrue, reason: 'le transfert doit s\'arrêter');
    });

    test('CA13 : après l\'annulation, des octets tardifs ne relancent rien '
        'et ne laissent aucun fichier', () async {
      final gate = GatedResponse();
      final transport = FakeModelTransport([gate.response]);
      final downloader = build(transport);
      final log = StateLog(downloader);
      addTearDown(log.close);
      unawaited(downloader.start());
      await eventually(() => transport.calls.isNotEmpty, reason: 'requête');
      gate.controller.add(modelBytes.sublist(0, 300));
      await eventually(
        () => filesIn(models).contains(partName),
        reason: 'fichier temporaire écrit',
      );
      await downloader.cancel();

      if (!gate.controller.isClosed) {
        gate.controller.add(modelBytes.sublist(300));
        await gate.controller.close();
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(downloader.current, isA<ModelAbsent>());
      expect(filesIn(models), isEmpty);
      expect(transport.calls, hasLength(1));
    });

    test('CA13 : après l\'annulation, un nouveau téléchargement repart de '
        'zéro', () async {
      final gate = GatedResponse();
      final transport = FakeModelTransport([
        gate.response,
        FakeModelTransport.ok(goodBody()),
      ]);
      final downloader = build(transport);
      final log = StateLog(downloader);
      addTearDown(log.close);
      unawaited(downloader.start());
      await eventually(() => transport.calls.isNotEmpty, reason: 'requête');
      gate.controller.add(modelBytes.sublist(0, 300));
      await eventually(
        () => filesIn(models).contains(partName),
        reason: 'fichier temporaire écrit',
      );
      await downloader.cancel();

      await downloader.start();
      await eventually(
        () => downloader.current is ModelReady,
        reason: 'second téléchargement terminé',
      );

      expect(transport.calls, hasLength(2));
      expect(
        transport.calls[1].headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('range')),
      );
      expect(
        File('${models.path}/${testSource.fileName}').readAsBytesSync(),
        modelBytes,
      );
    });
  });

  group('vérification (CA14, CA15, CA16)', () {
    test('CA14 : tous les octets reçus, la vérification est annoncée puis le '
        'modèle est prêt', () async {
      final transport = FakeModelTransport([FakeModelTransport.ok(goodBody())]);

      final log = await download(build(transport));

      final verifying = log.downloading.where((s) => s.verifying).toList();
      expect(verifying, isNotEmpty);
      expect(verifying.first.receivedBytes, testSource.sizeBytes);
      expect(verifying.first.totalBytes, testSource.sizeBytes);
      expect(log.last, isA<ModelReady>());
      final verifyingAt = log.states.indexOf(verifying.first);
      expect(log.states.indexOf(log.last), greaterThan(verifyingAt));
    });

    test('CA14 : le fichier est à son nom définitif, intact, sans fichier '
        'temporaire ; ModelReady donne son chemin', () async {
      final transport = FakeModelTransport([FakeModelTransport.ok(goodBody())]);

      final log = await download(build(transport));

      final ready = log.last as ModelReady;
      expect(ready.path, '${models.path}/${testSource.fileName}');
      expect(File(ready.path).readAsBytesSync(), modelBytes);
      expect(filesIn(models), [testSource.fileName]);
    });

    test('CA14 : le fichier temporaire existe pendant le transfert et porte '
        'les octets reçus', () async {
      final gate = GatedResponse();
      final transport = FakeModelTransport([gate.response]);
      final downloader = build(transport);
      final log = StateLog(downloader);
      addTearDown(log.close);
      unawaited(downloader.start());
      await eventually(() => transport.calls.isNotEmpty, reason: 'requête');

      gate.controller.add(modelBytes.sublist(0, 500));
      await eventually(
        () => filesIn(models).contains(partName),
        reason: 'fichier temporaire',
      );

      expect(filesIn(models), isNot(contains(testSource.fileName)));
      gate.controller.add(modelBytes.sublist(500));
      await gate.controller.close();
      await log.settled();
      expect(log.last, isA<ModelReady>());
    });

    test('CA14 : une empreinte juste avec une réponse en un seul morceau est '
        'acceptée', () async {
      final transport = FakeModelTransport([
        FakeModelTransport.ok([modelBytes]),
      ]);

      final log = await download(build(transport));

      expect(log.last, isA<ModelReady>());
    });

    test('CA15 : une empreinte fausse efface le fichier, ramène à « absent » '
        'et donne l\'échec « fichier faux »', () async {
      final transport = FakeModelTransport([
        FakeModelTransport.ok(chunksOf(wrongBytes, 100)),
      ]);

      final log = await download(build(transport));

      expectFailure(log, DownloadFailure.checksum);
      expect(filesIn(models), isEmpty);
    });

    test('CA15 : un fichier faux n\'est jamais à son nom définitif, même un '
        'instant', () async {
      final transport = FakeModelTransport([
        FakeModelTransport.ok(chunksOf(wrongBytes, 100)),
      ]);
      final downloader = build(transport);
      final log = StateLog(downloader);
      addTearDown(log.close);
      var finalSeen = false;
      final watcher = Timer.periodic(const Duration(milliseconds: 1), (_) {
        if (File('${models.path}/${testSource.fileName}').existsSync()) {
          finalSeen = true;
        }
      });
      addTearDown(watcher.cancel);

      await downloader.start();
      await log.settled();

      expect(finalSeen, isFalse);
      expect(log.states.whereType<ModelReady>(), isEmpty);
    });

    test('CA16 : plus d\'octets que la taille de la source : le transfert '
        's\'arrête aussitôt, échec « fichier faux »', () async {
      final body = CountingBody(chunkCount: 200, chunkSize: 100);
      final transport = FakeModelTransport([
        TransportResponse(statusCode: 200, body: body.stream),
      ]);

      final log = await download(build(transport));

      expectFailure(log, DownloadFailure.checksum);
      // 1 000 octets attendus : le 11e morceau dépasse. Une marge pour la
      // lecture anticipée, pas pour les 200 morceaux.
      expect(body.produced, lessThanOrEqualTo(15));
      expect(filesIn(models), isEmpty);
    });

    test('CA16 : un seul octet de trop suffit', () async {
      final transport = FakeModelTransport([
        FakeModelTransport.ok([
          ...chunksOf(modelBytes, 100),
          [1],
        ]),
      ]);

      final log = await download(build(transport));

      expectFailure(log, DownloadFailure.checksum);
      expect(filesIn(models), isEmpty);
    });

    test('CA16 : moins d\'octets avant la fermeture : échec « réseau », '
        'fichier temporaire effacé', () async {
      final transport = FakeModelTransport([
        FakeModelTransport.ok(chunksOf(modelBytes.sublist(0, 999), 100)),
      ]);

      final log = await download(build(transport));

      expectFailure(log, DownloadFailure.network);
      expect(filesIn(models), isEmpty);
    });
  });

  group('échecs (CA17, CA18, CA20)', () {
    // Ajoutés après la revue IA de la PR #22 : stockage plein en cours de route,
    // et renommage impossible.
    test('CA18 : une écriture qui échoue en cours de transfert est un échec '
        '« place », sans fichier laissé', () async {
      final transport = FakeModelTransport([
        FakeModelTransport.ok(chunksOf(modelBytes, 100)),
      ]);
      final downloader = HttpModelDownloader(
        transport: transport,
        folder: models,
        source: testSource,
        idleTimeout: const Duration(seconds: 5),
        openPart: (file) async =>
            _FullDisk(await file.open(mode: FileMode.write), failAfter: 3),
      );

      final log = await download(downloader);

      expectFailure(log, DownloadFailure.storage);
      expect(filesIn(models), isEmpty);
    });

    test('CA18 : un renommage impossible est un échec « place »', () async {
      // Le nom définitif est déjà pris par un dossier : le renommage échoue.
      Directory('${models.path}/${testSource.fileName}')
          .createSync(recursive: true);
      final transport = FakeModelTransport([
        FakeModelTransport.ok(chunksOf(modelBytes, 100)),
      ]);

      final log = await download(build(transport));

      expectFailure(log, DownloadFailure.storage);
      expect(filesIn(models), isNot(contains(partName)));
    });

    test('CA17 : la connexion échoue : échec « réseau »', () async {
      final transport = FakeModelTransport([
        const SocketException('Connection refused'),
      ]);

      final log = await download(build(transport));

      expectFailure(log, DownloadFailure.network);
      expect(filesIn(models), isEmpty);
    });

    test('CA17 : une connexion refusée tout de suite n\'attend pas le délai '
        'de 30 secondes', () async {
      final transport = FakeModelTransport([
        const SocketException('Connection refused'),
      ]);
      final downloader = HttpModelDownloader(
        transport: transport,
        folder: models,
        source: testSource,
      );
      final log = StateLog(downloader);
      addTearDown(log.close);
      final started = DateTime.now();

      await downloader.start();
      await log.settled();

      expectFailure(log, DownloadFailure.network);
      expect(
        DateTime.now().difference(started),
        lessThan(const Duration(seconds: 3)),
      );
    });

    // Ajouté après le contrôle par mutation : une erreur HTTP qui renverrait
    // exactement les octets attendus ne doit pas être prise pour le modèle.
    test(
      'CA17 : une réponse 404 avec les bons octets reste un échec « réseau »',
      () async {
        final transport = FakeModelTransport([
          TransportResponse(
            statusCode: 404,
            body: Stream.fromIterable(chunksOf(modelBytes, 100)),
          ),
        ]);

        final log = await download(build(transport));

        expectFailure(log, DownloadFailure.network);
        expect(filesIn(models), isEmpty);
      },
    );

    // Ajouté après la revue de sécurité : une taille annoncée différente arrête
    // tout de suite, sans consommer le forfait.
    test('CA16 : un Content-Length différent de la taille attendue est refusé '
        'sans lire le corps', () async {
      final body = CountingBody(chunkCount: 10, chunkSize: 100);
      final transport = FakeModelTransport([
        TransportResponse(
          statusCode: 200,
          contentLength: modelBytes.length * 2,
          body: body.stream,
        ),
      ]);

      final log = await download(build(transport));

      expectFailure(log, DownloadFailure.checksum);
      expect(body.produced, lessThanOrEqualTo(1));
      expect(filesIn(models), isEmpty);
    });

    test(
      'CA16 : un Content-Length égal à la taille attendue est accepté',
      () async {
        final transport = FakeModelTransport([
          TransportResponse(
            statusCode: 200,
            contentLength: modelBytes.length,
            body: Stream.fromIterable(goodBody()),
          ),
        ]);

        final log = await download(build(transport));

        expect(log.last, isA<ModelReady>());
      },
    );

    for (final code in [204, 206, 400, 403, 404, 416, 500, 503]) {
      test('CA17 : une réponse $code est un échec « réseau »', () async {
        final transport = FakeModelTransport([FakeModelTransport.status(code)]);

        final log = await download(build(transport));

        expectFailure(log, DownloadFailure.network);
        expect(filesIn(models), isEmpty);
      });
    }

    test(
      'CA17 : un 404 après une redirection admise est un échec « réseau »',
      () async {
        final transport = FakeModelTransport([
          FakeModelTransport.redirect('https://cdn-lfs.huggingface.co/x'),
          FakeModelTransport.status(404),
        ]);

        final log = await download(build(transport));

        expectFailure(log, DownloadFailure.network);
      },
    );

    test('CA17 : la connexion se coupe en cours de route : échec « réseau », '
        'fichier temporaire effacé', () async {
      final transport = FakeModelTransport([
        FakeModelTransport.ok(
          chunksOf(modelBytes.sublist(0, 500), 100),
          error: const SocketException('Connection reset by peer'),
        ),
      ]);

      final log = await download(build(transport));

      expectFailure(log, DownloadFailure.network);
      expect(filesIn(models), isEmpty);
    });

    test('CA17 : aucun octet pendant le délai : échec « réseau », fichier '
        'temporaire effacé', () async {
      final gate = GatedResponse();
      final transport = FakeModelTransport([gate.response]);
      final downloader = build(
        transport,
        idleTimeout: const Duration(milliseconds: 200),
      );
      final log = StateLog(downloader);
      addTearDown(log.close);
      unawaited(downloader.start());
      await eventually(() => transport.calls.isNotEmpty, reason: 'requête');
      gate.controller.add(modelBytes.sublist(0, 200));

      await log.settled();

      expectFailure(log, DownloadFailure.network);
      expect(filesIn(models), isEmpty);
      expect(gate.cancelled, isTrue);
    });

    test(
      'CA17 : aucun octet reçu du tout pendant le délai : échec « réseau »',
      () async {
        final gate = GatedResponse();
        final transport = FakeModelTransport([gate.response]);
        final downloader = build(
          transport,
          idleTimeout: const Duration(milliseconds: 200),
        );
        final log = StateLog(downloader);
        addTearDown(log.close);

        unawaited(downloader.start());
        await log.settled();

        expectFailure(log, DownloadFailure.network);
      },
    );

    test('CA17 : le délai court depuis le dernier octet, pas depuis le début : '
        'un téléchargement lent mais régulier réussit', () async {
      final gate = GatedResponse();
      final transport = FakeModelTransport([gate.response]);
      final downloader = build(
        transport,
        idleTimeout: const Duration(milliseconds: 400),
      );
      final log = StateLog(downloader);
      addTearDown(log.close);
      unawaited(downloader.start());
      await eventually(() => transport.calls.isNotEmpty, reason: 'requête');

      // 5 morceaux espacés de 150 ms : 750 ms au total, plus que le délai.
      for (final chunk in chunksOf(modelBytes, 200)) {
        gate.controller.add(chunk);
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      await gate.controller.close();
      await log.settled();

      expect(log.last, isA<ModelReady>());
    });

    test('CA18 : dossier inaccessible : échec « place », « absent », aucun '
        'fichier', () async {
      // Un fichier ordinaire à la place du dossier parent : créer `models/` échoue.
      final blocker = File('${tmp.path}/blocked')..writeAsStringSync('x');
      final downloader = HttpModelDownloader(
        transport: FakeModelTransport([FakeModelTransport.ok(goodBody())]),
        folder: Directory('${blocker.path}/models'),
        source: testSource,
      );
      final log = StateLog(downloader);
      addTearDown(log.close);

      await downloader.start();
      await log.settled();

      expectFailure(log, DownloadFailure.storage);
      expect(downloader.current, isA<ModelAbsent>());
      expect(blocker.readAsStringSync(), 'x');
    });

    test(
      'CA18 : une erreur du transport n\'est pas une erreur de stockage',
      () async {
        final transport = FakeModelTransport([
          const SocketException('Network is unreachable'),
        ]);

        final log = await download(build(transport));

        expect(
          (log.last as ModelAbsent).failure,
          isNot(DownloadFailure.storage),
        );
      },
    );

    test('CA20 : après un échec, un nouveau start() repart de zéro, sans '
        'en-tête Range, et réussit', () async {
      final transport = FakeModelTransport([
        FakeModelTransport.ok(
          chunksOf(modelBytes.sublist(0, 600), 100),
          error: const SocketException('Connection reset by peer'),
        ),
        FakeModelTransport.ok(goodBody()),
      ]);
      final downloader = build(transport);
      final log = StateLog(downloader);
      addTearDown(log.close);
      await downloader.start();
      await log.settled();
      expectFailure(log, DownloadFailure.network);

      await downloader.start();
      await eventually(
        () => downloader.current is ModelReady,
        reason: 'second téléchargement terminé',
      );

      expect(transport.calls, hasLength(2));
      expect(transport.calls[1].url, testSource.url);
      expect(transport.calls[1].headers, transport.calls[0].headers);
      expect(
        transport.calls[1].headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('range')),
      );
      expect(
        File('${models.path}/${testSource.fileName}').readAsBytesSync(),
        modelBytes,
      );
      expect(filesIn(models), [testSource.fileName]);
    });

    test('CA20 : après un échec « fichier faux », un nouveau start() réussit '
        'avec un fichier juste', () async {
      final transport = FakeModelTransport([
        FakeModelTransport.ok(chunksOf(wrongBytes, 100)),
        FakeModelTransport.ok(goodBody()),
      ]);
      final downloader = build(transport);
      final log = StateLog(downloader);
      addTearDown(log.close);
      await downloader.start();
      await log.settled();
      expectFailure(log, DownloadFailure.checksum);

      await downloader.start();
      await eventually(
        () => downloader.current is ModelReady,
        reason: 'second téléchargement terminé',
      );

      expect(
        File('${models.path}/${testSource.fileName}').readAsBytesSync(),
        modelBytes,
      );
    });
  });

  group('démarrage (CA21, CA22)', () {
    void write(String name, List<int> bytes) {
      models.createSync(recursive: true);
      File('${models.path}/$name').writeAsBytesSync(bytes);
    }

    test('CA21 : un fichier temporaire laissé est effacé, le modèle est '
        '« absent », aucune requête ne part', () async {
      write(partName, modelBytes.sublist(0, 400));
      final transport = FakeModelTransport();
      final downloader = build(transport);

      await downloader.checkAtStartup();

      expect(filesIn(models), isEmpty);
      expect(downloader.current, isA<ModelAbsent>());
      expect((downloader.current as ModelAbsent).failure, isNull);
      expect(transport.calls, isEmpty);
    });

    test('CA21 : le fichier temporaire est effacé même complet : il n\'est '
        'jamais repris', () async {
      write(partName, modelBytes);
      final downloader = build(FakeModelTransport());

      await downloader.checkAtStartup();

      expect(filesIn(models), isEmpty);
      expect(downloader.current, isA<ModelAbsent>());
    });

    test('CA21 : aucun téléchargement ne reprend de lui-même après le '
        'démarrage', () async {
      write(partName, modelBytes.sublist(0, 400));
      final transport = FakeModelTransport([FakeModelTransport.ok(goodBody())]);
      final downloader = build(transport);
      final log = StateLog(downloader);
      addTearDown(log.close);

      await downloader.checkAtStartup();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(transport.calls, isEmpty);
      expect(log.states.whereType<ModelDownloading>(), isEmpty);
    });

    test('CA21 : sans dossier du tout, le modèle est « absent » et rien n\'est '
        'créé de travers', () async {
      final downloader = build(FakeModelTransport());

      await downloader.checkAtStartup();

      expect(downloader.current, isA<ModelAbsent>());
      expect(filesIn(models), isEmpty);
    });

    test('CA22 : le fichier définitif de la bonne taille donne « prêt », avec '
        'son chemin', () async {
      write(testSource.fileName, modelBytes);
      final downloader = build(FakeModelTransport());

      await downloader.checkAtStartup();

      expect(downloader.current, isA<ModelReady>());
      expect(
        (downloader.current as ModelReady).path,
        '${models.path}/${testSource.fileName}',
      );
      expect(
        File('${models.path}/${testSource.fileName}').existsSync(),
        isTrue,
      );
    });

    test('CA22 : l\'empreinte n\'est pas recalculée au démarrage : un fichier '
        'de la bonne taille mais d\'un autre contenu reste « prêt »', () async {
      write(testSource.fileName, wrongBytes);
      final downloader = build(FakeModelTransport());

      await downloader.checkAtStartup();

      expect(downloader.current, isA<ModelReady>());
      expect(
        File('${models.path}/${testSource.fileName}').existsSync(),
        isTrue,
      );
    });

    test('CA22 : un fichier définitif trop court est effacé, le modèle est '
        '« absent »', () async {
      write(testSource.fileName, modelBytes.sublist(0, 999));
      final downloader = build(FakeModelTransport());

      await downloader.checkAtStartup();

      expect(downloader.current, isA<ModelAbsent>());
      expect(filesIn(models), isEmpty);
    });

    test('CA22 : un fichier définitif trop long est effacé, le modèle est '
        '« absent »', () async {
      write(testSource.fileName, [...modelBytes, 0]);
      final downloader = build(FakeModelTransport());

      await downloader.checkAtStartup();

      expect(downloader.current, isA<ModelAbsent>());
      expect(filesIn(models), isEmpty);
    });

    test('CA22 : un fichier définitif vide est effacé', () async {
      write(testSource.fileName, const []);
      final downloader = build(FakeModelTransport());

      await downloader.checkAtStartup();

      expect(downloader.current, isA<ModelAbsent>());
      expect(filesIn(models), isEmpty);
    });

    test('CA22 : fichier définitif juste et fichier temporaire : le premier '
        'reste, le second est effacé', () async {
      write(testSource.fileName, modelBytes);
      write(partName, modelBytes.sublist(0, 10));
      final downloader = build(FakeModelTransport());

      await downloader.checkAtStartup();

      expect(downloader.current, isA<ModelReady>());
      expect(filesIn(models), [testSource.fileName]);
    });

    test(
      'CA22 : le démarrage est observable : watch() donne l\'état déduit',
      () async {
        write(testSource.fileName, modelBytes);
        final downloader = build(FakeModelTransport());

        await downloader.checkAtStartup();

        expect(await downloader.watch().first, isA<ModelReady>());
      },
    );
  });

  group('après un échec de chargement (CA32)', () {
    Future<HttpModelDownloader> readyWith(List<int> bytes) async {
      models.createSync(recursive: true);
      File('${models.path}/${testSource.fileName}').writeAsBytesSync(bytes);
      final downloader = build(FakeModelTransport());
      await downloader.checkAtStartup();
      expect(downloader.current, isA<ModelReady>());
      return downloader;
    }

    test('CA32 : empreinte fausse : le fichier est effacé et le modèle '
        'repasse à « absent »', () async {
      final downloader = await readyWith(wrongBytes);

      await downloader.verifyAfterLoadFailure();

      expect(downloader.current, isA<ModelAbsent>());
      expect(filesIn(models), isEmpty);
    });

    test('CA32 : empreinte juste : le modèle reste « prêt », le fichier est '
        'gardé', () async {
      final downloader = await readyWith(modelBytes);

      await downloader.verifyAfterLoadFailure();

      expect(downloader.current, isA<ModelReady>());
      expect(
        File('${models.path}/${testSource.fileName}').readAsBytesSync(),
        modelBytes,
      );
    });

    test(
      'CA32 : après l\'effacement, la personne peut retélécharger',
      () async {
        final downloader = await readyWith(wrongBytes);
        await downloader.verifyAfterLoadFailure();
        final transport = FakeModelTransport([
          FakeModelTransport.ok(goodBody()),
        ]);
        final again = build(transport);

        await again.checkAtStartup();
        await again.start();
        await eventually(
          () => again.current is ModelReady,
          reason: 'retéléchargement terminé',
        );

        expect(transport.calls, hasLength(1));
        expect(
          File('${models.path}/${testSource.fileName}').readAsBytesSync(),
          modelBytes,
        );
      },
    );
  });

  group('suppression (lot H, deleteModel)', () {
    test('deleteModel efface le modèle prêt et ramène à « absent »', () async {
      models.createSync(recursive: true);
      File('${models.path}/${testSource.fileName}')
          .writeAsBytesSync(modelBytes);
      final downloader = build(FakeModelTransport());
      await downloader.checkAtStartup();

      await downloader.deleteModel();

      expect(downloader.current, isA<ModelAbsent>());
      expect(filesIn(models), isEmpty);
    });
  });
}

/// Transport dont la réponse arrive quand le test le décide.
class _PendingTransport implements ModelTransport {
  _PendingTransport(this.response);

  final Future<TransportResponse> response;
  int calls = 0;

  @override
  Future<TransportResponse> get(Uri url, Map<String, String> headers) {
    calls++;
    return response;
  }
}

/// Fichier qui refuse d'écrire après [failAfter] écritures : stockage plein.
class _FullDisk implements RandomAccessFile {
  _FullDisk(this._inner, {required this.failAfter});

  final RandomAccessFile _inner;
  final int failAfter;
  int _writes = 0;

  @override
  Future<RandomAccessFile> writeFrom(
    List<int> buffer, [
    int start = 0,
    int? end,
  ]) async {
    if (++_writes > failAfter) {
      throw const FileSystemException('No space left on device');
    }
    await _inner.writeFrom(buffer, start, end);
    return this;
  }

  @override
  Future<void> close() => _inner.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
