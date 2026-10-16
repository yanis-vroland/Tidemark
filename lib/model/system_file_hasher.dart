import 'package:flutter/services.dart';

import 'model_downloader.dart';
import 'model_source.dart';

/// Canal du SHA-256 natif (ADR-004, option F) : `ios/Runner/ModelHashChannel.swift`
/// et `android/app/src/main/kotlin/dev/tidemark/tidemark/MainActivity.kt`.
const modelHashChannel = MethodChannel('dev.tidemark/model_hash');

/// SHA-256 d'un fichier par la bibliothèque du système (CryptoKit sur iOS,
/// `MessageDigest` sur Android), environ dix fois plus rapide que le calcul Dart
/// (ADR-004, option F), avec [fallback] en repli.
///
/// La réponse native n'est crue que pour dire « oui » : seule une empreinte égale
/// à [expected] est rendue telle quelle. Toute autre réponse (empreinte différente
/// ou mal formée, erreur du canal, canal absent dans les tests ou sur ordinateur)
/// passe par [fallback] : un défaut du code natif ne fait jamais effacer un bon
/// modèle, et une erreur de lecture du repli remonte telle quelle au
/// téléchargeur (fichier illisible = empreinte fausse, spec 003).
class SystemFileHasher {
  const SystemFileHasher({
    required this.expected,
    this.channel = modelHashChannel,
    this.fallback = sha256OfFile,
  });

  /// Empreinte attendue, en hexadécimal minuscule.
  final String expected;
  final MethodChannel channel;

  /// Calcul Dart, dans un isolat ([sha256OfFile] par défaut).
  final Future<String> Function(String path) fallback;

  Future<String> call(String path) async {
    Object? digest;
    try {
      digest = await channel.invokeMethod<Object>('sha256OfFile', {
        'path': path,
      });
    } catch (_) {
      // PlatformException, MissingPluginException ou autre : le repli décide.
      digest = null;
    }
    // Comparaison exacte : une réponse mal formée ou d'un autre type ne vaut
    // jamais l'empreinte attendue.
    if (digest == expected) return expected;
    return fallback(path);
  }
}

/// Calcul d'empreinte du modèle de l'app, passé à `HttpModelDownloader` par
/// `openJournal` (`lib/main.dart`).
Future<String> modelSha256OfFile(String path) =>
    SystemFileHasher(expected: qwenModelSource.sha256).call(path);
