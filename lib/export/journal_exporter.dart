import 'dart:convert';

import '../analysis/mood_analyzer.dart';
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
  }) {
    final sorted = [...entries]
      ..sort((a, b) {
        final byTime = a.createdAt.compareTo(b.createdAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    final document = <String, Object?>{
      'formatVersion': exportFormatVersion,
      'app': 'Tidemark',
      'exportedAt': formatWithOffset(
        exportedAt.toUtc(),
        exportedAt.timeZoneOffset,
      ),
      'settings': {'lowMoodSensitivity': sensitivity.name},
      'entries': [for (final entry in sorted) _entry(entry)],
    };
    // Échappement de jsonEncode : seuls `"`, `\` et les caractères de contrôle ;
    // les caractères non ASCII sont écrits tels quels (spec 005, « Format »).
    return '${const JsonEncoder.withIndent('  ').convert(document)}\n';
  }

  static Map<String, Object?> _entry(Entry entry) {
    final tags = [...entry.tags]
      ..sort((a, b) {
        // `emotion` avant `theme`, puis par unités de code UTF-16.
        final byKind = _kindOrder(a.kind).compareTo(_kindOrder(b.kind));
        return byKind != 0 ? byKind : a.label.compareTo(b.label);
      });
    return {
      'createdAt': formatWithOffset(entry.createdAt.toUtc(), entry.utcOffset),
      'mood': entry.mood,
      'moodLabel': moodLabel(entry.mood),
      'text': entry.text,
      'analysisStatus': entry.analysisStatus.name,
      'tags': [
        for (final tag in tags) {'kind': tag.kind.name, 'label': tag.label},
      ],
    };
  }

  static int _kindOrder(TagKind kind) => switch (kind) {
    TagKind.emotion => 0,
    TagKind.theme => 1,
  };
}

String _two(int value) => value.toString().padLeft(2, '0');

/// [utc] écrit en ISO 8601 à la seconde, à l'heure locale du décalage [offset],
/// suivi de ce décalage (`2026-10-14T21:40:00+02:00`).
String formatWithOffset(DateTime utc, Duration offset) {
  final local = utc.toUtc().add(offset);
  final minutes = offset.inMinutes;
  final sign = minutes < 0 ? '-' : '+';
  final abs = minutes.abs();
  return '${local.year.toString().padLeft(4, '0')}-${_two(local.month)}-'
      '${_two(local.day)}T${_two(local.hour)}:${_two(local.minute)}:'
      '${_two(local.second)}$sign${_two(abs ~/ 60)}:${_two(abs % 60)}';
}

/// Nom du fichier d'export pour un export commencé à [start] (heure locale) :
/// `tidemark-export-AAAA-MM-JJ-HHMM.json`.
String exportFileName(DateTime start) =>
    'tidemark-export-${start.year.toString().padLeft(4, '0')}-'
    '${_two(start.month)}-${_two(start.day)}-'
    '${_two(start.hour)}${_two(start.minute)}.json';
