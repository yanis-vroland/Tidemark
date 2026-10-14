import 'entry.dart';

/// Les entrées d'un jour local, sous leur intertitre.
class DayGroup {
  const DayGroup(this.label, this.entries);

  final String label;
  final List<Entry> entries;
}

const _weekdays = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

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

/// Jour civil de [date], sans heure ni fuseau, pour comparer des jours.
DateTime _civilDay(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

/// Jour de la semaine et date, sans l'année : « Mercredi 14 octobre ».
String weekdayAndDate(DateTime day) =>
    '${_weekdays[day.weekday - 1]} ${day.day} ${_months[day.month - 1]}';

/// Intertitre du jour [day] vu depuis [today] (dates locales) : « Aujourd'hui »,
/// « Hier », « Lundi 12 octobre », ou « Lundi 13 octobre 2025 » pour une autre année.
String dayLabel(DateTime day, DateTime today) {
  final gap = _civilDay(today).difference(_civilDay(day)).inDays;
  if (gap == 0) return "Aujourd'hui";
  if (gap == 1) return 'Hier';
  final label = weekdayAndDate(day);
  return day.year == today.year ? label : '$label ${day.year}';
}

/// Date complète, pour le détail : « Mercredi 14 octobre 2026 ».
String fullDateLabel(DateTime day) => '${weekdayAndDate(day)} ${day.year}';

/// Heure locale au format « 21:40 ».
String timeLabel(DateTime local) =>
    '${local.hour.toString().padLeft(2, '0')}:'
    '${local.minute.toString().padLeft(2, '0')}';

/// Regroupe [entries] par jour local, jours et entrées du plus récent au plus ancien.
List<DayGroup> groupByDay(List<Entry> entries, DateTime today) {
  final sorted = [...entries]
    ..sort((a, b) {
      final byTime = b.createdAt.compareTo(a.createdAt);
      return byTime != 0 ? byTime : b.id.compareTo(a.id);
    });
  final byDay = <DateTime, List<Entry>>{};
  for (final entry in sorted) {
    byDay.putIfAbsent(_civilDay(entry.localCreatedAt), () => []).add(entry);
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final day in days) DayGroup(dayLabel(day, today), byDay[day]!)];
}
