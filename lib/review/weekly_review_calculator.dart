import '../analysis/mood_analyzer.dart';
import '../analysis/tag_vocabulary.dart';
import '../distress/distress_detector.dart';
import '../entries/entry.dart';
import 'local_week.dart';
import 'weekly_review.dart';

/// Nombre minimal d'entrées d'une semaine pour avoir un bilan (RM21).
const minEntriesForReview = 3;

/// Nombre maximal d'étiquettes fréquentes (spec 006).
const maxTopTags = 3;

/// Calculateur du bilan (glossaire : `WeeklyReviewCalculator`, RM10, RM50) : code
/// Dart pur, sans état ni accès à la base, ni modèle.
class WeeklyReviewCalculator {
  const WeeklyReviewCalculator({this.detector = const DistressDetector()});

  /// Revérifie le texte des entrées (semaine sensible, critère 3).
  final DistressDetector detector;

  /// Bilan de [week]. [entries] contient toutes les entrées du journal ; le
  /// calculateur garde celles de la semaine et de la semaine précédente.
  /// [tagsByEntry] donne les étiquettes de chaque entrée, par identifiant.
  WeeklyReview compute({
    required LocalWeek week,
    required List<Entry> entries,
    required Map<int, List<Tag>> tagsByEntry,
  }) {
    final current = [
      for (final e in entries)
        if (weekOfEntry(e) == week) e,
    ];
    if (current.length < minEntriesForReview) {
      return InsufficientWeek(week: week, entryCount: current.length);
    }
    final previousWeek = week.previous;
    final previous = [
      for (final e in entries)
        if (weekOfEntry(e) == previousWeek) e,
    ];

    final sum = current.fold(0, (s, e) => s + e.mood);
    final count = current.length;
    final tenths = _roundedTenths(sum, count);

    final moodCounts = List<int>.filled(5, 0);
    for (final e in current) {
      moodCounts[e.mood - 1]++;
    }

    final notedDays = {
      for (final e in current) e.localCreatedAt.weekday,
    }.toList()..sort();

    final topTags = _topTags(current, tagsByEntry);

    final comparison = previous.length < minEntriesForReview
        ? null
        : WeekComparison(
            averageMoodTenths: _roundedTenths(
              previous.fold(0, (s, e) => s + e.mood),
              previous.length,
            ),
            entryCount: previous.length,
          );

    final trend = comparison == null
        ? ReviewTrend.none
        : tenths > comparison.averageMoodTenths
        ? ReviewTrend.up
        : tenths < comparison.averageMoodTenths
        ? ReviewTrend.down
        : ReviewTrend.stable;

    // Libellé depuis la moyenne exacte, jamais depuis les dixièmes arrondis
    // (CA35) : unité = (2 × somme + nombre) ÷ (2 × nombre).
    final unit = (2 * sum + count) ~/ (2 * count);

    return ComputedWeek(
      week: week,
      entryCount: count,
      averageMoodTenths: tenths,
      moodCounts: List.unmodifiable(moodCounts),
      notedDays: List.unmodifiable(notedDays),
      topTags: List.unmodifiable(topTags),
      comparison: comparison,
      isSensitive: current.any(_isSensitive),
      facts: ReviewFacts(
        averageMoodLabel: moodLabel(unit),
        regularity: _regularity(notedDays.length),
        topTagLabels: List.unmodifiable([for (final t in topTags) t.tag.label]),
        trend: trend,
      ),
    );
  }

  /// Semaine sensible (RM52) : humeur 1 ; texte « non analysé » (la détresse est
  /// la seule cause de ce statut avec un texte) ; texte détecté de nouveau.
  bool _isSensitive(Entry entry) {
    if (entry.mood == 1) return true;
    final text = entry.text;
    if (text == null) return false;
    if (entry.analysisStatus == AnalysisStatus.skipped) return true;
    return detector.detectInText(text);
  }
}

/// Moyenne en dixièmes, la moitié vers le haut, en entiers :
/// (20 × somme + nombre) ÷ (2 × nombre).
int _roundedTenths(int sum, int count) => (20 * sum + count) ~/ (2 * count);

WeekRegularity _regularity(int days) => switch (days) {
  7 => WeekRegularity.everyDay,
  >= 5 => WeekRegularity.mostDays,
  >= 3 => WeekRegularity.someDays,
  _ => WeekRegularity.fewDays,
};

/// Au plus [maxTopTags] étiquettes, comptées sur les entrées « étiquetées », par
/// nombre décroissant puis libellé.
List<TagCount> _topTags(List<Entry> entries, Map<int, List<Tag>> tagsByEntry) {
  final counts = <Tag, int>{};
  for (final e in entries) {
    if (e.analysisStatus != AnalysisStatus.tagged) continue;
    // Une étiquette compte une fois par entrée.
    for (final tag in {...?tagsByEntry[e.id]}) {
      // Défense en profondeur (RM51) : seule la liste fermée atteint le modèle.
      if (!_vocabulary.contains(tag.label)) continue;
      counts[tag] = (counts[tag] ?? 0) + 1;
    }
  }
  final sorted =
      [
        for (final MapEntry(:key, :value) in counts.entries)
          TagCount(key, value),
      ]..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        if (byCount != 0) return byCount;
        // Ordre alphabétique sans tenir compte des accents (« études » avant
        // « famille »).
        final byLabel = DistressDetector.normalize(a.tag.label)
            .compareTo(DistressDetector.normalize(b.tag.label));
        return byLabel != 0 ? byLabel : a.tag.label.compareTo(b.tag.label);
      });
  return sorted.take(maxTopTags).toList();
}

final _vocabulary = {...TagVocabulary.emotions, ...TagVocabulary.themes};

/// Semaine du jour local de saisie de [entry] (spec 001), pas du jour actuel.
LocalWeek weekOfEntry(Entry entry) =>
    LocalWeek.containing(entry.localCreatedAt);
