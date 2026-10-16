import 'package:flutter/services.dart';

import 'model_downloader.dart';
import 'model_source.dart';

/// Canal du SHA-256 natif (ADR-004, option F) : `ios/Runner/ModelHashChannel.swift`
/// et `android/app/src/main/kotlin/dev/tidemark/tidemark/MainActivity.kt`.
const modelHashChannel = MethodChannel('dev.tidemark/model_hash');

/// SHA-256 d'un fichier par la bibliothèque du système (CryptoKit sur iOS,
/// `MessageDigest` sur Android), avec [fallback] en repli (ADR-004, option F).
/// Environ dix fois plus rapide que le calcul Dart sur un Mac M3 (CryptoKit) ;
/// iPhone et Android non mesurés.
///
/// La réponse native n'est crue que pour dire « oui » : seule une empreinte égale
/// à [expected] est rendue telle quelle. Toute autre réponse (empreinte différente
/// ou mal formée, erreur du canal, délai dépassé, canal absent dans les tests ou
/// sur ordinateur) passe par [fallback] : un défaut du code natif ne fait jamais
/// accepter un fichier modifié ni effacer un bon modèle, et une erreur de lecture
/// du repli remonte telle quelle au téléchargeur (fichier illisible = empreinte
/// fausse, spec 003).
class SystemFileHasher {
  const SystemFileHasher({
    required this.expected,
    this.channel = modelHashChannel,
    this.fallback = sha256OfFile,
    this.nativeTimeout = const Duration(seconds: 60),
  });

  /// Empreinte attendue, en hexadécimal minuscule. Elle n'est jamais envoyée au
  /// canal : le natif ne peut pas la renvoyer sans l'avoir calculée.
  final String expected;
  final MethodChannel channel;

  /// Calcul Dart, dans un isolat ([sha256OfFile] par défaut).
  final Future<String> Function(String path) fallback;

  /// Délai au-delà duquel un canal muet passe la main au repli : large, pour ne
  /// pas abandonner un calcul natif lent mais réel.
  final Duration nativeTimeout;

  Future<String> call(String path) async {
    Object? digest;
    try {
      digest = await channel
          .invokeMethod<Object>('sha256OfFile', {'path': path})
          .timeout(nativeTimeout);
    } catch (_) {
      // PlatformException, MissingPluginException, délai dépassé ou autre : le
      // repli décide.
      digest = null;
    }
    // Comparaison exacte : une réponse mal formée ou d'un autre type ne vaut
    // jamais l'empreinte attendue.
    if (digest == expected) return expected;
    return fallback(path);
  }
}

/// Calcul d'empreinte du modèle de l'app (`qwenModelSource`), passé à
/// `HttpModelDownloader` par `openJournal` (`lib/main.dart`), qui vérifie contre
/// la même source.
Future<String> modelSha256OfFile(String path) =>
    SystemFileHasher(expected: qwenModelSource.sha256).call(path);
