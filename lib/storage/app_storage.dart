import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../wipe/journal_wiper.dart';
import 'database_key.dart';

/// Emplacements de l'app et lieu de la clé, injectables pour les tests (spec 005).
class AppStorage {
  AppStorage({
    required this.folder,
    required this.cacheFolder,
    required this.keyStore,
    this.files = const IoWipeFiles(),
  });

  /// Emplacements du téléphone : Application Support/tidemark (exclu des
  /// sauvegardes) et le cache de l'app (`getTemporaryDirectory` : Library/Caches
  /// sur iOS, `cacheDir` sur Android, où `share_plus` fait sa copie) ; clé dans le
  /// trousseau ou le Keystore.
  static Future<AppStorage> system() async => AppStorage(
    folder: Directory(
      '${(await getApplicationSupportDirectory()).path}/tidemark',
    ),
    cacheFolder: await getTemporaryDirectory(),
    keyStore: SecureKeyStore(),
  );

  /// Dossier de la base, des marqueurs et du modèle.
  final Directory folder;

  /// Cache de l'app (non sauvegardé) : dossiers temporaires d'export.
  final Directory cacheFolder;

  final KeyStore keyStore;
  final WipeFiles files;
}
