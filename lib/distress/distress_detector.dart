import '../entries/entry.dart';
import 'distress_terms.dart';

/// Sensibilité aux humeurs basses (glossaire : `LowMoodSensitivity`, RM25, RM29) :
/// la série de [entryCount] entrées toutes à 1, tenant en [days] jours au plus, qui
/// ouvre l'écran d'aide. Aucun degré ne désactive le garde-fou.
enum LowMoodSensitivity {
  high(entryCount: 2, days: 3),
  normal(entryCount: 3, days: 7),
  low(entryCount: 5, days: 14);

  const LowMoodSensitivity({required this.entryCount, required this.days});

  final int entryCount;
  final int days;
}

/// Lettres accentuées du français (et voisines) et leur forme sans accent.
const _unaccented = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a', //
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i',
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
  'ÿ': 'y', 'ý': 'y',
  'ñ': 'n',
  'œ': 'oe', 'æ': 'ae',
};

final _combiningMarks = RegExp('[\u0300-\u036f]');
final _nonWord = RegExp('[^a-z0-9]+');

/// Règles déterministes de détection de la détresse (spec 002, RM6, RM25). Code pur,
/// sans état ni accès à la base.
class DistressDetector {
  const DistressDetector();

  /// Forme normalisée de [text] : minuscules, sans accents, tout ce qui n'est ni
  /// lettre ni chiffre remplacé par une espace, espaces réduites.
  static String normalize(String text) {
    final lower = text.toLowerCase().replaceAll(_combiningMarks, '');
    final buffer = StringBuffer();
    for (final char in lower.split('')) {
      buffer.write(_unaccented[char] ?? char);
    }
    return buffer.toString().replaceAll(_nonWord, ' ').trim();
  }

  /// Vrai si [text] contient une expression de la liste, en mots entiers.
  bool detectInText(String text) {
    final padded = ' ${normalize(text)} ';
    return distressExpressions.any((e) => padded.contains(' $e '));
  }

  /// Vrai si les `sensitivity.entryCount` premières entrées de [latest] (de la plus
  /// récente à la plus ancienne) sont toutes à 1 et tiennent en
  /// `sensitivity.days` × 24 heures.
  bool detectLowMoodSeries(List<Entry> latest, LowMoodSensitivity sensitivity) {
    if (latest.length < sensitivity.entryCount) return false;
    final series = latest.take(sensitivity.entryCount).toList();
    if (series.any((e) => e.mood != 1)) return false;
    final span = series.first.createdAt.difference(series.last.createdAt).abs();
    return span <= Duration(days: sensitivity.days);
  }
}
