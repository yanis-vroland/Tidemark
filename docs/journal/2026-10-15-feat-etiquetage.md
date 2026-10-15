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

## 2026-10-15 09:42

### Fait

- Tests de la spec 004 écrits à partir de la spec et de la maquette seules, avant toute implémentation : 209 tests, dont 184 en échec (fonctionnalité absente : `UnimplementedError`, table `tags` absente, section « Étiquettes » absente), 25 qui passent sans implémentation (voir « Corrections et limites »). Les 755 tests existants restent verts.
- Fichiers : `test/analysis/` (`tag_vocabulary_test` 15, `tag_output_parser_test` 62, `analysis_queue_test` 44, `analysis_wiring_test` 7, `llama_mood_analyzer_test` 2), `test/storage/analysis_storage_test.dart` (26), `test/ui/analysis_display_test.dart` (53), harnais `test/support/analysis_harness.dart`.
- CA1 relit le bloc `text` de la spec à chaque exécution (aucune copie de la liste) et compare aussi le schéma JSON de la spec à `TagVocabulary.outputSchema`.
- Aucun fichier de `lib/` ni test existant modifié.

### Décisions

- Écrans testés avec une file factice (`StubAnalysisQueue`) : ils ne lisent que `currentEntryId` et `state`, et se reconstruisent à chaque notification ; la file réelle est testée à part et par `startApp` (agent).
- `LlamaMoodAnalyzer` : seule la consigne est vérifiée (contre la spec) ; le schéma passé au moteur et les paramètres (température, jetons, GPU) ne sont pas exposés, donc non testables sans exécuter le moteur (agent).

### Corrections et limites

- Tests qui passent sans implémentation : la lecture du bloc de la spec (CA1, 9 tests, dont les 8 sur le format) ; CA25 (12 combinaisons : un détail « non analysée » ne montre rien, vrai déjà aujourd'hui, le test protège contre une régression) ; la consigne de `LlamaMoodAnalyzer` (2, déjà dans le squelette) ; `startApp` sans analyseur ; une entrée neuve sans étiquette.
- Deux tests existants affirment `schemaVersion == 3` (`test/storage/model_offer_storage_test.dart`) : ils échoueront à l'implémentation du schéma 4, à mettre à jour avec accord explicite.
- Les tests n'ont pas pu être confrontés à une implémentation : à relire à l'implémentation, surtout les tests d'écran et de minutage (délais réels courts).
- Ambiguïtés de la spec à trancher (aucune décision prise dans les tests) : écriture du résultat qui échoue (nouvelle tentative ou attente du lancement suivant) ; nouvel essai de la file si `whenIdle` est appelé avant la première lecture ; libellé de carte long avec étiquettes (CA27 et CA36 de la spec 001) ; mécanisme de l'annonce d'un changement de statut (CA28) ; touche d'une puce dans la liste (la carte s'ouvre-t-elle ?) ; tri à égalité de date.

### Prochaine étape

Relecture des tests, puis implémentation jusqu'au vert (parseur et vocabulaire, stockage et migration 4, file, écrans, branchement dans `startApp`).

## 2026-10-15 09:52

### Fait

- Implémentation de la spec 004 :
  - `TagVocabulary` (12 émotions, 12 thèmes, schéma tiré des listes) ;
  - `TagOutputParser` ;
  - `LlamaMoodAnalyzer` sur `llamadart` : session neuve par entrée, consigne en message système, température 0,2, 128 jetons, sortie contrainte par le schéma puis revalidée, GPU sur iOS et processeur seul ailleurs ;
  - `AnalysisQueue` : observe les entrées et l'état du modèle ; une analyse à la fois, la plus récente d'abord ; `detectInText` juste avant chaque analyse ; délai de 30 s, puis `cancel` et attente ; modèle libéré quand la file est vide ; `verifyAfterLoadFailure` si le chargement échoue ;
  - table `tags` (cascade, unicité), schéma en version 4, `PRAGMA foreign_keys = ON` à l'ouverture ;
  - `saveAnalysis` en transaction, sans effet si l'entrée n'est plus « en attente » ;
  - puces et mention « Analyse en cours… » dans la liste ; section « Étiquettes » du détail, mise à jour en direct ;
  - file démarrée dans `startApp`.
- 964 tests verts, en heure de Paris comme en UTC.
- Contrôle par mutation sur 19 protections : 16 détectées. 3 ne le sont pas encore (voir ci-dessous).

### Décisions

- Pas de construction complète de la liste à 200 % : un journal peut compter des centaines d'entrées. Le test de CA29 défile jusqu'à la carte (agent).

### Corrections et limites

- Tests modifiés, à signaler :
  - `test/ui/analysis_display_test.dart` (CA29, liste) : défilement jusqu'à la deuxième carte ;
  - `test/storage/model_offer_storage_test.dart` : version du schéma « au moins 3 », le schéma passant en version 4.
- Mutations non détectées, tests à ajouter :
  - l'attente de la fin de l'analyse après `cancel` ;
  - « aucune analyse si le modèle n'est pas prêt » : un modèle absent puis prêt, sans relance du flux ;
  - `saveAnalysis` limité aux entrées « en attente ».
- Pas encore faits : revues `reviewer` et `security-reviewer`, et essai du vrai modèle. Le modèle est déjà téléchargé sur l'émulateur Android `tidemark_api35`.

### Prochaine étape

1. Ajouter les 3 tests manquants.
2. Revues `reviewer` et `security-reviewer`.
3. Essai du vrai modèle sur l'émulateur Android, puis test humain de Yanis sur l'iPhone : 20 entrées fictives du spike, taux de JSON valide et rappel à consigner (spec 004).
4. Traiter la revue IA de la PR.
5. Ensuite : lot H (spec 005, export et suppression totale), puis lot I (spec 006), puis lot J.

## 2026-10-15 14:49

### Fait

- Les 3 mutations non détectées ont été rejouées :
  - attente de la fin de l'analyse après `cancel` : nouveau test CA14, avec `DetachedCancelAnalyzer` (un `cancel()` qui rend la main tout de suite pendant que la génération continue). La mutation est maintenant détectée ;
  - `saveAnalysis` limité aux entrées « en attente » : 3 tests de stockage (entrée non analysée, étiquetée, sans étiquette). Mutation détectée ;
  - garde `!_modelReady` dans `_kick` : mutant équivalent. La boucle de `_run` vérifie la même condition avant toute lecture ou analyse, donc aucun comportement observable ne change. Le cas « modèle retiré pendant la file » est couvert par la garde de la boucle, et sa mutation est détectée.
- 972 tests verts, en heure de Paris comme en UTC ; lint et format au vert.

### Décisions

- Pas de test artificiel pour le mutant équivalent : la garde de `_kick` est gardée comme protection en amont (agent).
- Yanis a validé la charte (lot C) le 2026-10-15. La case du plan sera cochée dans une PR `docs` séparée, après celle-ci.

### Corrections et limites

- Aucun test existant modifié.
- Contrôle par mutation : 18 protections sur 19 sont détectées, la 19ᵉ est le mutant équivalent ci-dessus.

### Prochaine étape

1. Revues `reviewer` et `security-reviewer`.
2. Essai du vrai modèle sur l'émulateur Android, puis test humain de Yanis sur l'iPhone (20 entrées fictives du spike).
3. Traiter la revue IA de la PR.
4. PR `docs` sur le plan : cases de validation et reports du lot C (icônes, captures).
