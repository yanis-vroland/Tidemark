import 'dart:async';

import 'package:tidemark/model/model_transport.dart';

/// Une requête reçue par [FakeModelTransport].
typedef TransportCall = ({Uri url, Map<String, String> headers});

/// Transport factice : rend, dans l'ordre, les réponses de [responses] (ou lève
/// l'erreur donnée à la place d'une réponse). Aucune requête vers Internet.
class FakeModelTransport implements ModelTransport {
  FakeModelTransport([List<Object>? responses]) : responses = responses ?? [];

  /// [TransportResponse] ou erreur à lever, consommées dans l'ordre.
  final List<Object> responses;
  final List<TransportCall> calls = [];

  @override
  Future<TransportResponse> get(Uri url, Map<String, String> headers) async {
    calls.add((url: url, headers: Map.unmodifiable(headers)));
    if (responses.isEmpty) throw StateError('Aucune réponse prévue pour $url');
    final next = responses.removeAt(0);
    if (next is TransportResponse) return next;
    throw next;
  }

  /// Réponse 200 qui envoie [chunks], puis se ferme ; [error] interrompt le flux
  /// après les morceaux.
  static TransportResponse ok(List<List<int>> chunks, {Object? error}) =>
      TransportResponse(
        statusCode: 200,
        body: Stream.fromIterable(chunks).transform(
          StreamTransformer.fromHandlers(
            handleDone: (sink) {
              if (error != null) sink.addError(error);
              sink.close();
            },
          ),
        ),
      );

  /// Réponse de redirection vers [location].
  static TransportResponse redirect(String location, {int status = 302}) =>
      TransportResponse(
        statusCode: status,
        location: location,
        body: const Stream.empty(),
      );

  /// Réponse d'erreur HTTP.
  static TransportResponse status(int code) =>
      TransportResponse(statusCode: code, body: const Stream.empty());
}
