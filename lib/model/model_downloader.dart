import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'model_source.dart';
import 'model_state.dart';
import 'model_transport.dart';

/// Téléchargement et état du modèle local (spec 003).
abstract interface class ModelDownloader {
  /// État actuel, puis chaque changement.
  Stream<ModelState> watch();

  /// État actuel.
  ModelState get current;

  /// Lance le téléchargement, sur un appui de la personne (RM11) ; sans effet si un
  /// téléchargement tourne déjà (CA10). Se termine avec le téléchargement.
  Future<void> start();

  /// Arrête le transfert et efface le fichier temporaire (CA13).
  Future<void> cancel();

  /// État au démarrage, déduit des fichiers (CA21, CA22).
  Future<void> checkAtStartup();

  /// Efface le modèle (suppression totale, lot H).
  Future<void> deleteModel();

  /// Recalcule l'empreinte d'un modèle `ready` qui n'a pas pu être chargé (CA32).
  Future<void> verifyAfterLoadFailure();
}

/// Statuts HTTP de redirection suivis par le téléchargeur (CA8).
const _redirects = {301, 302, 303, 307, 308};

/// Nombre maximal de redirections suivies (spec 003, « Hôtes »).
const _maxRedirects = 5;

/// Seuls en-têtes demandés au transport (spec 003, « Requête », CA7).
const _headers = {'User-Agent': 'Tidemark', 'Accept-Encoding': 'identity'};

/// Échec d'une étape du téléchargement, avec sa cause.
class _Failure implements Exception {
  const _Failure(this.cause);
  final DownloadFailure cause;
}

/// Reçoit l'empreinte calculée au fil de l'eau.
class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

/// [ModelDownloader] sur un [ModelTransport], dans [folder]
/// (Application Support/tidemark/models/).
class HttpModelDownloader implements ModelDownloader {
  HttpModelDownloader({
    required this.transport,
    required this.folder,
    ModelSource? source,
    this.idleTimeout = const Duration(seconds: 30),
  }) : source = source ?? qwenModelSource;

  final ModelTransport transport;
  final Directory folder;
  final ModelSource source;

  /// Délai sans octet reçu qui vaut échec réseau (CA17).
  final Duration idleTimeout;

  ModelState _state = const ModelAbsent();
  final _changes = StreamController<ModelState>.broadcast();
  Future<void>? _running;
  StreamIterator<List<int>>? _body;
  bool _cancelled = false;

  File get _finalFile => File('${folder.path}/${source.fileName}');
  File get _partFile => File('${folder.path}/${source.fileName}.part');

  void _set(ModelState state) {
    _state = state;
    _changes.add(state);
  }

  @override
  ModelState get current => _state;

  @override
  Stream<ModelState> watch() async* {
    yield _state;
    yield* _changes.stream;
  }

  @override
  Future<void> start() {
    // Un seul téléchargement à la fois (CA10) ; rien à faire si le modèle est prêt.
    final running = _running;
    if (running != null) return running;
    if (_state is ModelReady) return Future.value();
    _cancelled = false;
    _set(ModelDownloading(receivedBytes: 0, totalBytes: source.sizeBytes));
    final run = _download().whenComplete(() => _running = null);
    _running = run;
    return run;
  }

