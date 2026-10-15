import 'dart:convert';

import 'mood_analyzer.dart';
import 'tag_vocabulary.dart';

/// Validation de la sortie du modèle (spec 004, « Validation de la sortie », RM9) :
/// code Dart pur, qui ne lève jamais d'exception.
abstract final class TagOutputParser {
  /// [Tagged] si [raw] est conforme, [Untagged] sinon.
  static AnalysisResult parse(String raw) {
    try {
      // Un objet JSON seul, espaces autour ignorés : `jsonDecode` refuse tout
      // texte avant ou après.
      final decoded = jsonDecode(raw.trim());
      if (decoded is! Map<String, dynamic>) return const Untagged();
      if (decoded.length != 2 ||
          !decoded.containsKey('emotions') ||
          !decoded.containsKey('themes')) {
        return const Untagged();
      }
      final emotions = _labels(decoded['emotions'], TagVocabulary.emotions);
      final themes = _labels(decoded['themes'], TagVocabulary.themes);
      if (emotions == null || themes == null) return const Untagged();
      if (emotions.length > TagVocabulary.maxEmotions ||
          themes.length > TagVocabulary.maxThemes ||
          emotions.isEmpty && themes.isEmpty) {
        return const Untagged();
      }
      return Tagged([
        for (final label in emotions) Tag(label, TagKind.emotion),
        for (final label in themes) Tag(label, TagKind.theme),
      ]);
    } catch (_) {
      return const Untagged();
    }
  }

  /// Étiquettes d'un tableau, sans doublon (le premier est gardé), toutes dans
  /// [allowed] à l'identique ; `null` si la valeur n'est pas conforme.
  static List<String>? _labels(Object? value, List<String> allowed) {
    if (value is! List) return null;
    final labels = <String>[];
    for (final item in value) {
      if (item is! String || !allowed.contains(item)) return null;
      if (!labels.contains(item)) labels.add(item);
    }
    return labels;
  }
}
