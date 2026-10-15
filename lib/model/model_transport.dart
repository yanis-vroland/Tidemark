import 'dart:io';

/// Réponse brute d'une requête du téléchargement : statut, `Location` et corps.
class TransportResponse {
  const TransportResponse({
    required this.statusCode,
    required this.body,
    this.location,
  });

  final int statusCode;

  /// En-tête `Location` d'une redirection, tel quel (relatif ou absolu).
  final String? location;

  final Stream<List<int>> body;
}

/// Transport du téléchargement du modèle (spec 003) : une requête `GET`, sans
/// suivre les redirections (le téléchargeur les vérifie lui-même, CA8).
abstract interface class ModelTransport {
  Future<TransportResponse> get(Uri url, Map<String, String> headers);
}

/// [ModelTransport] sur `dart:io` : seul code réseau de l'app (RM1, CA25, CA31).
/// Pas de redirection suivie, pas de décompression, pas de cookie, et aucun
/// en-tête par défaut de `dart:io` (`User-Agent: Dart/…`, `Accept-Encoding: gzip`).
class IoModelTransport implements ModelTransport {
  IoModelTransport()
    : _client = HttpClient()
        ..autoUncompress = false
        ..userAgent = null;

  final HttpClient _client;

  @override
  Future<TransportResponse> get(Uri url, Map<String, String> headers) async {
    final request = await _client.getUrl(url);
    request.followRedirects = false;
    request.headers.removeAll(HttpHeaders.acceptEncodingHeader);
    headers.forEach(request.headers.set);
    final response = await request.close();
    return TransportResponse(
      statusCode: response.statusCode,
      location: response.headers.value(HttpHeaders.locationHeader),
      body: response,
    );
  }
}
