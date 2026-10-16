import 'dart:io';

import '../storage/database_key.dart';
import 'journal_wiper.dart';

/// Marqueur d'installation (ADR-002, RM45, spec 005) : sans marqueur `installed`
/// dans [folder], une nouvelle installation (aucun `journal.db`) efface toute clé
/// restée dans [keyStore] ; une base présente garde sa clé. Puis le marqueur est
/// créé. N'échoue jamais : une erreur laisse le marqueur absent, et tout est retenté
/// au démarrage suivant (CA32).
Future<void> checkInstallMarker({
  required Directory folder,
  required KeyStore keyStore,
  WipeFiles files = const IoWipeFiles(),
}) async {
  try {
    final marker = File('${folder.path}/installed');
    if (await marker.exists()) return;
    // Base présente sans marqueur : installation antérieure à la spec 005 ; lui
    // retirer sa clé la rendrait illisible.
    if (!await File('${folder.path}/journal.db').exists()) {
      await keyStore.deleteAll();
    }
    await files.createFile(marker);
  } catch (_) {
    // Retenté au démarrage suivant ; l'app s'ouvre normalement (CA32).
  }
}
