import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

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

  /// Vérifie l'empreinte du modèle avant sa première lecture par le moteur, une
  /// fois par lancement (spec 003, CA34 à CA36, ADR-004) : `true` si le
  /// chargement peut avoir lieu.
  Future<bool> verifyBeforeFirstLoad();
}

/// SHA-256 du fichier [path], en hexadécimal (spec 003, CA36).
Future<String> sha256OfFile(String path) async {
  // Squelette : à remplacer par un calcul dans un isolat.
  return sha256.convert(File(path).readAsBytesSync()).toString();
}

/// Statuts HTTP de redirection suivis par le téléchargeur (CA8).
const _redirects = {301, 302, 303, 307, 308};

/// Nombre maximal de redirections suivies (spec 003, « Hôtes »).
const _maxRedirects = 5;

/// Seuls en-têtes demandés au transport (spec 003, « Requête », CA7).
const _headers = {'User-Agent': 'Tidemark', 'Accept-Encoding': 'identity'};

/// Téléchargement annulé par la personne, à n'importe quelle étape.
class _Cancelled implements Exception {
  const _Cancelled();
}

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
    @visibleForTesting Future<RandomAccessFile> Function(File file)? openPart,
    this.hashFile = sha256OfFile,
  }) : source = source ?? qwenModelSource,
       _openPart = openPart ?? ((file) => file.open(mode: FileMode.write));

  final ModelTransport transport;
  final Directory folder;
  final ModelSource source;

  /// Délai sans octet reçu qui vaut échec réseau (CA17).
  final Duration idleTimeout;

  /// Calcul du SHA-256 d'un fichier, en hexadécimal ; [sha256OfFile] par défaut,
  /// remplacé dans les tests pour compter les calculs ou simuler une erreur.
  final Future<String> Function(String path) hashFile;

  /// Ouverture du fichier `.part` ; injectable pour simuler un stockage plein.
  final Future<RandomAccessFile> Function(File file) _openPart;

  ModelState _state = const ModelAbsent();
  final _changes = StreamController<ModelState>.broadcast();
  Future<void>? _running;
  StreamIterator<List<int>>? _body;
  bool _cancelled = false;

  /// Complété par [cancel] : interrompt l'attente d'une réponse du transport.
  Completer<void> _cancelSignal = Completer<void>();

  File get _finalFile => File('${folder.path}/${source.fileName}');
  File get _partFile => File('${folder.path}/${source.fileName}.part');

  void _set(ModelState state) {
    _state = state;
    _changes.add(state);
  }

  @override
  ModelState get current => _state;

  @override
  Stream<ModelState> watch() => Stream.multi((controller) {
    // Abonnement et état courant dans le même tour : aucun changement perdu.
    controller.add(_state);
    final changes = _changes.stream.listen(
      controller.add,
      onError: controller.addError,
    );
    controller.onCancel = changes.cancel;
  });

  @override
  Future<void> start() {
    // Un seul téléchargement à la fois (CA10) ; rien à faire si le modèle est prêt.
    final running = _running;
    if (running != null) return running;
    if (_state is ModelReady) return Future.value();
    _cancelled = false;
    _cancelSignal = Completer<void>();
    _set(ModelDownloading(receivedBytes: 0, totalBytes: source.sizeBytes));
    final run = _download().whenComplete(() => _running = null);
    _running = run;
    return run;
  }

  Future<void> _download() async {
    RandomAccessFile? file;
    try {
      final response = await _follow();
      _throwIfCancelled();
      try {
        await folder.create(recursive: true);
        file = await _openPart(_partFile);
      } on FileSystemException {
        throw const _Failure(DownloadFailure.storage);
      }
      _throwIfCancelled();
      final digest = _DigestSink();
      final hasher = sha256.startChunkedConversion(digest);
      var received = 0;
      var percent = 0;
      final body = StreamIterator(response.body.timeout(idleTimeout));
      _body = body;
      try {
        while (await body.moveNext()) {
          if (_cancelled) break;
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
      _throwIfCancelled();
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
      // Annulation confirmée pendant la vérification : rien n'est gardé (CA13).
      _throwIfCancelled();
      try {
        await _partFile.rename(_finalFile.path);
      } on FileSystemException {
        throw const _Failure(DownloadFailure.storage);
      }
      _set(ModelReady(path: _finalFile.path));
    } on _Cancelled {
      await file?.close();
      await _deletePart();
      _set(const ModelAbsent());
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

  void _throwIfCancelled() {
    if (_cancelled) throw const _Cancelled();
  }

  /// Une requête au transport, interrompue par [cancel] ou par le délai.
  Future<TransportResponse> _get(Uri url) async {
    final request = transport.get(url, _headers);
    try {
      return await Future.any([
        request,
        _cancelSignal.future.then<TransportResponse>(
          (_) => throw const _Cancelled(),
        ),
      ]).timeout(idleTimeout);
    } on _Cancelled {
      // Réponse arrivée trop tard : sa connexion est refermée sans être lue.
      unawaited(request.then((r) => _discard(r)).catchError((Object _) {}));
      rethrow;
    } catch (_) {
      unawaited(request.then((r) => _discard(r)).catchError((Object _) {}));
      throw const _Failure(DownloadFailure.network);
    }
  }

  /// Referme la connexion d'une réponse qui ne sera pas lue.
  Future<void> _discard(TransportResponse response) =>
      response.body.listen(null).cancel();

  /// Suit les redirections, en ne contactant que les hôtes admis (CA8, RM30).
  Future<TransportResponse> _follow() async {
    var url = source.url;
    for (var hops = 0; ; hops++) {
      final response = await _get(url);
      if (_cancelled) {
        await _discard(response);
        throw const _Cancelled();
      }
      if (_redirects.contains(response.statusCode)) {
        await _discard(response);
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
        await _discard(response);
        throw const _Failure(DownloadFailure.network);
      }
      // Taille annoncée différente : ce n'est pas le bon fichier, inutile de
      // consommer le forfait pour le découvrir.
      final length = response.contentLength;
      if (length != null && length != source.sizeBytes) {
        await _discard(response);
        throw const _Failure(DownloadFailure.checksum);
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
    if (!_cancelSignal.isCompleted) _cancelSignal.complete();
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

  @override
  Future<bool> verifyBeforeFirstLoad() async {
    // Squelette : comportement d'avant l'ADR-004, la taille seule.
    return _state is ModelReady;
  }
}
