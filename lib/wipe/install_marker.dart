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
}) => throw UnimplementedError();
