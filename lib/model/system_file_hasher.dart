import 'package:flutter/services.dart';

import 'model_downloader.dart';
import 'model_source.dart';

/// Canal du SHA-256 natif (ADR-004, option F) : `ios/Runner/ModelHashChannel.swift`
/// et `android/app/src/main/kotlin/dev/tidemark/tidemark/MainActivity.kt`.
const modelHashChannel = MethodChannel('dev.tidemark/model_hash');

/// SHA-256 d'un fichier par la bibliothèque du système, avec [fallback] en repli.
class SystemFileHasher {
  const SystemFileHasher({
    required this.expected,
    this.channel = modelHashChannel,
    this.fallback = sha256OfFile,
  });

  final String expected;
  final MethodChannel channel;
  final Future<String> Function(String path) fallback;

  Future<String> call(String path) => throw UnimplementedError();
}

/// Calcul d'empreinte du modèle de l'app.
Future<String> modelSha256OfFile(String path) =>
    SystemFileHasher(expected: qwenModelSource.sha256).call(path);
