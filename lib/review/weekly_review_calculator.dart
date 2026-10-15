import '../analysis/mood_analyzer.dart';
import '../distress/distress_detector.dart';
import '../entries/entry.dart';
import 'local_week.dart';
import 'weekly_review.dart';

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
  }) => throw UnimplementedError();
}

/// Semaine du jour local de saisie de [entry] (spec 001), pas du jour actuel.
LocalWeek weekOfEntry(Entry entry) => throw UnimplementedError();
