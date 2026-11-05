# Journal de la branche perf/celebration-semaine

## 2026-11-05 22:31

### Fait

- [Issue #51](https://github.com/yanis-vroland/Tidemark/issues/51) (suite de la revue IA de la PR #49) : tests de la lecture bornée des entrées, committés rouges avant l'implémentation. Dépôt `drift` sur base en mémoire (`test/storage/entries_between_test.dart`) : borne de début comprise, borne de fin exclue, ordre chronologique puis par identifiant, fenêtre vide ou inversée, et rangement par jour local de saisie (dimanche 23:30 à UTC-10, lundi 00:30 à UTC+14, lundi suivant 00:30 à UTC+2), comme la spec 006, CA7. Faux dépôt (`test/entries/fake_entry_repository_test.dart`) : mêmes bornes, erreur de lecture configurable, trace des appels. Fenêtre UTC de la semaine (`LocalWeek.utcWindow`, `test/review/local_week_test.dart`). Célébration (`test/ui/celebration_test.dart`) : un seul appel borné, sur la fenêtre de la semaine.
- Le faux dépôt de CA17 (`FailingReadsAfterAddRepository`) fait aussi échouer la nouvelle lecture, pour que le test de la lecture en erreur reste probant.

### Décisions

- Agent, sur consigne de la session parente : signature `entriesBetween(DateTime fromUtc, DateTime toUtc)`, début compris et fin exclue, de la plus ancienne à la plus récente, sans étiquettes ni sujets (la célébration n'a besoin que de l'humeur). La fenêtre de la semaine vient de `LocalWeek.utcWindow` (élargie d'un jour de chaque côté, assez pour tout décalage de UTC-12 à UTC+14) ; l'écran filtre ensuite par jour local de saisie (`LocalWeek.containsDay`), comme `entriesInWeek`.

### Corrections et limites

- Rien à signaler.

### Prochaine étape

- Implémenter `entriesBetween` (interface, `DriftEntryRepository`, faux dépôt), `LocalWeek.utcWindow`, et l'utiliser dans la célébration ; mettre à jour le contrat `EntryRepository` dans l'architecture technique.

## 2026-11-05 22:45

### Fait

- `EntryRepository.entriesBetween(fromUtc, toUtc)` : requête `drift` bornée par `created_at` (début compris, fin exclue), triée par instant puis identifiant, sans jointure sur les étiquettes ni les sujets. Faux dépôt : même contrat, plus `entriesBetweenError` et `entriesBetweenCalls`.
- `LocalWeek.utcWindow` : la semaine élargie d'un jour de chaque côté, en instants UTC.
- Célébration : lit `entriesBetween` sur cette fenêtre au lieu de `watchEntries().first`, puis garde les entrées dont le jour local de saisie tombe dans la semaine. Comportement inchangé (spec 010, CA12 et CA17 au vert).
- Architecture technique : contrat `EntryRepository` complété.
- `dart format lib test`, `dart analyze --fatal-infos` sans remarque, `flutter test` : 2528 tests au vert.

### Décisions

- Agent : pas de lecture des étiquettes ni des sujets dans `entriesBetween`, la célébration n'en a pas besoin ; à compléter le jour où un autre écran en aurait l'usage.

### Corrections et limites

- Test humain sans objet : aucun changement de comportement observable.

### Prochaine étape

- PR en brouillon sur `main` (ferme l'issue #51), revue IA, puis validation et merge par Yanis.
