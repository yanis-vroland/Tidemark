import 'entry.dart';

/// Les entrées d'un jour local, sous leur intertitre.
class DayGroup {
  const DayGroup(this.label, this.entries);

  final String label;
  final List<Entry> entries;
}

/// Intertitre du jour [day] vu depuis [today] (dates locales) : « Aujourd'hui »,
/// « Hier », « Lundi 12 octobre », ou « Lundi 13 octobre 2025 » pour une autre année.
String dayLabel(DateTime day, DateTime today) =>
    throw UnimplementedError('dayLabel');

/// Date complète, pour le détail : « Mercredi 14 octobre 2026 ».
String fullDateLabel(DateTime day) => throw UnimplementedError('fullDateLabel');

/// Heure locale au format « 21:40 ».
String timeLabel(DateTime local) => throw UnimplementedError('timeLabel');

/// Regroupe [entries] par jour local, jours et entrées du plus récent au plus ancien.
List<DayGroup> groupByDay(List<Entry> entries, DateTime today) =>
    throw UnimplementedError('groupByDay');