  Future<void> _download() async {
    RandomAccessFile? file;
    try {
      final response = await _follow();
      try {
        await folder.create(recursive: true);
        file = await _partFile.open(mode: FileMode.write);
      } on FileSystemException {
        throw const _Failure(DownloadFailure.storage);
      }
      final digest = _DigestSink();
      final hasher = sha256.startChunkedConversion(digest);
      var received = 0;
      var percent = 0;
      final body = StreamIterator(response.body.timeout(idleTimeout));
      _body = body;
      try {
        while (await body.moveNext()) {
          final chunk = body.current;
          received += chunk.length;
          // Plus d'octets qu'annoncé : ce n'est pas le bon fichier (CA16).
          if (received > source.sizeBytes) {
            throw const _Failure(DownloadFailure.checksum);
          }
          try {
            await file.writeFrom(chunk);
          } on FileSystemException {
            throw const _Failure(DownloadFailure.storage);
          }
          hasher.add(chunk);
          final now = received * 100 ~/ source.sizeBytes;
          if (now != percent || received == source.sizeBytes) {
            percent = now;
            _set(
              ModelDownloading(
                receivedBytes: received,
                totalBytes: source.sizeBytes,
              ),
            );
          }
        }
      } on _Failure {
        rethrow;
      } catch (_) {
        // Connexion coupée ou délai de 30 s sans octet (CA17).
        if (!_cancelled) throw const _Failure(DownloadFailure.network);
      } finally {
        await body.cancel();
        _body = null;
      }
      if (_cancelled) {
        await file.close();
        file = null;
        await _deletePart();
        _set(const ModelAbsent());
        return;
      }
      // Moins d'octets qu'annoncé : connexion fermée trop tôt (CA16).
      if (received != source.sizeBytes) {
        throw const _Failure(DownloadFailure.network);
      }
      _set(
        ModelDownloading(
          receivedBytes: received,
          totalBytes: source.sizeBytes,
          verifying: true,
        ),
      );
      hasher.close();
      await file.close();
      file = null;
      if (digest.value.toString() != source.sha256) {
        throw const _Failure(DownloadFailure.checksum);
      }
      await _partFile.rename(_finalFile.path);
      _set(ModelReady(path: _finalFile.path));
    } on _Failure catch (failure) {
      await file?.close();
      await _deletePart();
      _set(ModelAbsent(failure: _cancelled ? null : failure.cause));
    } catch (_) {
      await file?.close();
      await _deletePart();
      _set(ModelAbsent(failure: _cancelled ? null : DownloadFailure.network));
    }
  }

  /// Suit les redirections, en ne contactant que les hôtes admis (CA8, RM30).
  Future<TransportResponse> _follow() async {
    var url = source.url;
    for (var hops = 0; ; hops++) {
      final TransportResponse response;
      try {
        response = await transport.get(url, _headers).timeout(idleTimeout);
      } catch (_) {
        throw const _Failure(DownloadFailure.network);
      }
      if (_redirects.contains(response.statusCode)) {
        final location = response.location;
        if (hops >= _maxRedirects || location == null) {
          throw const _Failure(DownloadFailure.network);
        }
        final next = url.resolve(location);
        // Aucune requête vers une adresse refusée.
        if (!ModelSource.isAllowed(next)) {
          throw const _Failure(DownloadFailure.network);
        }
        url = next;
        continue;
      }
      if (response.statusCode != 200) {
        throw const _Failure(DownloadFailure.network);
      }
      return response;
    }
  }

  Future<void> _deletePart() async {
    try {
      if (await _partFile.exists()) await _partFile.delete();
    } on FileSystemException {
      // Rien d'autre à faire : il sera effacé au démarrage suivant (CA21).
    }
  }

  @override
  Future<void> cancel() async {
    final running = _running;
    if (running == null) return;
    _cancelled = true;
    await _body?.cancel();
    await running;
  }

  @override
  Future<void> checkAtStartup() async {
    try {
      await _deletePart();
      final file = _finalFile;
      if (await file.exists()) {
        if (await file.length() == source.sizeBytes) {
          _set(ModelReady(path: file.path));
          return;
        }
        await file.delete();
      }
    } on FileSystemException {
      // Fichier illisible : le modèle est absent, il pourra être retéléchargé.
    }
    _set(const ModelAbsent());
  }

  @override
  Future<void> deleteModel() async {
    await cancel();
    try {
      if (await _finalFile.exists()) await _finalFile.delete();
    } on FileSystemException {
      // Laissé au démarrage suivant : sa taille ou son empreinte décideront.
    }
    await _deletePart();
    _set(const ModelAbsent());
  }

  @override
  Future<void> verifyAfterLoadFailure() async {
    if (_state is! ModelReady) return;
    final file = _finalFile;
    try {
      final digest = await sha256.bind(file.openRead()).first;
      if (digest.toString() == source.sha256) return;
      await file.delete();
    } on FileSystemException {
      // Illisible : traité comme une empreinte fausse.
      try {
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        return;
      }
    }
    _set(const ModelAbsent());
  }
}
