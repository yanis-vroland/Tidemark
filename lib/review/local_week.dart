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
  factory LocalWeek.containing(DateTime localDay) {
    final day = _civil(localDay);
    // Dates civiles en UTC : 24 heures par jour, même au changement d'heure.
    return LocalWeek._(day.subtract(Duration(days: day.weekday - 1)));
  }

  /// Lundi de la semaine, date civile (marquée UTC par convention, à minuit).
  final DateTime monday;

  /// Dimanche de la semaine, date civile.
  DateTime get sunday => monday.add(const Duration(days: 6));

  /// Les sept jours, du lundi au dimanche.
  List<DateTime> get days => [
    for (var i = 0; i < 7; i++) monday.add(Duration(days: i)),
  ];

  LocalWeek get previous =>
      LocalWeek._(monday.subtract(const Duration(days: 7)));

  LocalWeek get next => LocalWeek._(monday.add(const Duration(days: 7)));

  /// Vrai si le jour local [localDay] tombe dans la semaine.
  bool containsDay(DateTime localDay) => LocalWeek.containing(localDay) == this;

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

DateTime _civil(DateTime date) => DateTime.utc(date.year, date.month, date.day);

const _months = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

String _dayMonth(DateTime day) => '${day.day} ${_months[day.month - 1]}';

String _dayMonthYear(DateTime day) => '${_dayMonth(day)} ${day.year}';

/// Dates de la carte de la liste (CA1) : « Du lundi 12 au dimanche 18 octobre »,
/// « Du lundi 28 septembre au dimanche 4 octobre », et l'année à chaque borne
/// quand la semaine change d'année.
String weekCardLabel(LocalWeek week) {
  final (from, to) = _bounds(
    week,
    withYear: week.monday.year != week.sunday.year,
  );
  return 'Du lundi $from au dimanche $to';
}

/// Dates de l'écran du bilan (CA4) : « 12 – 18 octobre », « 28 septembre –
/// 4 octobre », avec l'année à chaque borne si l'une diffère de [currentYear].
String weekRangeLabel(LocalWeek week, {required int currentYear}) {
  final (from, to) = _bounds(
    week,
    withYear:
        week.monday.year != currentYear || week.sunday.year != currentYear,
  );
  return '$from – $to';
}

/// Bornes de la semaine : le mois n'est répété au lundi que s'il change (ou si
/// l'année est donnée).
(String, String) _bounds(LocalWeek week, {required bool withYear}) {
  final monday = week.monday;
  final sunday = week.sunday;
  if (withYear) return (_dayMonthYear(monday), _dayMonthYear(sunday));
  final from = monday.month == sunday.month
      ? '${monday.day}'
      : _dayMonth(monday);
  return (from, _dayMonth(sunday));
}

/// Mention sous les dates (CA4) : « Semaine en cours », « Semaine dernière », ou
/// `null` pour les autres semaines.
String? weekCaption(LocalWeek week, {required LocalWeek current}) {
  if (week == current) return 'Semaine en cours';
  if (week == current.previous) return 'Semaine dernière';
  return null;
}
