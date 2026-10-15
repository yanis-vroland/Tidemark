import 'dart:io';

import '../entries/entry_repository.dart';
import '../settings/settings_repository.dart';
import 'journal_exporter.dart';
import 'share_sheet.dart';

/// Dossier du fichier d'export, dans le cache de l'app (spec 005, « Données »).
const exportFolderName = 'tidemark-export';

/// Dossier où `share_plus` copie le fichier sur Android, dans le cache de l'app.
const sharePlusFolderName = 'share_plus';

/// Type du fichier d'export.
const exportMimeType = 'application/json';

/// Dossiers temporaires d'export sous le cache de l'app [cache] :
/// `tidemark-export/` et `share_plus/`.
List<Directory> exportTemporaryFolders(Directory cache) => [
  Directory('${cache.path}/$exportFolderName'),
  Directory('${cache.path}/$sharePlusFolderName'),
];

/// Vide les dossiers temporaires d'export (CA10) ; un dossier absent compte comme
/// vidé. Lève une exception si un dossier ne peut pas être effacé.
Future<void> purgeExportTemporaryFiles(Directory cache) =>
    throw UnimplementedError();

/// L'export n'a pas abouti (CA11) : aucun fichier n'a été partagé, aucun fichier
/// temporaire ne reste.
class ExportFailure implements Exception {
  const ExportFailure(this.cause);

  final Object cause;

  @override
  String toString() => 'ExportFailure($cause)';
}

/// Export du journal, sur l'appui de la personne (spec 005, règles 1 et 2).
class JournalExport {
  JournalExport({
    required this.entries,
    required this.settings,
    required this.shareSheet,
    required this.cacheFolder,
    DateTime Function()? clock,
    this.exporter = const JournalExporter(),
  }) : clock = clock ?? DateTime.now;

  /// Entrées exportées ; leur nombre décide aussi si l'export est possible (CA12).
  final EntryRepository entries;
  final SettingsRepository settings;
  final ShareSheet shareSheet;

  /// Cache de l'app : parent des dossiers temporaires d'export.
  final Directory cacheFolder;

  /// Date et heure locales du début de l'export.
  final DateTime Function() clock;
  final JournalExporter exporter;

  /// Purge, lit, écrit le fichier, ouvre la feuille de partage, puis efface le
  /// fichier, que la personne ait partagé ou annulé. Lève [ExportFailure] sur
  /// toute erreur, après avoir effacé les fichiers temporaires.
  Future<void> run() => throw UnimplementedError();
}
