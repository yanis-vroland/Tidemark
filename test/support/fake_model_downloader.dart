import 'dart:async';

import 'package:tidemark/model/model_downloader.dart';
import 'package:tidemark/model/model_state.dart';

/// Modèle déjà prêt : cadre neutre des tests des specs 001 et 002, où la
/// proposition du modèle (spec 003, CA1) ne doit pas s'ouvrir.
const readyModel = ModelReady(path: 'tidemark/models/modele.gguf');

/// Téléchargeur factice pour les écrans : l'état se règle par [emit], les appels
/// sont comptés. Aucun réseau.
class FakeModelDownloader implements ModelDownloader {
  FakeModelDownloader([ModelState initial = const ModelAbsent()])
    : _current = initial;

  ModelState _current;
  final _changes = StreamController<ModelState>.broadcast();

  int startCalls = 0;
  int cancelCalls = 0;
  int checkAtStartupCalls = 0;
  int deleteCalls = 0;
  int verifyCalls = 0;

  /// Si non nul, [checkAtStartup] lève cette erreur.
  Object? checkAtStartupError;

  /// Change l'état, comme le ferait le vrai téléchargeur.
  void emit(ModelState state) {
    _current = state;
    _changes.add(state);
  }

  @override
  ModelState get current => _current;

  @override
  Stream<ModelState> watch() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<void> start() async {
    startCalls++;
    if (_current is! ModelDownloading) {
      emit(ModelDownloading(receivedBytes: 0, totalBytes: 1117320736));
    }
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    emit(const ModelAbsent());
  }

  @override
  Future<void> checkAtStartup() async {
    checkAtStartupCalls++;
    if (checkAtStartupError != null) throw checkAtStartupError!;
  }

  @override
  Future<void> deleteModel() async {
    deleteCalls++;
    emit(const ModelAbsent());
  }

  @override
  Future<void> verifyAfterLoadFailure() async => verifyCalls++;
}
