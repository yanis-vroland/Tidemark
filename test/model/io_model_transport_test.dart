// IoModelTransport (spec 003, CA31) : seul test autorisé à ouvrir une connexion,
// vers un serveur lancé par le test sur la boucle locale (127.0.0.1). Rien ne sort du
// poste.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/model/model_transport.dart';

/// Ce que le serveur a reçu.
class Received {
  Received(this.method, this.path, this.headers, this.body);

  final String method;
  final String path;

  /// Noms en minuscules, valeurs jointes.
  final Map<String, String> headers;
  final List<int> body;
}

/// En-têtes que le téléchargeur demande, et seulement eux (spec 003, « Requête »).
const requested = {'User-Agent': 'Tidemark', 'Accept-Encoding': 'identity'};

/// Liste exacte des en-têtes admis sur le fil : les deux demandés, `host`, et
/// `content-length: 0` que `dart:io` peut ajouter. Tout autre en-tête (`cookie`,
/// `authorization`, `range`, identifiant…) fait échouer le test.
const allowedOnTheWire = {
  'host',
  'user-agent',
  'accept-encoding',
  'content-length',
};

void main() {
  late HttpServer server;
  late List<Received> received;
  late Uri base;

  setUp(() async {
    received = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = Uri.parse('http://127.0.0.1:${server.port}');
    server.listen((request) async {
      final headers = <String, String>{};
      request.headers.forEach((name, values) {
        headers[name.toLowerCase()] = values.join(', ');
      });
      final body = await request.fold<List<int>>([], (a, b) => [...a, ...b]);
      received.add(Received(request.method, request.uri.path, headers, body));
      final response = request.response;
      switch (request.uri.path) {
        case '/redirect':
          response.statusCode = HttpStatus.found;
          response.headers.set(HttpHeaders.locationHeader, '/file');
        case '/relative':
          response.statusCode = HttpStatus.temporaryRedirect;
          response.headers.set(
            HttpHeaders.locationHeader,
            'https://cas-bridge.xethub.hf.co/a?b=c',
          );
        case '/missing':
          response.statusCode = HttpStatus.notFound;
        case '/cookie':
          response.headers.add(HttpHeaders.setCookieHeader, 'session=abc');
          response.write('cookie set');
        case '/gzip':
          response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
          response.add(gzip.encode(utf8.encode('contenu compressé')));
        default:
          response.write('hello');
      }
      await response.close();
    });
  });

  tearDown(() => server.close(force: true));

  Future<TransportResponse> get(String path) =>
      IoModelTransport().get(base.resolve(path), requested);

  Future<List<int>> bodyOf(TransportResponse r) =>
      r.body.fold<List<int>>([], (a, b) => [...a, ...b]);

  test('CA31 : le serveur reçoit un GET', () async {
    await bodyOf(await get('/file'));

    expect(received, hasLength(1));
    expect(received.single.method, 'GET');
    expect(received.single.path, '/file');
  });

  test('CA31 : la requête n\'a pas de corps', () async {
    await bodyOf(await get('/file'));

    expect(received.single.body, isEmpty);
    final length = received.single.headers['content-length'];
    expect(
      length == null || length == '0',
      isTrue,
      reason: 'content-length: $length',
    );
    expect(received.single.headers['transfer-encoding'], isNull);
  });

  test('CA31 : les en-têtes sont exactement la liste fixée : host, '
      'user-agent: Tidemark, accept-encoding: identity', () async {
    await bodyOf(await get('/file'));

    final headers = received.single.headers;
    expect(headers['host'], '127.0.0.1:${server.port}');
    expect(headers['user-agent'], 'Tidemark');
    expect(headers['accept-encoding'], 'identity');
    expect(
      headers.keys.toSet().difference(allowedOnTheWire),
      isEmpty,
      reason: 'en-têtes inattendus sur le fil : ${headers.keys}',
    );
  });

  test('CA31 : le User-Agent est « Tidemark », sans version ni identifiant, '
      'et ne contient pas celui de dart:io', () async {
    await bodyOf(await get('/file'));

    final agent = received.single.headers['user-agent']!;
    expect(agent, 'Tidemark');
    expect(agent, isNot(contains('Dart')));
  });

  test('CA31 : ni cookie, ni Authorization, ni Range', () async {
    await bodyOf(await get('/file'));

    final headers = received.single.headers;
    expect(headers, isNot(contains('cookie')));
    expect(headers, isNot(contains('authorization')));
    expect(headers, isNot(contains('range')));
    expect(headers, isNot(contains('referer')));
  });

  test('CA31 : un cookie posé par le serveur n\'est pas renvoyé à la demande '
      'suivante', () async {
    await bodyOf(await get('/cookie'));
    await bodyOf(await get('/file'));

    expect(received, hasLength(2));
    expect(received.last.headers, isNot(contains('cookie')));
  });

  test('CA31 : une réponse 302 est rendue telle quelle, avec son Location, '
      'sans être suivie', () async {
    final response = await get('/redirect');
    await bodyOf(response);

    expect(response.statusCode, 302);
    expect(response.location, '/file');
    expect(received, hasLength(1));
    expect(received.single.path, '/redirect');
  });

  test(
    'CA31 : un Location absolu est rendu tel quel, sans être suivi',
    () async {
      final response = await get('/relative');
      await bodyOf(response);

      expect(response.statusCode, 307);
      expect(response.location, 'https://cas-bridge.xethub.hf.co/a?b=c');
      expect(received, hasLength(1));
    },
  );

  test('CA31 : une réponse 200 donne son statut et ses octets', () async {
    final response = await get('/file');

    expect(response.statusCode, 200);
    expect(response.location, isNull);
    expect(utf8.decode(await bodyOf(response)), 'hello');
  });

  test('CA31 : une réponse d\'erreur est rendue, pas levée', () async {
    final response = await get('/missing');
    await bodyOf(response);

    expect(response.statusCode, 404);
  });

  test('CA31 : le corps n\'est pas décompressé : le téléchargeur reçoit les '
      'octets du serveur', () async {
    final response = await get('/gzip');

    expect(
      await bodyOf(response),
      gzip.encode(utf8.encode('contenu compressé')),
    );
  });

  test(
    'CA31 : serveur injoignable : la demande échoue tout de suite',
    () async {
      final port = server.port;
      await server.close(force: true);

      await expectLater(
        IoModelTransport().get(
          Uri.parse('http://127.0.0.1:$port/file'),
          requested,
        ),
        throwsA(isA<SocketException>()),
      );
    },
  );
}
