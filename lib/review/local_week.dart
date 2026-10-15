/// Semaine locale du bilan (spec 006, « Règles de calcul ») : du lundi 00:00 au
/// dimanche 23:59, en jours locaux.
library;

/// Semaine du lundi au dimanche, en dates locales (glossaire : `LocalWeek`). Les
/// jours sont des dates civiles, sans heure ni fuseau : un changement d'heure ne
/// décale rien.
class LocalWeek implements Comparable<LocalWeek> {
  LocalWeek._(this.monday);

  /// Semaine qui contient le jour local [localDay] (seuls l'année, le mois et le
  /// jour comptent).
  factory LocalWeek.containing(DateTime localDay) =>
      LocalWeek._(throw UnimplementedError());

  /// Lundi de la semaine, date civile (marquée UTC par convention, à minuit).
  final DateTime monday;

  /// Dimanche de la semaine, date civile.
  DateTime get sunday => throw UnimplementedError();

  /// Les sept jours, du lundi au dimanche.
  List<DateTime> get days => throw UnimplementedError();

  LocalWeek get previous => throw UnimplementedError();

  LocalWeek get next => throw UnimplementedError();

  /// Vrai si le jour local [localDay] tombe dans la semaine.
  bool containsDay(DateTime localDay) => throw UnimplementedError();

  @override
  int compareTo(LocalWeek other) => monday.compareTo(other.monday);

  @override
  bool operator ==(Object other) =>
      other is LocalWeek && other.monday == monday;

  @override
  int get hashCode => monday.hashCode;

  @override
  String toString() => 'LocalWeek(${monday.toIso8601String()})';
}

/// Dates de la carte de la liste (CA1) : « Du lundi 12 au dimanche 18 octobre »,
/// « Du lundi 28 septembre au dimanche 4 octobre », et l'année à chaque borne
/// quand la semaine change d'année.
String weekCardLabel(LocalWeek week) => throw UnimplementedError();

/// Dates de l'écran du bilan (CA4) : « 12 – 18 octobre », « 28 septembre –
/// 4 octobre », avec l'année à chaque borne si l'une diffère de [currentYear].
String weekRangeLabel(LocalWeek week, {required int currentYear}) =>
    throw UnimplementedError();

/// Mention sous les dates (CA4) : « Semaine en cours », « Semaine dernière », ou
/// `null` pour les autres semaines.
String? weekCaption(LocalWeek week, {required LocalWeek current}) =>
    throw UnimplementedError();
