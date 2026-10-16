# Journal : refactor/watch-entry

Issue #39 : l'écran de détail observe une seule entrée (`EntryRepository.watchEntry(id)`) au lieu de tout le journal. Refactor sans changement de comportement observable.

## 2026-10-16 17:00

### Fait

- Lecture de l'issue #39, de `EntryDetailScreen`, de `DriftEntryRepository.watchEntries()` et du faux `FakeEntryRepository`.
- Tests écrits par le subagent `test-writer`, avant l'implémentation : `test/storage/watch_entry_test.dart`. Sept cas, exécutés sur `DriftEntryRepository` (base en mémoire) et sur `FakeEntryRepository`, pour que le faux reste aligné sur le vrai : première émission, étiquettes dans l'ordre enregistré, entrée étiquetée puis « non analysée », entrée supprimée (`null`), identifiant inexistant (`null`), et aucune émission quand seules d'autres entrées changent.
- Rouges pour la bonne raison : le fichier ne compile pas, `The method 'watchEntry' isn't defined for the type 'EntryRepository'` (seule erreur).

### Décisions

- Yanis a donné son accord le 2026-10-16 pour enchaîner sans pause après les tests rouges (« fonce, continue le dev ») et a délégué les décisions à l'agent (« fonce, sois autonome sur les décisions et finis l'app »).
- Pas de spec : refactor sans changement de comportement, la description de la PR suffit (CLAUDE.md, méthode de travail, point 1).

### Corrections et limites

- Rien.

### Prochaine étape

- Implémenter `watchEntry` (drift et faux), puis brancher l'écran de détail.
