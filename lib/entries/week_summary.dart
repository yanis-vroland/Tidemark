/// Résumé d'une semaine pour l'accueil et l'en-tête du bilan (spec 009) : humeur du
/// jour, nombre d'entrées, libellé du compteur de coquillages.
library;

import '../review/local_week.dart';
import 'entry.dart';

/// Humeur du jour de chaque jour de [week], du lundi au dimanche ; `null` pour un
/// jour sans entrée (CA14, CA24).
///
/// L'humeur du jour est celle de la dernière entrée saisie ce jour local : date de
/// saisie la plus récente, puis plus grand identifiant. Chaque entrée est rangée
/// dans le jour local de sa saisie, avec le décalage enregistré (spec 006, CA7).
List<int?> dayMoodsOfWeek(Iterable<Entry> entries, LocalWeek week) {
  final latest = List<Entry?>.filled(7, null);
  for (final entry in entries) {
    final local = entry.localCreatedAt;
    if (!week.containsDay(local)) continue;
    final index = local.weekday - 1;
    final current = latest[index];
    if (current == null || _isMoreRecent(entry, current)) {
      latest[index] = entry;
    }
  }
  return [for (final entry in latest) entry?.mood];
}

bool _isMoreRecent(Entry a, Entry b) {
  final byTime = a.createdAt.compareTo(b.createdAt);
  return byTime != 0 ? byTime > 0 : a.id > b.id;
}

/// Nombre d'entrées de [week], quel que soit leur statut, chacune dans la semaine
/// de son jour local de saisie (CA9).
int entriesInWeek(Iterable<Entry> entries, LocalWeek week) =>
    entries.where((e) => week.containsDay(e.localCreatedAt)).length;

/// Compteur de l'en-tête de l'accueil (CA9).
String shellCountLabel(int count) => switch (count) {
  0 => 'Aucun coquillage cette semaine',
  1 => '1 coquillage cette semaine',
  _ => '$count coquillages cette semaine',
};
