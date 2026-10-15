# Journal : étiquetage automatique (spec 004)

Branche `feat/etiquetage`, partie de `feat/modele-local` (PR #22, pas encore mergée). La PR sera ouverte sur `main` après le merge de la #22, une fois la branche rebasée.

## 2026-10-15 09:25

### Fait

- Squelette de la spec 004, sans comportement :
  - `TagVocabulary` (listes vides), `TagOutputParser` ;
  - contrat `MoodAnalyzer` étendu (`prepare`, `cancel`, `release`) ;
  - `LlamaMoodAnalyzer` et sa consigne ;
  - `AnalysisQueue` (`ChangeNotifier`) et `AnalysisScope` (`InheritedNotifier`) ;
  - `Entry.tags` et `EntryRepository.saveAnalysis` ;
  - téléchargeur passé au détail ;
  - analyseur créé dans `openJournal`, et file facultative dans `TidemarkApp`.
- `FakeMoodAnalyzer` complété : résultat de `prepare`, délais par texte (dont « jamais »), `cancel`, compteur d'analyses simultanées. `FakeEntryRepository.saveAnalysis` ajouté.
- Dépendance `llamadart` 0.12.0, épinglée exactement (ADR-001). Elle n'ouvre aucune connexion à l'exécution : le modèle lui est donné par un chemin local. Son hook de compilation télécharge en revanche les bibliothèques natives de llama.cpp depuis GitHub, avec une empreinte SHA-256 épinglée. C'est du réseau à la construction de l'app, jamais sur le téléphone de la personne.

### Décisions

- File d'analyse et téléchargeur rendus visibles des écrans par un `InheritedNotifier`, plutôt que par un paramètre de plus dans chaque constructeur : la file n'a pas à être appelée par la saisie, elle observe les entrées et l'état du modèle (agent).
- File et téléchargeur facultatifs dans `TidemarkApp` et le détail : sans eux, rien n'est analysé ni affiché. Le test de `startApp` vérifie que l'app démarrée les reçoit (agent).

### Corrections et limites

- Branche partie d'une PR non mergée (#22) : la PR de cette branche n'est ouverte qu'après son merge et un rebase sur `main`.

### Prochaine étape

Tests de la spec 004 par le subagent `test-writer`, committés seuls et rouges ; puis implémentation.
