import 'dart:io';

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
  /// téléchargement tourne déjà (CA10).
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

  @override
  Stream<ModelState> watch() => throw UnimplementedError();

  @override
  ModelState get current => throw UnimplementedError();

  @override
  Future<void> start() => throw UnimplementedError();

  @override
  Future<void> cancel() => throw UnimplementedError();

  @override
  Future<void> checkAtStartup() => throw UnimplementedError();

  @override
  Future<void> deleteModel() => throw UnimplementedError();

  @override
  Future<void> verifyAfterLoadFailure() => throw UnimplementedError();
}
