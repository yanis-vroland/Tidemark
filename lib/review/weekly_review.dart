/// Bilan de la semaine et faits transmis au rédacteur (spec 006, « Données »).
library;

import '../analysis/mood_analyzer.dart';
import 'local_week.dart';

/// Régularité de la semaine, en mots (glossaire : `WeekRegularity`).
enum WeekRegularity {
  /// 7 jours notés.
  everyDay,

  /// 5 ou 6 jours notés.
  mostDays,

  /// 3 ou 4 jours notés.
  someDays,

  /// 1 ou 2 jours notés.
  fewDays,
}

/// Tendance par rapport à la semaine précédente (glossaire : `ReviewTrend`).
enum ReviewTrend {
  up,
  down,
  stable,

  /// Pas de semaine précédente comparable (moins de 3 entrées).
  none,
}

/// Faits du bilan, seuls transmis au rédacteur (RM51) : **aucun champ numérique**.
class ReviewFacts {
  const ReviewFacts({
    required this.averageMoodLabel,
    required this.regularity,
    required this.topTagLabels,
    required this.trend,
  });

  /// Libellé de RM3 de la moyenne exacte arrondie à l'unité (« Bien »).
  final String averageMoodLabel;

  final WeekRegularity regularity;

  /// Au plus 3 libellés de la liste fermée, dans l'ordre des chiffres.
  final List<String> topTagLabels;

  final ReviewTrend trend;

  /// Forme sérialisée, envoyée au modèle comme message : des mots, sans chiffre.
  String toPrompt() {
    final regularityText = switch (regularity) {
      WeekRegularity.everyDay => 'notée chaque jour',
      WeekRegularity.mostDays => 'notée la plupart des jours',
      WeekRegularity.someDays => 'notée certains jours',
      WeekRegularity.fewDays => 'notée peu de jours',
    };
    final trendText = switch (trend) {
      ReviewTrend.up => 'humeur en hausse',
      ReviewTrend.down => 'humeur en baisse',
      ReviewTrend.stable => 'humeur stable',
      ReviewTrend.none => 'pas de comparaison possible',
    };
    final tags = topTagLabels.isEmpty ? 'aucune' : topTagLabels.join(', ');
    return 'Humeur moyenne de la semaine : $averageMoodLabel.\n'
        'Régularité : semaine $regularityText.\n'
        'Étiquettes fréquentes : $tags.\n'
        'Par rapport à la semaine précédente : $trendText.';
  }

  @override
  bool operator ==(Object other) =>
      other is ReviewFacts &&
      other.averageMoodLabel == averageMoodLabel &&
      other.regularity == regularity &&
      other.trend == trend &&
      _sameList(other.topTagLabels, topTagLabels);

  @override
  int get hashCode => Object.hash(
    averageMoodLabel,
    regularity,
    trend,
    Object.hashAll(topTagLabels),
  );

  @override
  String toString() => 'ReviewFacts(${toPrompt()})';
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Étiquette fréquente et nombre d'entrées « étiquetées » qui la portent.
class TagCount {
  const TagCount(this.tag, this.count);

  final Tag tag;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is TagCount && other.tag == tag && other.count == count;

  @override
  int get hashCode => Object.hash(tag, count);

  @override
  String toString() => 'TagCount(${tag.label}, $count)';
}

/// Chiffres de la semaine précédente, pour l'évolution (CA14).
class WeekComparison {
  const WeekComparison({
    required this.averageMoodTenths,
    required this.entryCount,
  });

  final int averageMoodTenths;
  final int entryCount;
}

/// Bilan d'une semaine (glossaire : `WeeklyReview`).
sealed class WeeklyReview {
  const WeeklyReview({required this.week, required this.entryCount});

  final LocalWeek week;

  /// Toutes les entrées de la semaine, quel que soit leur statut (CA8).
  final int entryCount;
}

/// Moins de 3 entrées : pas de bilan (RM21, CA6).
final class InsufficientWeek extends WeeklyReview {
  const InsufficientWeek({required super.week, required super.entryCount});
}

/// Bilan calculé.
final class ComputedWeek extends WeeklyReview {
  const ComputedWeek({
    required super.week,
    required super.entryCount,
    required this.averageMoodTenths,
    required this.moodCounts,
    required this.notedDays,
    required this.topTags,
    required this.comparison,
    required this.isSensitive,
    required this.facts,
  });

  /// Humeur moyenne en dixièmes (36 pour 3,6), arrondie la moitié vers le haut.
  final int averageMoodTenths;

  /// Nombre d'entrées pour chaque humeur, de 1 à 5 (5 entiers, zéros compris).
  final List<int> moodCounts;

  /// Jours notés, de 1 (lundi) à 7 (dimanche), dans l'ordre.
  final List<int> notedDays;

  /// Au plus 3 étiquettes fréquentes, triées (CA12).
  final List<TagCount> topTags;

  /// Semaine précédente, si elle compte au moins 3 entrées (CA14, CA15).
  final WeekComparison? comparison;

  /// Semaine sensible (RM52) : aucun texte généré.
  final bool isSensitive;

  final ReviewFacts facts;
}

/// Dixièmes affichés avec une virgule : 36 → « 3,6 », 30 → « 3,0 ».
String formatTenths(int tenths) => '${tenths ~/ 10},${tenths % 10}';
