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
class IoModelTransport implements ModelTransport {
  IoModelTransport();

  @override
  Future<TransportResponse> get(Uri url, Map<String, String> headers) =>
      throw UnimplementedError();
}
