// Données fictives et outils communs aux tests du téléchargement du modèle
// (spec 003). Aucun réseau : les octets sont inventés pour les tests.
import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:tidemark/model/model_downloader.dart';
import 'package:tidemark/model/model_source.dart';
import 'package:tidemark/model/model_state.dart';
import 'package:tidemark/model/model_transport.dart';

/// Contenu fictif du « modèle » de test : 1 000 octets.
final modelBytes = List<int>.generate(1000, (i) => (i * 7 + 3) % 256);

/// Même taille, autre contenu : l'empreinte diffère.
final wrongBytes = List<int>.generate(1000, (i) => (i * 11 + 5) % 256);

/// Petite source de test : empreinte et taille calculées sur [modelBytes].
final testSource = ModelSource(
  url: Uri.parse(
    'https://huggingface.co/Qwen/test-model/resolve/'
    '0123456789abcdef0123456789abcdef01234567/test-model.gguf',
  ),
  sha256: sha256.convert(modelBytes).toString(),
  sizeBytes: modelBytes.length,
  fileName: 'test-model.gguf',
);

/// Nom du fichier temporaire du téléchargement (spec 003, « Pendant le
/// téléchargement »).
const partName = 'test-model.gguf.part';

/// Découpe [bytes] en morceaux de [size] octets au plus.
List<List<int>> chunksOf(List<int> bytes, int size) => [
  for (var i = 0; i < bytes.length; i += size)
    bytes.sublist(i, i + size > bytes.length ? bytes.length : i + size),
];

/// Noms des fichiers présents dans [folder] (vide si le dossier n'existe pas).
List<String> filesIn(Directory folder) => folder.existsSync()
    ? folder
          .listSync()
          .map((e) => e.uri.pathSegments.lastWhere((s) => s.isNotEmpty))
          .toList()
    : <String>[];

/// Attend, sur la vraie boucle d'événements, que [condition] devienne vraie.
Future<void> eventually(
  bool Function() condition, {
  String reason = 'condition jamais atteinte',
  Duration timeout = const Duration(seconds: 5),
}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      throw StateError('Délai dépassé : $reason');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// Garde la suite des états émis par un téléchargeur.
class StateLog {
  StateLog(ModelDownloader downloader) {
    _subscription = downloader.watch().listen(states.add);
  }

  final List<ModelState> states = [];
  late final StreamSubscription<ModelState> _subscription;

  ModelState get last => states.last;

  /// États « en téléchargement » émis, dans l'ordre.
  List<ModelDownloading> get downloading =>
      states.whereType<ModelDownloading>().toList();

  /// Attend la fin d'un téléchargement : passé par `downloading` puis revenu à
  /// `absent` ou `ready`, ou échec émis sans être passé par `downloading`.
  Future<void> settled() => eventually(
    () =>
        states.isNotEmpty &&
        ((states.any((s) => s is ModelDownloading) &&
                states.last is! ModelDownloading) ||
            (states.last is ModelAbsent &&
                (states.last as ModelAbsent).failure != null)),
    reason: 'le téléchargement ne se termine pas : $states',
  );

  Future<void> close() => _subscription.cancel();
}

/// Réponse 200 dont le corps est alimenté à la main par le test ; [cancelled]
/// devient vrai quand le téléchargeur cesse d'écouter.
class GatedResponse {
  GatedResponse() {
    controller = StreamController<List<int>>(onCancel: () => cancelled = true);
  }

  late final StreamController<List<int>> controller;
  bool cancelled = false;

  TransportResponse get response =>
      TransportResponse(statusCode: 200, body: controller.stream);
}

/// Corps qui produit [chunkCount] morceaux de [chunkSize] octets, un par demande du
/// lecteur ; [produced] compte les morceaux réellement produits, pour vérifier qu'un
/// téléchargeur cesse de lire dès qu'il le doit.
class CountingBody {
  CountingBody({required this.chunkCount, required this.chunkSize});

  final int chunkCount;
  final int chunkSize;
  int produced = 0;

  Stream<List<int>> get stream async* {
    for (var i = 0; i < chunkCount; i++) {
      produced++;
      yield List<int>.filled(chunkSize, 1);
      // Laisse la main : un lecteur qui a annulé n'en demande pas davantage.
      await Future<void>.delayed(Duration.zero);
    }
  }
}
