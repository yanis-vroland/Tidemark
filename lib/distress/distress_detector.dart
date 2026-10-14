import '../entries/entry.dart';

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

/// Règles déterministes de détection de la détresse (spec 002, RM6, RM25). Code pur,
/// sans état ni accès à la base.
class DistressDetector {
  const DistressDetector();

  /// Forme normalisée de [text] : minuscules, sans accents, tout ce qui n'est ni
  /// lettre ni chiffre remplacé par une espace, espaces réduites.
  static String normalize(String text) => throw UnimplementedError();

  /// Vrai si [text] contient une expression de la liste, en mots entiers.
  bool detectInText(String text) => throw UnimplementedError();

  /// Vrai si les `sensitivity.entryCount` premières entrées de [latest] (de la plus
  /// récente à la plus ancienne) sont toutes à 1 et tiennent en
  /// `sensitivity.days` × 24 heures.
  bool detectLowMoodSeries(
    List<Entry> latest,
    LowMoodSensitivity sensitivity,
  ) => throw UnimplementedError();
}
