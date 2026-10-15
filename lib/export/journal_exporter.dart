import '../distress/distress_detector.dart';
import '../entries/entry.dart';

/// Version du format du fichier d'export (spec 005, « Format ») : tout changement
/// du format l'augmente de 1.
const exportFormatVersion = 1;

/// Construit le fichier d'export (glossaire : `JournalExporter`, spec 005), en
/// code Dart pur, sans Flutter ni base.
class JournalExporter {
  const JournalExporter();

  /// JSON du format version 1 : [entries] dans n'importe quel ordre (elles sont
  /// triées de la plus ancienne à la plus récente), le degré [sensitivity] et la
  /// date de l'export [exportedAt], écrite avec son propre décalage
  /// (`DateTime.timeZoneOffset` : `+00:00` pour une date UTC).
  String buildExport({
    required List<Entry> entries,
    required LowMoodSensitivity sensitivity,
    required DateTime exportedAt,
  }) => throw UnimplementedError();
}

/// [utc] écrit en ISO 8601 à la seconde, à l'heure locale du décalage [offset],
/// suivi de ce décalage (`2026-10-14T21:40:00+02:00`).
String formatWithOffset(DateTime utc, Duration offset) =>
    throw UnimplementedError();

/// Nom du fichier d'export pour un export commencé à [start] (heure locale) :
/// `tidemark-export-AAAA-MM-JJ-HHMM.json`.
String exportFileName(DateTime start) => throw UnimplementedError();
